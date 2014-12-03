module Wrest::Native
  module ConnectionFactory
    def create_connection(options = {:timeout => 60, :verify_mode => OpenSSL::SSL::VERIFY_NONE})
      options[:timeout] ||= 60
      # We only use https for vanadium, else if there's no ssl, then it must be a local call  
      if ENV['https_proxy'] && self.https?
        proxy = URI.parse(ENV['https_proxy'])
        proxy_host, proxy_port = proxy.host, proxy.port if proxy
        puts "Using proxy #{proxy_host}:#{proxy_port}"
        proxy_user, proxy_password = proxy.userinfo.split(/:/) if proxy.userinfo
      end
              
      connection = Net::HTTP.new(self.host, self.port, proxy_host, proxy_port, proxy_user, proxy_password)  
      #connection = Net::HTTP.new(self.host, self.port)
      connection.read_timeout = options[:timeout]
      if self.https?
        connection.use_ssl     = true
        connection.verify_mode = options[:verify_mode] ? options[:verify_mode] : OpenSSL::SSL::VERIFY_PEER 
        connection.ca_path = options[:ca_path] if options[:ca_path]
      end
      connection
    end
  end
end