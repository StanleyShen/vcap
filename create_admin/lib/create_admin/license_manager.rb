require 'rubygems'
require "wrest"
require 'json/pure'

require 'create_admin/admin_instance'
require 'patch/connection_factory_proxy_patch'

module CreateAdmin

  module LicenseManager
    include Wrest

    def get_license_credentials()
      admin_instace = CreateAdmin::AdminInstance.instance
      manifest = admin_instace.manifest(true)

      dns_provider_section = manifest['dns_provider']
      dns_gateway_url = dns_provider_section['dns_gateway_url']

      vm_token = dns_provider_section['vm_token']
      password = dns_provider_section['vm_password']
      dns_prefix = dns_provider_section['dns_prefix']

      sub_domain = manifest['sub_domain']

      if dns_prefix.nil? or dns_prefix == ''
        dns_prefix = dns_provider_section['vm_id'] || ''
        vm_hostname = "#{sub_domain}"
      else
        vm_hostname = "#{dns_prefix}#{sub_domain}"
      end
      
      vm_id = dns_prefix.slice(0, (dns_prefix.length-1))
      
      { :gateway_url => dns_gateway_url, :vm_id => vm_id, :token => vm_token, :password => password[1], :vm_hostname => vm_hostname }
    end

    def get_new_license(dns_gateway_url, vm_id_or_prefix, token, password)
      res = query(dns_gateway_url, 'get_vm_license', vm_id_or_prefix, token, password)
      if res.ok?
        license = res.body
        puts "Got new license"
        return license
      else
        puts "Failed to get license #{res.body}"
        raise "Unable to get license. Response code #{res.code}"
      end
    end

    def attach_license(url, username, access_token, license)
      puts "Importing license to #{url}"
      header = get_access_header(username, access_token)
      #puts "Using header #{header}"
      target = "#{url}/instance/import_license"
      header['Content-Type'] = 'application/octet-stream'
      res = target.to_uri(:timeout => 30).post(license,  header)

      raise "Failed to attach license #{res.code}" unless res.ok?
    end

    def get_license_status(dns_gateway_url, vm_id_or_prefix, token, password)
      res = query(dns_gateway_url, 'get_vm_license_status', vm_id_or_prefix, token, password)
      if res.ok?
        return JSON.parse(res.body)
      end

      raise "Unable to get license. Response code #{res.code}"
    end
    
    def get_license_terms(intalio_hostname)
      uri = "http://#{intalio_hostname}/instance/get_license_terms"
      debug "getting license from #{uri}"
      begin
        response = uri.to_uri(:timeout => 50).get()
        return JSON.parse(response.body) if response.ok?
      rescue Exception => e
        warn "Unable to get license #{e.message}"
        return ""
      end
    end

    private

    def query(gateway_url, path, vm_id_or_prefix, token, password)
      uri = URI(gateway_url)
      host = "#{uri.scheme}://#{uri.host}:#{uri.port}"
      puts "Quering gateway on #{host}/#{path}"
      data = {
        :vm_id => vm_id_or_prefix,
        :token => token,
        :password => password
      }
      "#{host}/#{path}".to_uri(:timeout => 30).get(data, {})
    end

    def get_access_header(username, access_token)
      access_req = {
        :Authorization => 'OAuth',
        :user => username,
        'access-token' => access_token
      }
    end

  end
end