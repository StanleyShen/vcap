require 'rubygems'
require 'wrest'
require 'json/pure'

require "jobs/job"
require "route53/dns_gateway_client"

module Jobs
  class DNSUpdateJob < Job
  end
end

class ::Jobs::DNSUpdateJob
  include Wrest

  def initialize(options)
    @manifest_path = options['manifest']
    @auth_headers = options['oauth_access_headers']
    @hostname = options['hostname']
  end
  
  def run()
    debug 'Performing hostname update'
    intalio_info = @admin_instance.app_info('intalio', false)
    org_hostname = intalio_info[:uris].first
    @manifest_path = @admin_instance.manifest_path(@manifest_path)

    total = 5
    if (org_hostname.nil? || org_hostname.empty?)
      failed "can't get the intalio uri."
      return
    end

    if (@auth_headers.nil? || @auth_headers.empty?)
      failed 'No access token provided'
      return
    end 

    msg = "Preparing to update dns to #{@hostname}"
    debug msg
    at(0, total, msg)

    msg = "Updating system setting"
    debug msg
    at(1, total, msg)
    update_system_setting(org_hostname)    
    sleep(1)
    
    update_manifest()
    sleep(1)

    msg = "Configuring hostname"
    debug msg
    at(2, total, msg)
    configure_app()
    sleep(1)

    msg = "Configuring aliases"
    at(3, total, msg)
    debug msg
    configure_etc_host()
    configure_etc_avahi_aliases()
    

    msg = "Restarting all"
    debug msg
    at(4, total, msg)
    sleep(1)
    
    restart_apps()
    msg = "Restart command sent"
    at(5, total, msg)
    debug msg
    DnsProvider.update_etc_issue("This installation of Intalio|Create is bound to #{@hostname}.")
 
    admin_app_info = @admin_instance.app_info('admin', false)
    
    info("admin_app_info now is .... #{admin_app_info}")
    
    completed
  rescue => e
    error "Got exception #{e.message}"
    failed( {'message' => "Update hostname failed: #{e.message}",
             'dns_update' => 'failed', 'exception' => e.backtrace })
  end
  
  private
  
  def update_system_setting(org_hostname)
    # TODO: this hardcoded system setting record id must be a problem for new record or deleted record
    system_settings = ['fd3f4c7d-8903-47c7-99bc-54a6b51c3fee', 'e0914da0-d56f-11e0-9572-0800200c9a66']
    system_setting_data = { :io_instance_url => "http://#{@hostname}" }
    debug "Updating hostname from #{org_hostname} to #{@hostname}"
    system_settings.each { |uuid|
      res = "https://#{org_hostname}/io_system_setting/#{uuid}".to_uri(:timeout => 30, :verify_mode => OpenSSL::SSL::VERIFY_NONE ).put('', @auth_headers, system_setting_data)
      raise "Unable to update system setting" unless res.ok?
    }
  end

  def update_manifest(clear_prefix=true)
    contents = File.open(@manifest_path, 'r') { |f| f.read }
    manifest_json = JSON.parse(contents)
    manifest_json['sub_domain'] = @hostname

    if clear_prefix
      dns_provider = manifest_json['dns_provider']
      dns_provider['vm_id'] = dns_provider['dns_prefix'] 
      dns_provider['dns_prefix'] = ''
      dns_provider['dns_published_ip'] = ''
    end
    debug "Updated manifest sub_domain to #{@hostname}"
    File.open(@manifest_path, 'w') {|f| f.write(JSON.pretty_generate(manifest_json)) }

    # refresh the manifest of the instance
    @admin_instance.manifest(true, @manifest_path)
  end
  
  def configure_app()
    manifest = @admin_instance.manifest(false, @manifest_path)
    client = @admin_instance.vmc_client(false, @manifest_path)

    configurer = VMC::KNIFE::RecipesConfigurationApplier.new(manifest, client)
    configurer.execute
  end
  
  def configure_etc_host()
    uris = manifest_uris()
    update_hosts = VMC::KNIFE::VCAPUpdateEtcHosts.new(uris.join(' '))

    udp = update_hosts.update_pending()
    debug "/etc/hosts Update pending #{udp} with #{uris}"

    if udp
      debug "Configuring /etc/hosts with uri: #{uris}"
      update_hosts.execute()
    else
      warn "Skipping /etc/hosts update"
    end
  end

  # Likely to be deprecated
  def configure_etc_avahi_aliases()
    if File.exist?('/etc/avahi/aliases')
      manifest = @admin_instance.manifest(false, @manifest_path)
      update_aliases = VMC::KNIFE::VCAPUpdateAvahiAliases.new(nil, manifest)
      update_aliases.do_exec = true
      update_aliases.execute
    else
      warn "Skipping avahi configuration"
    end
  end

  def restart_apps(fork=true)
    `echo "Application starting... This may take a few minutes." > /etc/issue.d/volatile.d/K50_applications_status`
    if(fork)
      pid = fork {
        restart()
      }
      Process.detach(pid)
    else
      restart()
    end
  end
  
  def restart
    manifest = @admin_instance.manifest(false, @manifest_path)
    client = @admin_instance.vmc_client(false, @manifest_path)

    configurer = VMC::KNIFE::RecipesConfigurationApplier.new(manifest, client)
    method_object = configurer.method(:restart)
    method_object.call
  end

  def manifest_uris()
    manifest = @admin_instance.manifest(false, @manifest_path)
    return [] unless manifest

    uris = []
    uris << manifest['target']

    manifest['recipes'].each do |recipe|
      recipe['applications'].each do | key, app |
        app['uris'].each do | uri |
          uris << uri
        end
      end
    end
    uris.uniq!
    uris
  end
end