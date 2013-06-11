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
  notifies :restart, "service[vcap_router]"
end

cf_bundle_install(File.expand_path(File.join(node["cloudfoundry"]["path"], "router")))
add_to_vcap_components("router")

service "vcap_router" do
  provider CloudFoundry::VCapChefService
  supports :status => true, :restart => true, :start => true, :stop => true
  action [ :start ]
end
