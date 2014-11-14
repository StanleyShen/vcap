require 'rubygems'
require 'vmc_knife'
require 'vmc_knife/commands/knife_cmds'

require 'singleton'
require 'securerandom'
require 'thread'

require "create_admin/log"
require "create_admin/util"

module CreateAdmin
  class AdminInstance; end
end

class ::CreateAdmin::AdminInstance
  include Singleton
  include ::CreateAdmin::Log
  include VMC::KNIFE::Cli

# ---- methods for job status
  def accept_job?(job_type, instance_id)
    klass = CreateAdmin::JOBS[job_type]
    return {:accept => false, :message => "Can't find the job class with type: #{job_type}."} if klass.nil?

    @running_jobs_lock.synchronize{
      @job_instances.values.each{|instance|
        if instance.is_working?
          running_klass = CreateAdmin::JOBS[instance.job_type]
          unless running_klass.accept?(instance.job_type, job_type)
            return {:accept => false, :message => "Can't execute #{klass.job_name} because #{running_klass.job_name} is running."}
          end
        end
      }

      @job_instances[instance_id] = JobInstance.new(job_type, instance_id)
    }

    {:accept => true}
  end

  def complete_instance(job_type, instance_id)
    @running_jobs_lock.synchronize{
      instance = @job_instances[instance_id]
      warn("The instance #{instance_id} doesn't exist for type: #{job_type}.") if instance.nil?
      instance.completed if instance
    }
  end
  
  def job_instance_status(instance_id)
    instance = @job_instances[instance_id]
    if instance
      if instance.status == CreateAdmin::JOB_STATES['completed']
        # delete if the instance has completed and it's result has been taken.
        @running_jobs_lock.synchronize{
          @job_instances.delete(instance_id)
        }
      end
      return instance.job_execution_result
    end
    {'_status' => CreateAdmin::JOB_STATES['none']}
  end

  def job_status(job_type)
    res = []
    @running_jobs_lock.synchronize{
      @job_instances.values.each{|instance|
        if instance.job_type == job_type
          res << instance.job_execution_result
        end
      }
    }
    res
  end

  def get_safe_instance_id()
    @running_jobs_lock.synchronize{
      new_id = SecureRandom.base64
      while @job_instances.has_key?(new_id)
        new_id = SecureRandom.base64
      end
      return new_id
    }
  end
  
  def update_instance_execution_result(instance_id, res)
    @running_jobs_lock.synchronize{
      instance = @job_instances[instance_id]
      instance.execution_result = res if instance
    }
  end
#-------------methods for job status end

  def app_status(name)
    client = vmc_client(false)
# [{:state=>:RUNNING, :stats=>{:name=>"intalio", :host=>"38.102.156.37", :port=>46418, :uris=>["eng17.cloud.intalio.com"], :uptime=>183943.528171026, :mem_quota=>2147483648, :disk_quota=>2147483648, :fds_quota=>256, :cores=>6, :usage=>{:time=>"2014-10-03 08:09:05 +0000", :cpu=>0.0, :mem=>38144.0, :disk=>180568064}}, :instance=>0}] 
    # app_state only returns the state of "RUNNING" instance
    stats = client.app_stats(name)

    instances = {}
    stats.each{|s|
      instance_id = s[:instance]
      inner_stats = s[:stats]
      usage = inner_stats[:usage] || {}

      instances[instance_id] = {
        'instance' => s[:instance],
        'state' => s[:state].to_s,
        'host' => inner_stats[:host],
        'port' => inner_stats[:port],
        'uris' => inner_stats[:uris],
        'uptime' => CreateAdmin.uptime_string(inner_stats[:uptime]),
        'since' => usage[:time],
        'cpu' => usage[:cpu],
#        'mem' => CreateAdmin.pretty_size(usage[:mem] * 1024), # mem comes in K's
        'disk'  => CreateAdmin.pretty_size(usage[:disk])
      }
    }
    
