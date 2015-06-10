#
# Cookbook Name:: nodejs
# Recipe:: default
#
# Copyright 2011, VMware
#
#

%w[ build-essential ].each do |pkg|
  package pkg
end

nodejs_tarball_path = File.join(node[:deployment][:setup_cache], "node-v#{node[:nodejs][:version]}-linux-x64.tgz")

remote_file nodejs_tarball_path do
  owner node[:deployment][:user]
  source node[:nodejs][:source]
  action :create_if_missing
end

bash "Delete Nodejs if present" do
  user node[:deployment][:user]
  code <<-EOH
  rm -rf #{node[:nodejs][:path]} || true
  EOH
  only_if do
    ::File.exists?(node[:nodejs][:path])
  end
end

bash "Install Nodejs #{node[:nodejs][:version]}" do
  cwd File.join("", "tmp")
  user node[:deployment][:user]
  code <<-EOH
  tar xvzf #{nodejs_tarball_path}
  mv node-v#{node[:nodejs][:version]}-linux-x64 #{node[:nodejs][:path]}
  EOH
end

