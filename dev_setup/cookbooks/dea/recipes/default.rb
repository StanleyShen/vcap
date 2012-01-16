#
# Cookbook Name:: dea
# Recipe:: default
#
# Copyright 2011, VMWARE
#
#
%w{lsof psmisc librmagick-ruby}.each do |pkg|
  package pkg
end

node[:dea][:runtimes].each do |runtime|
  case runtime
  when "ruby19"
    include_recipe "ruby"
  when "ruby18"
    include_recipe "ruby::ruby18"
  else
    include_recipe "#{runtime}"
  end
end

[File.join("", "var", "vcap.local", "dea")].each do |dir|
  directory dir do
    owner node[:deployment][:user]
    group node[:deployment][:group]
    mode "0755"
    recursive true
    action :create
  end
end

template node[:dea][:config_file] do
  path File.join(node[:deployment][:config_path], node[:dea][:config_file])
  source "dea.yml.erb"
  owner node[:deployment][:user]
  mode 0644
end

cf_bundle_install(File.expand_path(File.join(node["cloudfoundry"]["path"], "dea")))
