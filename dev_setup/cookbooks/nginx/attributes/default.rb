include_attribute "deployment"
default[:nginx][:worker_connections] = 2048
default[:nginx][:dir] = File.join("", "etc", "nginx")
##default[:nginx][:vcap_log] = File.join(node[:deployment][:home], "sys", "log", "vcap.access.log")

default[:nginx][:client_max_body_size] = "256M"
default[:nginx][:proxy_connect_timeout] = 10
default[:nginx][:proxy_send_timeout] = 30
default[:nginx][:proxy_read_timeout] = 30
default[:nginx][:proxy_pass] = "http://vcap_router"

default[:nginx][:ssl][:config_dir] = "/etc/nginx/ssl"
default[:nginx][:ssl][:basename] = "autocf"

