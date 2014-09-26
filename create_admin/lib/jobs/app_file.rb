require 'rubygems'

require 'jobs/job'
require 'route53/dns_gateway_client'

module Jobs
  class AppFileJob < Job
  end
end

class ::Jobs::AppFileJob
  def initialize(options)
    @app_name = options['app']
    @path = options['path']
  end
  
  def run
    begin
      @admin_instance.app_files(@app_name, @path, true) {|content|
        send_data(content, false)
      }
    rescue VMC::Client::TargetError => e
      error(e.message)
    end
    @requester.close
  end
end