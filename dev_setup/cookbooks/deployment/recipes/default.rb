#
# Cookbook Name:: deployment
# Recipe:: default
#
# Copyright 2011, VMware
#

node[:nats_server][:host] ||= cf_local_ip
node[:ccdb][:host] ||= cf_local_ip
node[:postgresql_node][:host] ||= cf_local_ip

[node[:deployment][:home], File.join(node[:deployment][:home], "deploy"), node[:deployment][:log_path],
 File.join(node[:deployment][:home], "sys", "log"), node[:deployment][:config_path],
 File.join(node[:deployment][:config_path], "staging"),
 File.join("/var/vcap", "shared"),
 File.join("/var/vcap/shared", "staged")].each do |dir|
  directory dir do
    owner node[:deployment][:user]
    group node[:deployment][:group]
    mode "0755"
    recursive true
    action :create
  end
end

var_vcap = File.join("", "var", "vcap")
[var_vcap, File.join(var_vcap, "sys"), File.join(var_vcap, "db"), File.join(var_vcap, "services"),
 File.join(var_vcap, "data"), File.join(var_vcap, "data", "cloud_controller"),
 File.join(var_vcap, "sys", "log"), File.join(var_vcap, "data", "cloud_controller", "tmp"),
 File.join(var_vcap, "data", "cloud_controller", "staging"),
 File.join(var_vcap, "data", "db"), File.join("", "var", "vcap.local"),
 File.join("", "var", "vcap.local", "staging")].each do |dir|
  directory dir do
    owner node[:deployment][:user]
    group node[:deployment][:group]
    mode "0755"
    recursive true
    action :create
  end
end

template node[:deployment][:info_file] do
  path node[:deployment][:info_file]
  source "deployment_info.json.erb"
  owner node[:deployment][:user]
  mode 0644
  variables({
    :name => node[:deployment][:name],
    :ruby_bin_dir => File.join(node[:ruby][:path], "bin"),
    :cloudfoundry_path => node[:cloudfoundry][:path],
    :deployment_log_path => node[:deployment][:log_path]
  })
end

template "hostname_uniq_if_up" do
  path File.join("", "etc", "network", "if-up.d", "hostname_uniq")
  source "hostname_uniq_if_up.erb"
  mode 0755
end

template "etc_issue_with_ip" do
  path File.join("", "etc", "network", "if-up.d", "update-etc-issue")
  source "etc_issue_with_ip.erb"
  owner node[:deployment][:user]
  mode 0755
end

template "etc_issue.conf" do
  path File.join("", "etc", "init", "etc_issue.conf")
  source "etc_issue.conf.erb"
  owner "root"
  mode 0644
end

template "etc_issue_update" do
  path File.join("", "etc", "issue_update")
  source "etc_issue_update.erb"
  owner "root"
  mode 0755
end

template node[:deployment][:vcap_exec] do
  path node[:deployment][:vcap_exec]
  source "vcap.erb"
  owner node[:deployment][:user]
  mode 0755
end

case node['platform']
when "ubuntu"
    bash "Create some symlinks and customize .bashrc" do
      code <<-EOH
cd #{node[:cloudfoundry][:home]}
# few symbolic links (todo: too many assumptions on the layout of the deployment)
[ -h log ] && rm log
ln -s #{node[:deployment][:log_path]} log
[ -h config ] && rm config
ln -s #{node[:deployment][:config_path]} config
[ -h deployed_apps ] && rm deployed_apps
mkdir -p /var/vcap.local/dea/apps
ln -s /var/vcap.local/dea/apps deployed_apps

cd #{ENV["HOME"]}
# add the local_run_profile to the user's  home.
grep_it=`grep #{node[:deployment][:local_run_profile]} .bashrc`
[ -z "$grep_it" ] && echo "source #{node[:deployment][:local_run_profile]}" >> .bashrc
grep_it=`grep alias\\ #{node[:deployment][:vcap_exec_alias]}= .bashrc`
[ -z "$grep_it" ] && echo "alias #{node[:deployment][:vcap_exec_alias]}='#{node[:deployment][:vcap_exec]}'" >> .bashrc
grep_it=`grep alias\\ _psql= .bashrc`
[ -z "$grep_it" ] && echo "alias _psql='sudo -u postgres psql'" >> .bashrc
grep_it=`grep alias\\ _mongo= .bashrc`
[ -z "$grep_it" ] && echo "alias _mongo='#{node[:deployment][:home]}/deploy/mongodb/bin/mongo'" >> .bashrc
exit 0
EOH
Chef::Log.warn("Code to exec for customizing the deployment #{code}")
  end
  
  node[:deployment][:etc_hosts][:api_dot_domain].each do |ip|
    bash "Bind #{ip} to api.#{node[:deployment][:domain]} in /etc/hosts" do
    user "root"
    code <<-EOH
binding_exists=`grep -E '#{Regexp.escape(ip)}[[:space:]].*[[:space:]]api\.#{Regexp.escape(node[:deployment][:domain])}[^[:alnum:]]?'`
if [ -z "$binding_exists" ]; then
  ip_already_bound=`grep -E '#{Regexp.escape(ip)}[[:space:]]`
  if [ -z "$ip_already_bound" ]; then
    echo "#{ip}    api.#{node[:deployment][:domain]}" >> /etc/hosts
  else
    sed -i 's/^{Regexp.escape(ip)}[[:space:]].*$/'$ip_already_bound' api.#{node[:deployment][:domain]}/g' /etc/hosts
  fi
else
  echo "#{ip} was already bound to api.#{node[:deployment][:domain]} in /etc/hosts"  
fi
EOH
    end
  end
  
end

file node[:deployment][:local_run_profile] do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  content <<-EOH
export PATH=#{node[:ruby][:path]}/bin:`#{node[:ruby][:path]}/bin/gem env gempath`/bin:$PATH
export CLOUD_FOUNDRY_CONFIG_PATH=#{node[:deployment][:config_path]}
export VMC_KNIFE_DEFAULT_RECIPE=#{node[:deployment][:vmc_knife_default_recipe]}
  EOH
end

