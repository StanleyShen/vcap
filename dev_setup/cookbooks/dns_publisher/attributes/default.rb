include_attribute "deployment"

default[:dns_publisher][:logging][:level] = "debug"
default[:dns_publisher][:publishers][:mdns_avahi][:enable] = true
default[:dns_publisher][:publishers][:mdns_avahi][:hostnames_filter] = "/\.local$/"
default[:dns_publisher][:publishers][:route53][:enable] = false
default[:dns_publisher][:publishers][:route53][:access_key] = "123"
default[:dns_publisher][:publishers][:route53][:secret_key] = "4567890"
default[:dns_publisher][:publishers][:route53][:hostnames_filter] = "/\.testzone\.intalio\.io$/"
default[:dns_publisher][:config_file] = File.join(node[:deployment][:config_path], "dns_publisher.yml")