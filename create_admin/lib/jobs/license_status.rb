require 'rubygems'

require 'jobs/job'
require 'create_admin/license_manager'

module Jobs
  class LicenseStatusJob < Job
  end
end

class ::Jobs::LicenseStatusJob
  include CreateAdmin::LicenseManager
  
  def initialize(options)
    options = options || {}
    @manifest_path = options['manifest']
  end
  
  def run
    creds = get_license_credentials(@manifest_path)
    
    if(creds[:vm_id].nil? or creds[:token].nil? or creds[:password].nil?)
      return send_data({'status' => 'not_activated'}, true)
    end
    
    status = get_license_status(creds[:gateway_url], creds[:vm_id], creds[:token], creds[:password])
    send_data(status, true)
  end
end