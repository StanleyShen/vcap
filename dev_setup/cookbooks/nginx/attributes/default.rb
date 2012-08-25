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
default[:nginx][:ssl][:only_ssl] = false

default[:nginx][:ssl][:gen][:country_name] = "US"
default[:nginx][:ssl][:gen][:state_name] = "CA"
default[:nginx][:ssl][:gen][:locality_name] = "Palo Alto"
default[:nginx][:ssl][:gen][:organization_name] = "Research and Testing Not Incorported"
default[:nginx][:ssl][:gen][:organizational_unit_name] = "Research and Production Department"
default[:nginx][:ssl][:gen][:common_name] = nil # the server hostname
default[:nginx][:ssl][:gen][:ip_address] = nil
