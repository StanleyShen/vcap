require 'rubygems'

require 'jobs/job'
require 'route53/dns_gateway_client'
require 'vmc/vmcapphelpers'

module Jobs
  class StopAppJob < Job
  end
end

class ::Jobs::StopAppJob
  def initialize(options)
    options = options || {}

    @apps = options['apps']
    @vmc_app_query_interval = options['vmc_app_query_interval'] || 10
    @vmc_app_stop_query_timeout = options['vmc_app_stop_query_timeout'] || 60
      
    @master_test_uri = options['master_test_uri']
    @master_test_oauth_headers = options['master_test_oauth_headers']
  end
  
  def run
    res = {}
    @apps = @apps.nil? ? @admin_instance.governed_apps: @apps.split(",")
    @apps.each do |app_name|
      app = @admin_instance.app_info(app_name, false)
      if app[:state] != 'STOPPED'
        begin
          stop_app(app_name, app)
          # try to get the latest status again 
          app = @admin_instance.app_info(app_name, false)
          if app[:state] != 'STOPPED'
            res[app_name.to_sym] = 'stopping'
          else
            res[app_name.to_sym] = 'stopped'
          end
        rescue => e
          error("failed to stop #{app_name}")
          error(e)
          res[app_name.to_sym] = e.message
        end
      else
        res[app_name.to_sym] = 'stopped'
      end
    end
    res['success'] = true

    send_data(res, true)
  end

  def stop_app(app_name, app)
    retry_count = 1
    begin
      stopped = do_stop(app_name, app)
      return unless stopped

      do_master_test_should_fail unless @master_test_uri.nil?
      completed("The application #{app_name} was stopped", false)
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
  
  def do_master_test_should_fail
     master_test = @master_test_uri.to_uri(:timeout => 50).get({}, @master_test_oauth_headers)
     raise "Expecting a 404 from an intalio URL and got instead #{master_test.code}" unless master_test.code.to_str == "404"
  end
  
  def stop_total_ticks
    (@vmc_app_stop_query_timeout / @vmc_app_query_interval).to_i
  end
  
  def do_stop(app_name, app)
    return true if app[:state] == 'STOPPED'

    total_ticks = stop_total_ticks
    iteration = 0

    puts "[do_stop] tick to stop it now......"
    at(0, total_ticks, "Stopping the application #{app_name}")
    app[:state] = 'STOPPED'
    update_app(app_name, app)
    
    timeout_at = Time.now.to_i + (@vmc_app_stop_query_timeout)
    begin
      at(iteration, total_ticks, "Stopping the application #{app_name}")

      # get current app info again
      app = @admin_instance.app_info(app_name, false)
      return true if app[:state] == 'STOPPED'

      iteration = iteration + 1
      sleep(@vmc_app_query_interval)
    end while timeout_at >= Time.now.to_i

    if app[:state] != 'STOPPED'
      failed("Timeout: the application #{app_name} did not stop in time.", false)
      return false
    end
    true
  end
  
  def update_app(app_name, app)
    puts "[update_app] ..... for #{app_name}"
    begin
      client = @admin_instance.vmc_client(false)
      client.update_app(app_name, app)
    rescue VMC::Client::TargetError => te 
      if te.message.index('Error (JSON 502)').nil?
        raise te
      else
        # should not retry if its a 502 as it will instead
        # throw a 102 optimistic locking failure instead
        warn "Ignoring 502 from vcap while stopping."
        # just wait a while and we should be fine
        sleep(2)
      end
    end
  end
end