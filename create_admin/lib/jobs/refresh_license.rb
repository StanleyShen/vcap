require 'rubygems'

require 'jobs/job'
require 'create_admin/license_manager'

module Jobs
  class RefreshLicense < Job
  end
end

class ::Jobs::RefreshLicense
  include CreateAdmin::LicenseManager
  
  def initialize(options)
    @user = options['user']
    raise 'No user provided.' if (@user.nil? || @user.empty?)

    @access_token = options['access_token']
    raise "No access_token provided" if (@access_token.nil? || @access_token.empty?)
  end
  
  def run
    # is activated?
    creds = get_license_credentials()    
    if(creds[:vm_id].nil? || creds[:token].nil? || creds[:password].nil?)
      return failed({'_code' => 'not_activated'}, true)
    end
    
    intalio_info = @admin_instance.app_info('intalio')
    return failed({'message' => 'No intalio Instance is running.', '_code' => 'intalio_app_not_available'}) if intalio_info[:runningInstances] <= 0

    # license from license server
    remote_status = get_license_status(creds[:gateway_url], creds[:vm_id], creds[:token], creds[:password])
    return_code = remote_status['status']

    case remote_status['status']
      when 'available', 'exists'
        # update the license
        update_license(creds)

      when 'unavailable'
        # can't find the license from license server, need to delete the license from the target vm
        url = "http://#{creds[:vm_hostname]}"
        response = delete_vm_license(url, @user, @access_token)
        if response.ok?
          debug 'license is deleted because of not available from server.'  
        else
          debug 'falied to delete license, code #{response.code}'
        end
      else
    end

    # get the license again
    completed({'_code' => return_code, 'license' => get_license_terms(intalio_host_name)})
  end
  
  private  
  def need_update?(current_license, remote_status)
    current_ver = current_license['license-version'].to_s
    current_expires_on = DateTime.parse(current_license['expires-on']).to_time.to_s
    current_trial = current_license['trial'].to_s
    current_max_user = current_license['maximum-active-users']['maximum'].to_s
    current_des = current_license['description'].to_s
    current_contact = current_license['contact-email'].to_s
      
    remote_ver = remote_status['license-version'].to_s
    remote_contact = remote_status['contact-email'].to_s
    remote_des = remote_status['description'].to_s
    remote_max_user = remote_status['maximum-active-users'].to_s
    remote_expires_on = DateTime.parse(remote_status['expires-on']).to_time.to_s
    remote_trial = remote_status['trial'].to_s

    if (current_ver != remote_ver) ||
      (current_expires_on != remote_expires_on) ||
      (current_trial != remote_trial) ||
      (current_max_user != remote_max_user) ||
      (current_des != remote_des) ||
      (current_contact != remote_contact)
      return true;
    end
    
    return false
  end
  
  def update_license(creds)
    license = get_new_license(creds[:gateway_url], creds[:vm_id], creds[:token], creds[:password])

    url = "http://#{creds[:vm_hostname]}"
    attach_license(url, @user, @access_token, license)
  end
end