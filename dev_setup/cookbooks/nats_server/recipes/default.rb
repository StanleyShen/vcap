#
# Cookbook Name:: nats
# Recipe:: default
#
# Copyright 2011, VMware
#
compute_derived_attributes

# this will nicely try to start or restart nats_server and not complain if it is not there or something
execute "start-nats" do
  command "sudo /etc/init.d/nats_server start || sudo /etc/init.d/nats_server restart; exit 0"
  action :nothing
end

gem_package "nats" do
  gem_binary "sudo -u #{node[:deployment][:user]} #{File.join(node[:ruby][:path], "bin", "gem")}"
  notifies :run, "execute[start-nats]"
end

nats_config_dir = File.join(node[:deployment][:config_path], "nats_server")
node[:nats_server][:config] = File.join(nats_config_dir, "nats_server.yml")

directory nats_config_dir do
  owner node[:deployment][:user]
  mode "0755"
  recursive true
  action :create
  notifies :run, "execute[start-nats]"
  #notifies :restart, "service[nats_server]"
end

case node['platform']
when "ubuntu"
  template "nats_server" do
    path File.join("", "etc", "init.d", "nats_server")
    source "nats_server.erb"
    owner node[:deployment][:user]
    mode 0755
    notifies :run, "execute[start-nats]"
    #notifies :restart, "service[nats_server]"
  end
  
  template "vcap_reconfig" do
    path "/etc/init/vcap_reconfig.conf"
    source "vcap_reconfig.conf.erb"
    owner node[:deployment][:user]
    mode 0644
  end

  # runs /etc/init.d/nats_server (start|stop|restart), etc.
  #service "nats_server" do
  #  supports :status => true, :restart => true, :reload => true, :start => true, :stop => true
  #  action [ :enable, :start ]
  #end
else
  Chef::Log.error("Installation of nats_server not supported on this platform.")
end

template "nats_server.yml" do
  path node[:nats_server][:config]
  source "nats_server.yml.erb"
  owner node[:deployment][:user]
  mode 0644
  notifies :run, "execute[start-nats]"
  #notifies :restart, "service[nats_server]"
end