#{:instances=>[{:index=>0, :state=>"RUNNING", :since=>1412141344, :debug_ip=>nil, :debug_port=>nil}, {:index=>1, :state=>"RUNNING", :since=>1412325926, :debug_ip=>nil, :debug_port=>nil}]}
    # app_instances will return all the instances includes "STARTING" instance
    all_instances = client.app_instances(name)[:instances]
    all_instances.each{|s|
      instance_id = s[:index]
      
      instance = instances[instance_id]
      if instance.nil?
        instances[instance_id]  = {
          'instance' => instance_id,
          'state' => s[:state].to_s
        }
      end
    }
    instances.values
  end

  def app_info(app, parse_env = true, manifest_path = nil)
    client = vmc_client(false, manifest_path)
    app_info = client.app_info(app)
    return if app_info.nil?

    return app_info unless parse_env

    app_env = app_info[:env]
    parsed_env = {}
    app_env.each do |e|
      k,v = e.split('=', 2)
      parsed_env[k] = v
    end
    app_info[:env] = parsed_env
    app_info
  end

  # instance id could be: ANY, ALL or one number
  def app_files(app_name, file_path, instance_id = 'ANY', ignore_not_found = true)
    client = vmc_client
    get_content_proc = proc {|instance_id|
      begin
        content = client.app_files(app_name, file_path, instance_id)
      rescue => e
        raise e unless ignore_not_found
        info("Failed to get file #{file_path} from #{app_name}.#{instance_id}.")
        nil
      end
    }
    
    if instance_id != 'ALL' && instance_id != 'ANY'
      content = get_content_proc.call(instance_id)
      return yield content if block_given?
      return content
    end

    instances = client.app_instances(app_name)
    return if instances.nil? || instances.empty?

    inner_ins = instances[:instances]
    return if inner_ins.nil? || inner_ins.empty?

    if instance_id == 'ANY'
      content = get_content_proc.call(inner_ins.first[:index])
      return yield content if block_given?
      return content
    end
    
    res = ''
    inner_ins.each do |ins|
      content = client.app_files(app_name, file_path, ins[:index])
      if block_given?
        yield content
      else
        res << "\n" << content
      end
    end
    return res
  end

  def governed_apps
    apps = manifest['recipes'].first['applications']

    # include all the apps excludes cdn, oauth, admin
    res = []
    apps.each{|k, v| 
      name = v['name']
      res << name if name != CreateAdmin.CDN_APP_NAME && name != CreateAdmin.ADMIN_APP_NAME && name != CreateAdmin.OAUTH_APP_NAME
    }
    res 
  end
  
  def manifest(refresh = false, manifest_path = nil)
    if (refresh)
      return refresh_manifest(manifest_path)
    end
    @manifest = @manifest || refresh_manifest(manifest_path) 
  end
  
  def manifest_path(path = nil)
    path || ENV['VMC_KNIFE_DEFAULT_RECIPE']
  end
  
  def vmc_client(renew = false, manifest_path = nil)
    return @vmc_client if @vmc_client && !renew

    manifest = manifest(renew, manifest_path)

    target = manifest['target']
    user = manifest['email']
    password = manifest['password']

    @vmc_client = vmc_client_by_credential(target, user, password)    
  end

  def vmc_client_by_credential(target, user, password)
    client = VMC::Client.new(target || 'api.intalio.priv')
    client.login(user || 'system@intalio.com', password || 'gold')
    client
  end
  
  def backup_home
    "#{ENV['HOME']}/cloudfoundry/backup"
  end

  # instance cache  
  def put_cache(key, value)
    @instance_cache[key] = value
    value
  end
  
  def get_cache(key)
    @instance_cache[key]
  end

  def delete_cache(key = nil)
    if key.nil?
      @instance_cache = {}
    else
      @instance_cache.delete(key)
    end
  end

  def stop_app(app_name)
    app = app_info(app_name, false)
    return true if app[:state] == 'STOPPED'

    app[:state] = 'STOPPED'
    vmc_client(false).update_app(app_name, app)
    app_info(app_name, false)[:state] == 'STOPPED'
  end

  private

  def initialize
    @instance_cache = {}
    # it is to maintain the instance number per job type.
    @running_instance_nums = {}
    # it is to maintain the running job instanceid
    @job_instances = {}
    @running_jobs_lock = Mutex.new

    # thread is used to clean expired job instance
    Thread.new{
      loop do
        # check in every 10 minutes
        sleep (600)
        # remove all the expired instance
        @running_jobs_lock.synchronize{
          all_instances = @job_instances.values
          all_instances.each{|t|
            @job_instances.delete(t.instance_id) if t.is_expired?
          }
        }
      end
    }
  end

  def refresh_manifest(manifest_path = nil)
    @vmc_client = nil

    manifest = manifest_path || ENV['VMC_KNIFE_DEFAULT_RECIPE']
    @manifest = load_manifest(manifest_path)
  end

  class JobInstance
    TIMEOUT = 3600 # will keep the completed instance in one hour
  
    attr_accessor :job_type, :instance_id, :status, :completed_time, :execution_result
    def initialize(job_type, instance_id)
      @status = CreateAdmin::JOB_STATES['working']
      @job_type = job_type
      @instance_id = instance_id
    end

    def completed
      @status = CreateAdmin::JOB_STATES['completed']
      @completed_time = Time.new.to_i
    end

    def job_execution_result
      return execution_result unless execution_result.nil?
      
      if @status == CreateAdmin::JOB_STATES['completed']
        # the client only consider two status here, failed or success
        {'_status' => CreateAdmin::JOB_STATES['success']}
      else
        {'_status' => CreateAdmin::JOB_STATES['working']}
      end
    end

    def is_expired?
      return true if (@status == COMPLETED) && ((Time.new.to_i - @completed_time) >= TIMEOUT)
      false
    end

    def is_working?
      @status == CreateAdmin::JOB_STATES['working']
    end

    def completed?
      @status == CreateAdmin::JOB_STATES['completed']
    end
  end
end