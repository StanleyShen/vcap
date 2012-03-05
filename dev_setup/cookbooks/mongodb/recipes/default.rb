#
# Cookbook Name:: mongodb
# Recipe:: default
#
# Copyright 2011, VMware
#
#
compute_derived_attributes
node[:mongodb_node][:path] = File.join(node[:deployment][:home], "deploy", "mongodb") unless node[:mongodb_node][:path]

mongod_bin_path=node[:mongodb_node][:path]
expected_version=node[:mongodb_node][:version]
expected_version_found=`echo $(#{mongod_bin_path} --version 2>&1) | grep v#{expected_version}` if File.exists?(node_bin_path)


remote_file File.join("", "tmp", "mongodb-linux-#{node[:kernel][:machine]}-#{node[:mongodb_node][:version]}.tgz") do
  owner node[:deployment][:user]
  source node[:mongodb_node][:source]
  not_if do
    expected_version_found ||
        ::File.exists?(File.join("", "tmp", "mongodb-linux-#{node[:kernel][:machine]}-#{node[:mongodb_node][:version]}.tgz"))
  end
end

bash "Install Mongodb" do
  cwd File.join("", "tmp")
  user node[:deployment][:user] #does not work: CHEF-2288
  environment ({'HOME' => "/home/#{node[:deployment][:user]}",
                'USER' => "#{node[:deployment][:user]}"})
  code <<-EOH
source $HOME/.bashrc
cd /tmp
tar xvzf mongodb-linux-#{node[:kernel][:machine]}-#{node[:mongodb_node][:version]}.tgz
cd mongodb-linux-#{node[:kernel][:machine]}-#{node[:mongodb_node][:version]}
[ -d #{node[:mongodb_node][:path]} ] && rm -rf #{node[:mongodb_node][:path]}/*
cp #{File.join("bin", "*")} #{File.join(node[:mongodb_node][:path], "bin")}
EOH
  not_if do
    expected_version_found
  end
end

directory File.join(node[:mongodb_node][:path], "bin") do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode "0755"
  recursive true
  action :create
end
