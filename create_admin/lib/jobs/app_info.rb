require 'rubygems'

require 'jobs/job'
require 'route53/dns_gateway_client'
require 'vmc/vmcapphelpers'
require 'vmc/vmchelpers'

module Jobs
  class AppInfo < Job; end
end

class ::Jobs::AppInfo
  def self.job_name
    'Applications State'
  end
  
  def initialize(options)
    options = options || {}

    @apps = options['apps']
  end
  
  def run
    @apps = @apps.nil? ? @admin_instance.governed_apps: @apps.split(",")

    res = []
    client = @admin_instance.vmc_client(false)
    @apps.each{|app_name|
      info = client.app_info(app_name)
      # only return the instnaces, running instances, uris and state
      res << {
        'name' => info[:name],
        'state' => info[:state],
        'uris' => info[:uris],
        'instances' => info[:instances],
        'runningInstances' => info[:runningInstances]
      }
    }

    completed(res)
  end
end