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