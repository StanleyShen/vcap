require 'rubygems'

require 'jobs/job'
require 'route53/dns_gateway_client'
require 'vmc/vmcapphelpers'
require 'vmc/vmchelpers'

module Jobs
  class StartAppJob < StopAppJob; end
end

class ::Jobs::StartAppJob
  def self.job_name
    'Start Application'
  end

  def initialize(options)
    super(options)

    options = options || {}
    @vmc_app_start_query_timeout = options['vmc_app_start_query_timeout']  || 3600
    @enforce_restart = options['enforce_start']
    @enforce_restart = true if @enforce_restart.nil? 
  end
  
  def run
    @apps = @apps.nil? ? @admin_instance.governed_apps: @apps.split(",")
    begin
      @apps.each do |app_name|
        if @enforce_restart
          start(app_name)
        else
          app = @admin_instance.app_info(app_name, false)
          health = ext_client.__health(app)
          if health != 'RUNNING'
            start(app_name)
          else
            output_status("Application #{app_name} is started already.", 2)
          end
        end
      end
    rescue Jobs::JobTimeoutError => e
      error e.message
      failed({'message' => e.message, 'reason' => 'timeout'})
      return
    end

    completed("Applications: #{@apps.join(', ')} are started successfully.")
  end
  
  def total_steps
    @total_steps = @total_steps || if @enforce_restart
      @apps.size * 4
    else
      @apps.size * 2 
    end
  end
  
  private
  
  def ext_client()
    client = @admin_instance.vmc_client(false)
    client_ext = VMC::Cli::Command::AppsExt.new
    client_ext.client = client

    client_ext
  end
  
  def start(app_name)
    if @enforce_restart
      stop_app(app_name)
    end
    retry_count = 1

    output_status("Trying to start the application #{app_name}.")    
    begin
      app = @admin_instance.app_info(app_name, false)
      app[:state] = 'STARTED'

      # start the application
      client = @admin_instance.vmc_client(false)
      client.update_app(app_name, app)

      app = @admin_instance.app_info(app_name, false)
      if ext_client.__health(app) == 'RUNNING'
        output_status("Application #{app_name} is started.")
      end

      ensure_started(app_name)
      output_status("Application #{app_name} is started.")
    rescue VMC::Client::TargetError => te
      if te.message.index('Error (JSON 502)').nil?
        raise te 
      else
        retry_count -= 1
        if retry_count >= 0
          retry
        else
          raise te
        end
      end
    end
  end

  def ensure_started(app_name)
    timeout_at = Time.now.to_i + (@vmc_app_start_query_timeout)
    begin
      debug("Starting the application #{app_name}")

      # get current app info again
      app = @admin_instance.app_info(app_name, false)
      return if ext_client.__health(app) == 'RUNNING'

      sleep(@vmc_app_query_interval)
    end while timeout_at >= Time.now.to_i

    app = @admin_instance.app_info(app_name, false)
    if ext_client.__health(app) != 'RUNNING'
      raise JobTimeoutError.new("Timeout: the application #{app_name} did not start in time.")
    end
  end
end