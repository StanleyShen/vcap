require 'rubygems'

require 'jobs/job'
require 'route53/dns_gateway_client'
require 'vmc/vmcapphelpers'
require 'vmc/vmchelpers'

module Jobs
  class StartAppJob < StopAppJob
  end
end

class ::Jobs::StartAppJob
  def self.job_name
    'Start Application'
  end

  def initialize(options)
    super(options)

    options = options || {}
    @vmc_app_start_query_timeout = options['vmc_app_start_query_timeout']  || 3600
  end
  
  def run
    res = {}
    @apps = @apps.nil? ? @admin_instance.governed_apps: @apps.split(",")

    @apps.each do |app_name|
      app = @admin_instance.app_info(app_name, false)
      health = ext_client.__health(app)

      debug "Starting app #{app_name} - current health => #{health}"
      if health != 'RUNNING'
        begin
          start(app_name, app)
  
          # check the latest states
          app = @admin_instance.app_info(app_name, false)
          health = ext_client.__health(app)
  
          if (health != 'RUNNING')
            res[app_name] = "starting #{app_name}"
          else
            res[app_name] = "started already"
          end
        rescue => e
          error("failed to start #{app_name}")
          error(e)
          res[app_name] = e.message
        end
      else
        res[app_name.to_sym] = "started already"
      end
    end
    completed(res)
  end
  
  private
  
  def ext_client()
    client = @admin_instance.vmc_client(false)
    client_ext = VMC::Cli::Command::AppsExt.new
    client_ext.client = client

    client_ext
  end
  
  def start(app_name, app)
    retry_count = 1
    begin
      started = do_start(app_name, app, true)
      return unless started

      completed("The application #{app_name} was started", false)
    rescue VMC::Client::TargetError => te 
      if te.message.index('Error (JSON 502)').nil?
        raise te 
      else
        retry_count -= 1
        if retry_count >= 0
          do_start(app_name, app, false)
        else 
          raise te
        end
      end
    end
  end

  def do_start(app_name, app, force_stop = true)    
    if (force_stop)
      do_stop(app_name, app)
    end

    # start the application
    app[:state] = 'STARTED'
    client = @admin_instance.vmc_client(false)
    client.update_app(app_name, app)

    start_time = Time.now.to_i
    timeout_at = start_time + @vmc_app_start_query_timeout

    total_ticks = (@vmc_app_start_query_timeout / @vmc_app_query_interval).to_i
    iteration = 0

    begin
      at(iteration, total_ticks, "Starting the application #{app_name}")

      app = @admin_instance.app_info(app_name, false)
      return true if ext_client.__health(app) == 'RUNNING'

      iteration = iteration + 1
      sleep(@vmc_app_query_interval)
    end while timeout_at >= Time.now.to_i

    app = @admin_instance.app_info(app_name, false)
    unless ext_client.__health(app) == 'RUNNING'
      failed( {'message' => "Timeout: the application #{app_name} did not start in time.",
               'start' => 'failed', 'reason' => 'timeout' }, false)
      return false
    end
    true
  end
end