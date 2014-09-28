require 'rubygems'

require 'jobs/job'
require 'create_admin/license_manager'

module Jobs
  class LicenseStatusJob < Job
  end
end

class ::Jobs::LicenseStatusJob
  include CreateAdmin::LicenseManager
  
  def run
    creds = get_license_credentials()
    
    if(creds[:vm_id].nil? || creds[:token].nil? || creds[:password].nil?)
      return failed({'reason' => 'not_activated'}, true)
    end
    
    status = get_license_status(creds[:gateway_url], creds[:vm_id], creds[:token], creds[:password])
    completed(status)
  end
end