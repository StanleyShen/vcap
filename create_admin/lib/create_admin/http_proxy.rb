require 'uri'
require 'net/http'
require 'net/http/digest_auth'

module HttpProxy
  def http_get(url_in)
    if ENV['http_proxy']
      proxy = URI.parse(ENV['http_proxy'])
      proxy_host, proxy_port = proxy.host, proxy.port if proxy
      proxy_user, proxy_password = proxy.userinfo.split(/:/) if proxy.userinfo
    end
    url = URI.parse(url_in)

    http = Net::HTTP.new(url.host, url.port, proxy_host, proxy_port, proxy_user, proxy_password)
    http.use_ssl = url.scheme == "https"
    http.read_timeout = 3600 # 1 hour for timeout, should be enough

    req = Net::HTTP::Get.new(url.path)
    if url.userinfo
      user, password = url.userinfo.split(/:/)
      req.basic_auth(user, password)
    end
    
    result = nil
    http.request(req){|res|
      if res.code == '401'
        # unauthorized, check whether it is one digest authtication
        if res['www-authenticate'] && res['www-authenticate'].start_with?("Digest")
          digest_auth = Net::HTTP::DigestAuth.new
          auth = digest_auth.auth_header url, res['www-authenticate'], 'GET'
          
          # create a new request with the Authorization header
          req = Net::HTTP::Get.new url.request_uri
          req.add_field 'Authorization', auth
  
          # re-issue request with Authorization
          if block_given?
            http.request(req) {|res2| yield(res2)}
          else
            result = http.request(req)
          end
        end
      else
        if block_given?
          yield(res)
        else
          result = res
        end
      end
    }
    
    return result
  end
end
