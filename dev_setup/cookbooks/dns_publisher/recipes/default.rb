#
# Cookbook Name:: dns_publisher
# Recipe:: default
#
package "avahi-daemon"
package "avahi-utils"
package "python-avahi"

add_to_vcap_components("dns_publisher")
template "dns_publisher.yml" do
  path node[:dns_publisher][:config_file]
  source "dns_publisher.yml.erb"
  owner node[:deployment][:user]
  mode 0644
end

cf_bundle_install(File.expand_path(File.join(node["cloudfoundry"]["path"], "dns_publisher")))

