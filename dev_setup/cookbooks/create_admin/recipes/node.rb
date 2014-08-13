#
# Cookbook Name:: create_admin
# Recipe:: default
#

template node[:create_admin][:config_file] do
  path File.join(node[:deployment][:config_path], node[:create_admin][:config_file])
  source "create_admin.yml.erb"
  owner node[:deployment][:user]
  mode 0644
end

cf_bundle_install(File.expand_path(File.join(node["cloudfoundry"]["path"], "create_admin")))
add_to_vcap_components("create_admin")

service "create_admin" do
  provider CloudFoundry::VCapChefService
  supports :status => true, :restart => true, :start => true, :stop => true
  action [ :start ]
end
