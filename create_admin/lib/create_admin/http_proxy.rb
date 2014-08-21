require 'uri'
require 'net/http'
 
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

    req = Net::HTTP::Get.new(url.path)
    if url.userinfo
      user, password = url.userinfo.split(/:/)
      req.basic_auth(user, password)
    end

    if block_given?
      http.request(req) {|r| yield(r)}
    else
      return http.request(req)
    end
  end
end
