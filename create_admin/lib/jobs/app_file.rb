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
#    
#    client = @admin_instance.vmc_client
#    app_infos = client.app_instances(@app_name)
#
#    # send an empty string to client 
#    return @requester.close if app_infos.is_a?(Array)
#
#    instances = app_infos[:instances] || []
#    instances.each do |instance|
#      begin
#        content = client.app_files(@app_name, @path, instance[:index])
#        send_data(content, false)
#      rescue VMC::Client::TargetError => e
#        error(e.message)
#      end      
#    end
#
#    @requester.close
  end
end