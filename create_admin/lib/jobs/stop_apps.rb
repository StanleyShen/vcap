require 'rubygems'

require 'jobs/job'
require 'route53/dns_gateway_client'
require 'vmc/vmcapphelpers'

module Jobs
  class StopAppJob < Job
  end
  class JobTimeoutError < StandardError
  end
end

class ::Jobs::StopAppJob
  attr_accessor :total_steps, :iteration

  def self.job_name
    'Stop Application'
  end
  
  def initialize(options)
    options = options || {}

    @apps = options['apps']
    @vmc_app_query_interval = options['vmc_app_query_interval'] || 10
    @vmc_app_stop_query_timeout = options['vmc_app_stop_query_timeout'] || 60

    @iteration = 0    
  end
  
  def run
    @apps = @apps.nil? ? @admin_instance.governed_apps: @apps.split(",")
    @total_steps = 2 * @apps.size

    begin
      @apps.each{|app_name|
        # try to stop the appliation then
        stop_app(app_name)
       }
    rescue Jobs::JobTimeoutError => e
      error e.message
      failed({'message' => e.message, 'reason' => 'timeout'})
      return
    end
    completed("Applications: #{@apps.join(', ')} are stopped successfully.")
  end

  def total_steps
    @total_steps = @total_steps || 2 * @apps.size
  end

  def start_step
    0
  end

  def output_status(message, step = 1)
    @iteration = @iteration + step
    at(@iteration, total_steps, message)
  end
  
  def stop_app(app_name)
    app = @admin_instance.app_info(app_name, false)
    if app[:state] == 'STOPPED'
      # output the status
      output_status("Application #{app_name} was already stopped.", 2)
      return
    end
    
    retry_count = 1

    output_status("Trying to stop the application #{app_name}.")    
    begin
      stopped = @admin_instance.stop_app(app_name)
      if (stopped)
        output_status("Application #{app_name} is stopped.")
        return
      end

      ensure_stopped(app_name)
      output_status("Application #{app_name} is stopped.")
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

  private
  def ensure_stopped(app_name)
    timeout_at = Time.now.to_i + (@vmc_app_stop_query_timeout)
    begin
      debug("Stopping the application #{app_name}")

      # get current app info again
      app = @admin_instance.app_info(app_name, false)
      return if app[:state] == 'STOPPED'

      sleep(@vmc_app_query_interval)
    end while timeout_at >= Time.now.to_i

    if app[:state] != 'STOPPED'
      raise JobTimeoutError.new("Timeout: the application #{app_name} did not stop in time.")
    end
  end
end