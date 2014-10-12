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
    @app_intance = options['instance'] || 'ANY'
  end

  def run
    begin
      @admin_instance.app_files(@app_name, @path, @app_intance) {|content|
        @requester.send_data(content) if content && !content.empty?
      }
      update_execution_result({'_status' => CreateAdmin::JOB_STATES['success']})
    rescue VMC::Client::TargetError => e
      error(e.message)
      error e
      update_execution_result({'_status' => CreateAdmin::JOB_STATES['failed'], 'message' => e.message})
    end
    
    @requester.close
  end
end