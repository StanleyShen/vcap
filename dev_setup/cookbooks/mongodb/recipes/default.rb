#
# Cookbook Name:: mongodb
# Recipe:: default
#
# Copyright 2011, VMware
#
#
remote_file File.join("", "tmp", "mongodb-linux-#{node[:kernel][:machine]}-#{node[:mongodb_node][:version]}.tgz") do
  owner node[:deployment][:user]
  source node[:mongodb_node][:source]
  not_if { ::File.exists?(File.join("", "tmp", "mongodb-linux-#{node[:kernel][:machine]}-#{node[:mongodb_node][:version]}.tgz")) }
end

directory File.join(node[:mongodb_node][:path], "bin") do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode "0755"
  recursive true
  action :create
end

bash "Install Mongodb" do
  cwd File.join("", "tmp")
  #user node[:deployment][:user] #does not work: CHEF-2288
  code <<-EOH
  sudo -i -u #{node[:deployment][:user]}
  tar xvzf mongodb-linux-#{node[:kernel][:machine]}-#{node[:mongodb_node][:version]}.tgz
  cd mongodb-linux-#{node[:kernel][:machine]}-#{node[:mongodb_node][:version]}
  cp #{File.join("bin", "*")} #{File.join(node[:mongodb_node][:path], "bin")}
  EOH
  not_if do
    ::File.exists?(File.join(node[:mongodb_node][:path], "bin", "mongo"))
  end
end
