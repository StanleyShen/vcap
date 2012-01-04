#
# Cookbook Name:: dns_publisher
# Recipe:: default
#
package "avahi-daemon"
package "python-avahi"

node[:dns_publisher][:config_file] = File.join(node[:deployment][:config_path], "dns_publisher.yml")

template node[:dns_publisher][:config_file] do
  path node[:dns_publisher][:config_file]
  source "dns_publisher.yml.erb"
  owner node[:deployment][:user]
  mode 0644
end

cf_bundle_install(File.expand_path(File.join(node["cloudfoundry"]["path"], "dns_publisher")))
