#
# Cookbook Name:: dea
# Recipe:: default
#
# Copyright 2011, VMWARE
#
#
compute_derived_attributes

%w{lsof psmisc librmagick-ruby}.each do |pkg|
  package pkg
end

runtimes=node[:dea][:runtimes]
runtimes||=node[:dea][:runtimes_default]
node[:dea][:runtimes].each do |runtime|
  case runtime
  when "ruby19"
    include_recipe "ruby"
  when "ruby18"
    case node[:platform]
    when "ubuntu"
      if node[:platform_version].to_f >= 11.10
        raise "ruby18 not supported on this ubuntu for now."
      end
    end
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
  notifies :restart, "service[vcap_dea]"
end

cf_bundle_install(File.expand_path(File.join(node["cloudfoundry"]["path"], "dea")))

service "vcap_dea" do
  provider CloudFoundry::VCapChefService
  supports :status => true, :restart => true, :start => true, :stop => true
end

