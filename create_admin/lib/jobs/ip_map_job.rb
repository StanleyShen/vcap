require 'rubygems'

require 'jobs/job'
require 'route53/dns_gateway_client'

module Jobs
  class IPMapJob < Job
  end
end

class ::Jobs::IPMapJob

  def initialize(options)
    @ip = options['ip']
    raise "No ip provided" if (@ip.nil? || @ip.empty?)

    @manifest_path = options['manifest']
  end
  
  def run
    @manifest_path = @admin_instance.manifest_path(@manifest_path)

    total = 2
    at(0, total, "Preparing to update IP mapping")
    contents = File.open(@manifest_path, 'r') { |f| f.read }
    manifest_raw = JSON.parse(contents)
    dns_provider_section = manifest_raw['dns_provider']

    dns_provider_section['static_ip'] = @ip
    File.open(@manifest_path, 'w') {|f| f.write(JSON.pretty_generate(manifest_raw)) }

    at(1, total, "Updating local IP mapping")               
    vm_config = DnsProvider::DnsProviderVMConfig.new(@manifest_path)
    
    successful_bind = vm_config.call_dns_gateway
    debug "successful_bind :  #{successful_bind.to_json}"
    
    if successful_bind['success']
      completed('message' => 'IP Address Updated!')

      # refresh the manifest
      manifest = @admin_instance.manifest(true, @manifest_path)
    else
      rollback(manifest_raw)
      failed('ip_map' => 'failed', 'message' => successful_bind['message'])
    end      
      
  rescue => e
    error "Got exception #{e.message}"
    failed( {'message' => "IP mapping update failed: #{e.message}",
             'ip_map' => 'failed', 'exception' => e.backtrace })
  end
  
  private
  
  def rollback(manifest_raw)
    # rollback manifest changes
    unless(manifest_raw.nil?)
      dns_provider_section = manifest_raw['dns_provider']  
      dns_provider_section.delete('static_ip')
      File.open(@manifest_path, 'w') {|f| f.write(JSON.pretty_generate(manifest_raw)) }
    end
  end

end
