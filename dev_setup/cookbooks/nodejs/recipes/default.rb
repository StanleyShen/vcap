#
# Cookbook Name:: nodejs
# Recipe:: default
#
# Copyright 2011, VMware
#
#
compute_derived_attributes

node_bin_path=File.join(node[:nodejs][:path], "bin", "node")
expected_version=node[:nodejs][:version]
expected_version_found=`echo $(#{node_bin_path} --version 2>&1) | grep #{expected_version}` if File.exists?(node_bin_path)

raise "TESTING: node should have been detected as installed" unless expected_version_found

%w[ build-essential ].each do |pkg|
  package pkg
end

remote_file File.join("", "tmp", "node-v#{node[:nodejs][:version]}.tar.gz") do
  owner node[:deployment][:user]
  source node[:nodejs][:source]
  not_if do
    ::File.exists?(File.join("", "tmp", "node-v#{node[:nodejs][:version]}.tar.gz")) ||
        expected_version_found
  end
end


directory node[:nodejs][:path] do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode "0755"
  recursive true
  action :create
end

bash "Install Nodejs" do
  cwd File.join("", "tmp")
  user node[:deployment][:user] #does not work: CHEF-2288
  environment ({'HOME' => "/home/#{node[:deployment][:user]}",
                'USER' => "#{node[:deployment][:user]}"})
  code <<-EOH
  source $HOME/.bashrc
  rm -rf #{node[:nodejs][:path]}/*
  cd /tmp
  tar xzf node-v#{node[:nodejs][:version]}.tar.gz
  cd node-v#{node[:nodejs][:version]}
  ./configure --prefix=#{node[:nodejs][:path]}
  make
  make install
EOH
  not_if do
    expected_version_found
  end
end
