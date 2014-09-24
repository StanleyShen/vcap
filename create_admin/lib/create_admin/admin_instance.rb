require 'rubygems'
require 'vmc_knife'
require 'vmc_knife/commands/knife_cmds'

require 'singleton'
require 'securerandom'
require 'thread'

require "create_admin/log"

module CreateAdmin
  class AdminInstance
  end
end

class ::CreateAdmin::AdminInstance
  include Singleton
  include ::CreateAdmin::Log
  include VMC::KNIFE::Cli
  
  def accept_job?(job_type, instance_id)
    klass = CreateAdmin::JOBS[job_type]
    return {:accept => false, :message => "Can't find the job class with type: #{job_type}."} if klass.nil?

    @running_jobs_lock.synchronize{
      @running_instance_nums.each{|running_job, instance_num|
        next if instance_num == 0

        running_klass = CreateAdmin::JOBS[running_job]
        unless running_klass.accept?(running_job, job_type)
          return {:accept => false, :message => "Can't execute #{klass.job_name} because #{running_klass.job_name} is running."}
        end
      }
      @running_instance_nums[job_type] = (@running_instance_nums[job_type] || 0) + 1 
      @job_instances[instance_id] = JobInstance.new(job_type, instance_id)
    }

    {:accept => true}
  end

  def complete_instance(job_type, instance_id)
    @running_jobs_lock.synchronize{
      @running_instance_nums[job_type] = (@running_instance_nums[job_type] || 0) - 1
      if (@running_instance_nums[job_type] < 0)
        warn("#{job_type} instance number isn't removed correctly, the instances number is #{@running_instance_nums[job_type]}")
        @running_instance_nums[job_type] = 0
      end

      instance = @job_instances[instance_id]
      warn("The instance #{instance_id} doesn't exist for type: #{job_type}.") if instance.nil?
      instance.completed if instance
    }
  end
  
  def job_status(instance_id)
    instance = @job_instances[instance_id]
    raise "The instance #{instance_id} doesn't exist."
    instance.status
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

  def app_stats(app_name)
    client = vmc_client()
    client.app_stats(app_name)
  end
  
  def app_files(app_name, file_path, all_instances = false)
    client = vmc_client
    app_infos = client.app_instances(app_name)
    return if app_infos.nil? 

    instances = app_infos[:instances]
    return if instances.nil? || instances.empty?

    if all_instances
      instances.each do |instance|
        content = client.app_files(app_name, file_path, instance[:index])
        yield content
      end
    else
      if block_given?
        yield client.app_files(app_name, file_path, instances.first[:index])
      else
        client.app_files(app_name, file_path, instances.first[:index])
      end
    end
  end

  def governed_apps
    apps = manifest['recipes'].first['applications']

    # include all the apps excludes cdn, oauth, admin
    res = []
    apps.each{|k, v| 
      name = v['name']
      res << name if name != 'cdn' && name != 'admin' && name != 'oauth'
    }
    res 
  end
  
  def manifest(refresh = false, manifest_path = nil)
    if (refresh)
      return refresh_manifest(manifest_path)
    end
    @manifest = @manifest || refresh_manifest(manifest_path) 
  end
  
  def manifest_path(path)
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
    COMPLETED = :completed
    RUNNING = :running
    TIMEOUT = 3600 # will keep the completed instance in one hour
  
    attr_accessor :job_type, :instance_id, :status, :completed_time
    def initialize(job_type, instance_id)
      @status = RUNNING
      @job_type = job_type
      @instance_id = instance_id
    end
    
    def completed
      @status = COMPLETED
      @completed_time = Time.new.to_i
    end
    
    def is_expired?
      return true if (@status == COMPLETED) && ((Time.new.to_i - @completed_time) >= TIMEOUT)
      false
    end
  end
end