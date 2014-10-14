require 'rubygems'

require 'jobs/job'
require 'create_admin/license_manager'

module Jobs
  class LicenseStatusJob < Job
  end
end

class ::Jobs::LicenseStatusJob  
  def run
    host_name = intalio_host_name
    completed({'license' => get_license_terms(host_name)})   
  end
end