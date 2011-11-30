#
# Cookbook Name:: router
# Recipe:: default
#
# Copyright 2011, VMware
#
template node[:router][:config_file] do
  path File.join(node[:deployment][:config_path], node[:router][:config_file])
  source "router.yml.erb"
  owner node[:deployment][:user]
  mode 0644
end

cf_bundle_install(File.expand_path(File.join(node["cloudfoundry"]["path"], "router")))

# Install the support for avahi to publish the *.local URLs with multicast-DNS
case node[:router][:enable_mdns_avahi_aliases] && node['platform']
when "ubuntu"
  if node[:cloud_controller][:external_uri] =~ /\.local$/ 
    package "avahi-daemon"
    package "python-avahi"
    bash "Install avahi-alias support" do
      code <<-EOH
if [ ! -d "/tmp/avahi-aliases" ]; then
  cd /tmp
  git clone https://github.com/hmalphettes/avahi-aliases.git
  cd avahi-aliases
  ./install.sh
  # now make the aliases accessible to the user so that we can add/remove aliases
  # from here.
  touch o+w /etc/avahi/aliases
  touch o+r /etc/avahi/aliases
fi
EOH
    end
  end
end
