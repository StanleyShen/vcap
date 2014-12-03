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
    EXPIRATION_WARNING_DAYS = 30 * 24 * 3600 # in seconds
    
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
      res = query_license_server(dns_gateway_url, 'get_vm_license', vm_id_or_prefix, token, password)
      if res.ok?
        license = res.body
        return license
      else
        error("Failed to get license #{res.body}")
        raise "Unable to get license. Response code #{res.code}"
      end
    end

    def attach_license(license)
      begin
        conn = get_postgres_db

        conn.exec('BEGIN')
        lo_desc, oid = CreateAdmin.create_large_object(license, conn)
        doc_id = get_license_document(conn)
        create_license_version(doc_id, oid, license.size, conn)
        conn.exec('COMMIT')
      rescue => e
        error("Failed to attach license, message: #{e.message}")
        error(e)
        raise "Failed to attach license: #{e.message}"
      ensure
        if conn
          conn.close
        end
      end
    end
    
    def delete_vm_license()
      # delete all the version of the intalio-license document
      delete_ver_sql = "delete from io_version where io_document in " +
        "(select d.io_uuid from io_document d, io_system_setting s where " +
        "d.io_related_to[1] = s.io_uuid and s.io_active = true and s.io_deleted = false " +
        "and d.io_name = 'intalio-license')"
      delete_doc_sql = "delete from io_document where io_related_to[1] in " +
        "(select io_uuid from io_system_setting where io_active = true and io_deleted = false) "
        "and io_name = 'intalio-license'"

      begin
        conn = get_postgres_db
        conn.exec('BEGIN')
        conn.exec(delete_ver_sql)
        conn.exec(delete_doc_sql)
        conn.exec('COMMIT')
        return true
      rescue => e
        error("Failed to remove the license, message: #{e.message}")
        error(e)
        false
      ensure
        if conn
          conn.close
        end
      end
    end

    def get_license_status(dns_gateway_url, vm_id_or_prefix, token, password)
      res = query_license_server(dns_gateway_url, 'get_vm_license_status', vm_id_or_prefix, token, password)
      if res.ok?
        return JSON.parse(res.body)
      end

      raise "Unable to get license. Response code #{res.code}"
    end
    
    def get_license_terms()
      sql = "select io_version.io_file from io_version, io_document where " +
              "io_version.io_document = io_document.io_uuid and " +
              "io_document.io_related_to[1] in (select io_uuid from io_system_setting where io_active = true and io_deleted = false) and " +
              "io_document.io_name = 'intalio-license' and io_document.io_deleted  = false order by io_version.io_number desc, io_version.io_updated_on desc limit 1"

      oid = query(sql) {|res|
        res.getvalue(0, 0).to_i
      }
      license = nil
      errors = []
      if oid
        val = nil
        begin
          conn = get_postgres_db
          conn.exec('BEGIN')
          lo_des = conn.lo_open(oid, PG::Constants::INV_READ)
          val = conn.lo_read(lo_des, 8192) # assume the license won't exceed 8KB bytes.(right now, it is less than 300 bytes)
          conn.exec('COMMIT')
        rescue => e
          error("Failed to read the large object #{oid} message: #{e.message}")
        ensure
          if conn
            conn.close
          end
        end

        if (val)
          gz = Zlib::GzipReader.new(StringIO.new(val))
          unzipp_val = gz.read
          license = parse_license(unzipp_val, errors)
        end
      end

      if license
        expires_time = DateTime.parse(license['expires-on']).to_time
        now = Time.now

        if (expires_time <=> now) == -1
          errors << {
            'message' => "Intalio|Create license has expired on #{license['expires-on']}",
            'type' => 'LicenseExpiredDateException',
            'solution' => 'Please contact Intalio (support@intalio.com) for an updated license.'
          }
        elsif ((now + EXPIRATION_WARNING_DAYS) <=> expires_time) == 1
          # needs to warning?
          errors << {
            'message' => "Intalio|Create license will expire on #{license['expires-on']}.",
            'type' => 'LicenseWillExpireException',
            'solution' => 'Please contact Intalio (support@intalio.com) for an updated license.'
          }
        end
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
      license
    end
    
    private

    def get_license_document(conn)
      sql = "select d.io_uuid from io_document d, io_system_setting s " +
        "where d.io_active = true and d.io_deleted = false and d.io_name = 'intalio-license' and " +
        "s.io_active = true and s.io_deleted = false and " +
        "d.io_related_to[1] = s.io_uuid " +
        "order by d.io_updated_on limit 1"

      res = conn.exec(sql)
      return res.getvalue(0, 0) if res.num_tuples > 0
      
      # need to create the license document
      sql = "select io_uuid from io_system_setting where io_active = true and io_deleted = false"
      res = conn.exec(sql)
      raise "NO active system setting!" if res.num_tuples <= 0

      sys_setting_id = res.getvalue(0, 0)
      doc_id = CreateAdmin.create_record('io_document', {
        'io_name' => 'intalio-license',
        'io_media_type' => '63de6288-bc48-11e0-8148-001ec950a80f', # "application/octet-stream"
        'io_public' => false,
        'io_private' => false,
        'io_related_to' => "{#{sys_setting_id},13108321-f4ee-446f-995f-9c051e1026c7}"
      })
      doc_id
    end
    
    def create_license_version(doc_uuid, oid, size, conn)
      # query the latest version number
      sql = "select io_number from io_version where io_active = true and io_deleted = false and io_document=$1 " +
        "order by io_number desc, io_updated_on desc limit 1"
      
      res = conn.exec_params(sql, [doc_uuid])
      ver_num = 1
      if res.num_tuples > 0
        ver_num = res.getvalue(0, 0).to_i + 1
      end
      
      ver_id = CreateAdmin.create_record('io_version', {
        'io_size_quantity' => "{#{size},263132378541201564204920243629027413178}",
        'io_private' => false,
        'io_name' => 'intalio-license',
        'io_number' => ver_num,
        'io_major' => true, 
        'io_type' => '{a4a36328-cf89-11e0-99e9-001ec950a80f}', # file type
        'io_file' => oid, 
        'io_file_name' => 'intalio-license',
        'io_media_type' => '63de6288-bc48-11e0-8148-001ec950a80f', # "application/octet-stream"
        'io_document' => doc_uuid
      })
      ver_id
    end
    
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
    
    def query_license_server(gateway_url, path, vm_id_or_prefix, token, password)
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

  end
end