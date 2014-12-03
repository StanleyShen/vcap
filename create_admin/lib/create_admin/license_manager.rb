require 'rubygems'
require "wrest"
require 'json/pure'
require 'stringio'
require 'zlib'
require "openssl"
require "base64"
require 'time'

require "dataservice/postgres_ds"
require 'create_admin/admin_instance'
require 'create_admin/util'
require 'patch/connection_factory_proxy_patch'

module CreateAdmin

  module LicenseManager
    include Wrest
    include ::DataService::PostgresSvc

    # below variables from IntalioLicense, must change it accordingly if they are changed in IntalioLicense
    MODULES = "80F87195F5BDDCD483D4F133341FB403486B570A96E2FB61982ABAE143A74E687715842D50A2226E87054CE8B6CA3B6C561975FE95C7BC5562501A32FB583C49".to_i(16)
    PUBLIC_EXPONENT = "10001".to_i(16)
    EXPIRATION_WARNING_DAYS = 30
    
    DEFAULT_MAX_USERS = 3
    DEFAULT_LICENSE = {
      'description' => 'default license',
      'maximum-active-users' => {
        'maximum' => DEFAULT_MAX_USERS
      },
      'license-version' => '0'
    }
    
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
    
    def delete_vm_license(url, username, access_token)
      puts "start to delete the vm license because it isn't available in sever"
      header = get_access_header(username, access_token)

      target = "#{url}/instance/delete_license"
      res = target.to_uri(:timeout => 30).post(license,  header)

      res
    end

    def get_license_status(dns_gateway_url, vm_id_or_prefix, token, password)
      res = query(dns_gateway_url, 'get_vm_license_status', vm_id_or_prefix, token, password)
      if res.ok?
        return JSON.parse(res.body)
      end

      raise "Unable to get license. Response code #{res.code}"
    end
    
    def get_license_terms(intalio_hostname)
      sql = "select io_version.io_file from io_version, io_document where " +
              "io_version.io_document = io_document.io_uuid and " +
              "io_document.io_related_to[1] in (select io_uuid from io_system_setting where io_active = true and io_deleted = false) and " +
              "io_document.io_name = 'intalio-license' and io_document.io_deleted  = false order by io_version.io_number desc, io_version.io_updated_on desc limit 1"

      oid = query(sql) {|res|
        res.getvalue(0, 0)
      }

      license = nil, errors = []  
      if oid
        conn = get_postgres_db
        conn.exec('BEGIN')
        lo_des = conn.lo_open(oid, PG::Constants::INV_READ)
        val = conn.lo_read(lo_des, 8192) # assume the license won't exceed 8KB bytes.(right now, it is less than 300 bytes)
        conn.exec('COMMIT')
        
        if (val)
          gz = Zlib::GzipReader.new(StringIO.new(val))
          unzipp_val = gz.read
          license = parse_license(unzipp_val, errors)
        end
      end

      if license
        
        #          expires_on = license['expires-on'],
        #          cur_time = Time.now
        #          expire_time = new Date(expires_on);
        #    
        #          if (expire_time.getTime() < cur_time.getTime()) {
        #            // expired
        #            errors.push({
        #              message: util.format('Intalio|Create license has expired on %s', expires_on),
        #              type: "LicenseExpiredDateException",
        #              solution: "Please contact Intalio (support@intalio.com) for an updated license."
        #            })
        #          } else {
        #            // needs to warning?
        #            cur_time.setDate(cur_time.getDate() + EXPIRATION_WARNING_DAYS);
        #            if (expire_time.getTime() < cur_time.getTime()) {
        #              // it will expire in 30 days
        #              errors.push({
        #                message: util.format('Intalio|Create license will expire on %s.', expires_on),
        #                type: "LicenseWillExpireException",
        #                solution: "Please contact Intalio (support@intalio.com) for an updated license."
        #              })
        #            }
        #          }
        
                  # convert the maximum-active-users data
                  max_user = license['maximum-active-users']
                  license['maximum-active-users'] = {'maximum' => max_user}
      else
        license = DEFAULT_LICENSE
        license['expires-on'] = Time.now.iso8601()
  
        errors << {
          'message' => "Intalio|Create license has expired on #{license['expires-on']}.",
          'type' => 'LicenseExpiredDateException',
          'solution' => 'Please contact Intalio (support@intalio.com) for an updated license.'
        }
        errors << {
          'message' => 'The version of your Intalio|Create license is incompatible with the Intalio|Create product version you are running.',
          'type' => 'LicenseExpiredVersionException',
          'solution' => 'Please contact Intalio (support@intalio.com) for an updated license.'
        }
      end
      
      # update the active user account
      license['maximum-active-users']['current'] = CreateAdmin.active_user_num(true)

      license['errors'] = errors
    end
    
    private

    def parse_license(val, errors)
      l, s = [], []
      saw_break = false

      lines = val.split("\n")
      lines.each{|line|
        if line.start_with?('--')
          saw_break = true
          next
        end

        if saw_break
          s << line
        else
          l << line
        end 
      }

      license = l.join("\n")
      signature = s.join("\n")

      # decrypt
      pub = OpenSSL::PKey::RSA::new
      pub.e = PUBLIC_EXPONENT
      pub.n = MODULES

      successful = pub.verify("MD5", Base64.decode64(signature), license.force_encoding("utf-8"))
      if !successful
        errors << {
          'message' => 'Intalio|Create license could not be decrypted.',
          'type' => 'LicenseDecryptionException',
          'solution' => 'Please contact Intalio (support@intalio.com) for an updated license.'
        }
      end

      JSON.parse(license)
    end
    
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