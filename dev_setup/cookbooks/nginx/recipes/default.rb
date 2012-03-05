#
# Cookbook Name:: nginx-new
# Recipe:: default
#
# Copyright 2011, VMware
#
#
compute_derived_attributes
node[:nginx][:vcap_log] = File.join(node[:deployment][:home], "sys", "log", "vcap.access.log") unless node[:nginx][:vcap_log]
case node['platform']
when "ubuntu"
  package "nginx"
  template "nginx.conf" do
    path File.join(node[:nginx][:dir], "nginx.conf")
    source "ubuntu-nginx.conf.erb"
    owner "root"
    group "root"
    mode 0644
    notifies :reload, "service[nginx]"
  end

  service "nginx" do
    supports :status => true, :restart => true, :reload => true
    action [ :enable, :start ]
  end
else
  Chef::Log.error("Installation of nginx packages not supported on this platform.")
end
