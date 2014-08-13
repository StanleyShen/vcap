require "net/http"
require "uri"

module DnsProvider

  A_ROOT_SERVER = '198.41.0.4'
  def self.local_ip(route = A_ROOT_SERVER)
    if File.exists? "/var/run/openstack_public_ip4"
      #`wget --tries=1 --connect-timeout=10 -qO- http://169.254.169.254/latest/meta-data/public-ipv4`
      # assume that the OS has an init job that writes the openstack public IP in a temporary file.
      aws_ec2_public_ip=`cat /var/run/openstack_public_ip4`.strip
      return aws_ec2_public_ip unless aws_ec2_public_ip.nil? || aws_ec2_public_ip.empty?
    end
    begin
      route ||= A_ROOT_SERVER
      orig, Socket.do_not_reverse_lookup = Socket.do_not_reverse_lookup, true
      UDPSocket.open {|s| s.connect(route, 1); s.addr.last }
    rescue
      #ruby19 only; works on macosx
      begin
        ip = Socket.ip_address_list.detect do |intf|
          intf.ipv4? or intf.ipv4_private? and !(intf.ipv4_loopback? or intf.ipv4_multicast?)
        end
        ip.ip_address
      rescue
        #does not work on macosx
        # this is when the public internet is not reachable.
        # for example a 'Host-only' private network.
        ip=`/sbin/ifconfig | grep "inet addr" | grep -v "127.0.0.1" | awk '{ print $2 }' | awk -F: '{ print $2 }'`
        raise "Network unreachable." unless ip
        ip.strip
      end
    ensure
      Socket.do_not_reverse_lookup = orig
    end
  end

  def self.public_ip()
    begin
      puts "Getting public IP"
      uri = URI.parse("http://vanadium.cloud.intalio.com/route53/bind?my_ip=true")
      res = Net::HTTP.get_response(uri)
      return res.body if res.code == '200'
    rescue Exception => e
      puts "Exception when getting public IP #{e.message}"
    end
    puts "Can't get public IP"
    return nil
  end

  def self.update_etc_issue(vcap_status=nil)
    if vcap_status
      `echo "#{vcap_status}" > /etc/issue.d/volatile.d/K75_registration_app`
    else
      `[ -f /etc/issue.d/volatile.d/K50_applications_status.disabled ] && mv /etc/issue.d/volatile.d/K50_applications_status.disabled /etc/issue.d/volatile.d/K50_application_status`
      `rm /etc/issue.d/volatile.d/K75_registration_app`
    end
  end

  class DnsProviderVMConfig

    #TESTING: switch to 'true' and you can test the dns publish with the 'test' prefix. normal values is 'false' for both.
    BIND_DOT_LOCAL = false
    FORCE_DNS_PREFIX_TO_TEST = false
    DONT_UPDATE_KNIFE_RECIPE = false

    attr_reader :manifest
    attr_reader :manifest_path
    attr_reader :sub_domain
    attr_reader :vm_token
    attr_reader :vm_password
    attr_reader :dns_prefix
    attr_reader :dns_gateway_url
    attr_reader :local_ip
    attr_reader :use_public_ip

    def initialize(manifest_path=nil, reset=false)
      manifest_path ||= ENV['VMC_KNIFE_DEFAULT_RECIPE']
      manifest_path ||= "#{ENV['HOME']}/cloudfoundry/intalio_recipe.json"
      @manifest_path = manifest_path
      @manifest =VMC::KNIFE::JSON_EXPANDER.expand_json(@manifest_path)
      dns_provider_section = manifest['dns_provider']
      if dns_provider_section
        @vm_token = dns_provider_section['vm_token']
        vm_password_man = dns_provider_section['vm_password']
        @encrypted = vm_password_man.kind_of?(Array)
        if vm_password_man.kind_of?(Array)
          @vm_password = vm_password_man[1]
        elsif vm_password_man.kind_of?(String)
          @vm_password = vm_password_man unless vm_password_man.empty?
        end
        @dns_prefix = dns_provider_section['dns_prefix']
        @dns_prefix = "test." if (@dns_prefix.nil? || @dns_prefix.empty?) && FORCE_DNS_PREFIX_TO_TEST
        @dns_gateway_url = dns_provider_section['dns_gateway_url']
        @dns_published_ip = dns_provider_section['dns_published_ip']
      end
      @dns_gateway_url ||= "http://iridium.cloud.intalio.com/route53/publish"
      @sub_domain = manifest['sub_domain']
      @use_public_ip = manifest['dns_provider']['public_ip']

      ip_to_bind = DnsProvider.public_ip() if !reset and @use_public_ip and @use_public_ip != ''
      ip_to_bind = DnsProvider.local_ip() if ip_to_bind.nil?

      @local_ip = dns_provider_section['static_ip'] || ip_to_bind
    end

    # sets the dns_prefix to something else. on the object
    # but not yet on the manifest.
    # will append a '.' if there is no such thing.
    def set_dns_prefix_in_mem(dns_prefix)
      dns_prefix = dns_prefix+"." unless dns_prefix.end_with? "."
      @dns_prefix = dns_prefix
    end
    # sets the vm_password to something else on the object
    # but not yet on the manifest.
    def set_vm_token_in_mem(vm_token)
      @vm_token = vm_token
    end
    # sets the vm_password to something else on the object
    # but not yet on the manifest.
    def set_vm_password_in_mem(vm_password)
      @vm_password = vm_password
    end
    # sets the sub_domain to something else on the object
    # but not yet on the manifest.
    def set_sub_domain_in_mem(sub_domain)
      @sub_domain = sub_domain
    end

    def set_use_public_ip
      @use_public_ip = true
    end
    # Returns true if we can ping the dns_gateway and
    # if the recipe is incomplete with regard to the dns_provider
    # in that case the register app should be started.
    def should_start_register_app()
      return false if @sub_domain != "intalio.local"
      return true if !@vm_token || @vm_token.empty?
      return true if !@vm_password || @vm_password.empty?
      return true if !@dns_prefix || @dns_prefix.empty?
      return false
    end

    def is_ip_changed()
      @dns_published_ip != @local_ip
    end

    def should_call_dns_gateway()
      return false unless is_ip_changed()
      return false if !@sub_domain.end_with?(".io") && !BIND_DOT_LOCAL
      return true
    end

    # return { 'dns_prefix' => 'myapp', 'password' => '2S7uLKvUgjkoFH+lFS0VELnzp8YyfCbQUoPWShxwXV8=' } for success.
    # throws an exception otherwise.
    def call_dns_gateway()

      @sub_domain = 'intalio.io' if @sub_domain.end_with? '.local'
      #Note the following debug statement is true if we make all kinds of assumptions.
      #Good enough for now.
      puts "Calling the dns_gateway #{@dns_gateway_url} to bind #{@local_ip} to #{@dns_prefix}#{@sub_domain}, #{@dns_prefix}oauth.#{@sub_domain}, #{@dns_prefix}admin.#{@sub_domain} using public IP #{@use_public_ip}"
      #the dns_prefix and local_ip won't be used for now.
      gateway_url = URI.parse(@dns_gateway_url)
      puts "Using SSL #{gateway_url.scheme == 'https'} on port #{gateway_url.port}"
      response = Net::HTTP.start(gateway_url.host, gateway_url.port, :use_ssl => gateway_url.scheme == 'https') do |http|
        #query_string = URI.escape(query_string, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
        local_ip = escape_param(@local_ip.to_s)
        dns_prefix = escape_param(@dns_prefix.to_s)
        vm_token = escape_param(@vm_token.to_s)
        vm_password = escape_param(@vm_password.to_s)
        encrypted = escape_param(@encrypted.to_s)
        use_public_ip = escape_param(@use_public_ip.to_s)
        query_string = "ip=#{local_ip}&dns_prefix=#{dns_prefix}&vm_token=#{vm_token}&vm_password=#{vm_password}&encrypted=#{encrypted}&public_ip=#{use_public_ip}"
        #puts "Query string #{query_string}"
        req = Net::HTTP::Get.new("#{gateway_url.path}?#{query_string}")
        # route 53 operation is expected to be public
        req.basic_auth gateway_url.user, gateway_url.password if gateway_url.user

        http.request(req)
      end

      if response.code.to_s != "200"
        puts "Unexpected response code returned by the dns_gateway: #{response.code}"
        puts response.body
        raise "Unexpected response code returned by the dns_gateway: #{response}"
      end
      begin
        successful_bind = JSON.parse(response.body, :symbolize_names => false)

      rescue
        raise "Unexpected response body format returned by the dns_gateway: #{response.body}"
      end
    end

    def escape_param(param)
      URI.escape(param, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
    end

    # successful_bind: { 'ip' => '192.168.0.110', 'dns_prefix' => 'myapp', 'password' => '2S7uLKvUgjkoFH+lFS0VELnzp8YyfCbQUoPWShxwXV8=' }
    def update_manifest_ip(successful_bind, vm_password_in_clear=nil)
      return unless is_ip_changed()
      puts "Updating the published IP from #{@dns_published_ip} to #{@local_ip}"
      infile = File.open(@manifest_path, "r")
      manifest_src=JSON.parse infile.read
      infile.close
      unless manifest_src['dns_provider']
        manifest_src['dns_provider']=Hash.new
      end
      #ip
      ip = successful_bind['ip'] || @local_ip
      manifest_src['dns_provider']['dns_published_ip']=ip
      manifest_src['dns_provider']['public_ip'] = true if @use_public_ip
      @dns_published_ip=ip

      #password:
      if successful_bind['password']
        manifest_src['dns_provider']['vm_password']=successful_bind['password']
        @vm_password=successful_bind['password']
      end

      #token:
      if successful_bind['token']
        manifest_src['dns_provider']['vm_token']=successful_bind['token']
        @vm_token=successful_bind['token']
      end

      #dns_prefix
      if successful_bind['dns_prefix']
        successful_bind['dns_prefix'] = successful_bind['dns_prefix']+"." unless successful_bind['dns_prefix'].end_with? "."
        manifest_src['dns_provider']['dns_prefix']=successful_bind['dns_prefix']
        @dns_prefix=successful_bind['dns_prefix']
        @sub_domain = successful_bind['sub_domain'] || 'intalio.io'
        manifest_src['sub_domain'] = @sub_domain
      end

      if vm_password_in_clear
        manifest_src['password'] = vm_password_in_clear
      end

      # default user after registration
      manifest_src['default_user'] = 'system'

      unless DONT_UPDATE_KNIFE_RECIPE
        File.open(@manifest_path, 'w') do |f|
          f.write(JSON.pretty_generate(manifest_src))
        end
      else
        puts "DEBUGGING: The updated manifest after the dns_success would contain the following dns_provider section: #{manifest_src['dns_provider'].to_json}"
      end
    end

    def reset_manifest()
      puts "Reset the IP, sub_domain and vm_token, vm_password, dns_prefix, default_user of #{@manifest_path} and the system's user password to Intalio2012 in pg_intalio"
      infile = File.open(@manifest_path, "r")
      manifest_src=JSON.parse infile.read
      infile.close
      if manifest_src['dns_provider']
        manifest_src['dns_provider']['vm_token']=""
        manifest_src['dns_provider']['vm_password']=""
        manifest_src['dns_provider']['dns_prefix']=""
        manifest_src['dns_provider']['dns_published_ip']=""
        manifest_src['dns_provider'].delete('public_ip')
      end
      manifest_src['sub_domain']='intalio.local' if manifest_src['sub_domain']
      manifest_src['default_user']='system' if manifest_src['default_user']

      File.open(@manifest_path, 'w') do |f|
        f.write(JSON.pretty_generate(manifest_src))
      end

      # reset the password of the system user too.
      #pass="Intalio2012" unfortunately we don't have a
      # cmd-line utility to run sscrypt. so the encrypted pass is hardcoded here.
      salt="X9NelN8Rg/I9rWOssYCN1Q=="
      spass="hx5ORCbrubBRC2dXypAQhEjl3j+kW2ejv1jOCgJ/pHY="
      password=[salt,spass]
      command = "update io_user set io_password=ARRAY['#{password[0]}','#{password[1]}'] where io_username='system'"
      puts `vmc_knife data-shell pg_intalio "#{command}"`

    end
  end

end
