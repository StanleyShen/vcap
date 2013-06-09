#
# Cookbook Name:: nginx-new
# Recipe:: default
#
# Copyright 2011, VMware
#
#
template "openssl-gen-conf.cnf" do
  path File.join(node[:deployment][:config_path], "openssl-gen-conf.cnf")
  source "openssl-gen-conf.cnf.erb"
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode 0755
end

bash "dont-echo-nginx-start" do
    # mysterious failure to start nginx with the latest beta build of 12.04 if something is echoed out.
    code <<-CMD
export CLOUD_FOUNDRY_CONFIG_PATH=#{node[:deployment][:config_path]}
echo "CLOUD_FOUNDRY_CONFIG_PATH $CLOUD_FOUNDRY_CONFIG_PATH"
bash -x #{node[:cloudfoundry][:path]}/dev_setup/bin/vcap_generate_ssl_cert_self_signed
CMD
  notifies :reload, "service[nginx]"
  not_if do
    ::File.exists?(File.join(node[:nginx][:ssl][:config_dir],node[:nginx][:ssl][:basename]+".crt"))
  end
end


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
