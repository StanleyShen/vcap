#
# Cookbook Name:: nginx-new
# Recipe:: default
#
# Copyright 2011, VMware
#
#
compute_derived_attributes
case node['platform']
when "ubuntu"
  package "nginx-extras"
  template "nginx.conf" do
    path File.join(node[:nginx][:dir], "nginx.conf")
    source "ubuntu-nginx.conf.erb"
    owner "root"
    group "root"
    mode 0644
    notifies :reload, "service[nginx]"
  end

  bash "dont-echo-nginx-start" do
		# mysterious failure to start nginx with the latest beta build of 12.04 if something is echoed out.
    code <<-CMD
sed -i 's/[[:space:]]*echo -n "Starting/#this line prevents the startup at boot time on 12.04           echo -n "Starting/' /etc/init.d/nginx
		CMD
	end

  service "nginx" do
    supports :status => true, :restart => true, :reload => true
    action [ :enable, :start ]
  end

else
  Chef::Log.error("Installation of nginx packages not supported on this platform.")
end
