#
# Cookbook Name:: mongodb
# Recipe:: default
#
# Copyright 2011, VMware
#
#
case node['platform']
when "ubuntu"
  package "cgroup-bin"
  package "libcgroup1" 
else
  Chef::Log.error("Installation of cgroup to limit the memory used by mongod is not supported on this platform.")
end

install_path = File.join(node[:deployment][:home], "deploy", "mongodb", node[:mongodb_node][:version])

mongodb_tarball_path = File.join(node[:deployment][:setup_cache], "mongodb-linux-#{node[:kernel][:machine]}-#{node[:mongodb_node][:version]}.tgz")

remote_file mongodb_tarball_path do
  owner node[:deployment][:user]
  source node[:mongodb_node][:source]
  not_if do
    ::File.exists?(mongodb_tarball_path)
  end  
end

directory File.join(install_path, "bin") do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode "0755"
  recursive true
  action :create
end

bash "Install Mongodb #{node[:mongodb_node][:version]}" do
  cwd File.join("", "tmp")
  user node[:deployment][:user]
  code <<-EOH
  echo `pwd`
  tar xvzf #{mongodb_tarball_path}
  cd mongodb-linux-#{node[:kernel][:machine]}-#{node[:mongodb_node][:version]}
  cp #{File.join("bin", "*")} #{File.join(install_path, "bin")}
  EOH
  not_if do
    ::File.exists?(File.join(install_path, "bin", "mongo"))
  end
end