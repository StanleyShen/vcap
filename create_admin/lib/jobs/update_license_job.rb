require 'rubygems'
require 'json/pure'

require 'jobs/job'
require 'create_admin/license_manager'

module Jobs
  class UpdateLicenseJob < Job
  end
end

class ::Jobs::UpdateLicenseJob
  include CreateAdmin::LicenseManager

  def initialize(options)
    @user = options['user']
    raise "No user provided" if (@user.nil? || @user.empty?)

    @access_token = options['access_token']
    @success_msg = options['success_message'] || 'License has been updated.'
    raise "No access_token provided" if (@access_token.nil? || @access_token.empty?)

    @manifest_path = options['manifest'] || ENV['VMC_KNIFE_DEFAULT_RECIPE']
  end

  def run
    total = 2
    at(0, total, "Preparing to update license")

    creds = get_license_credentials(@manifest_path)

    license = get_new_license(creds[:gateway_url], creds[:vm_id], creds[:token], creds[:password])
    at(1, total, "Got updated license")
    
    url = "http://#{creds[:vm_hostname]}"
    attach_license(url, @user, @access_token, license)
    at(2, total, "Updated license")

    # wait for license to be refreshed
    sleep(60)
    completed('message' => @success_msg)
  rescue Exception => e
    error "Got exception #{e.message}"
    failed( {'message' => "License update failed: #{e.message}",
             'license_update' => 'failed', 'exception' => e.backtrace })
  end

end