#
# Cookbook Name:: deployment
# Recipe:: default
#
# Copyright 2011, VMware
#
compute_derived_attributes
case node['platform']
when "ubuntu"
  package "git-core"
  package "secure-delete"
else
  Chef::Log.error("Installation of cloudfoundr not supported on this platform.")
end

# when we package a VM for download we delete the .git folders as they use a lot of space 400M+
# let's detect that and redo a checkout when that is the case:
if File.exist?("#{node[:cloudfoundry][:path]}") && !File.exist?("#{node[:cloudfoundry][:path]}/.git")
  Chef::Log.warn("Could not find the .git folders, preparing a brand new checkout.")
	FileUtils.rm_rf("node[:cloudfoundry][:path]}")
end
# main repo
_enable_submodules = false
_enable_submodules = true if node[:cloudfoundry][:git][:vcap][:enable_submodules] && node[:cloudfoundry][:git][:vcap][:enable_submodules].to_s == "true"
git node[:cloudfoundry][:path] do
  repository node[:cloudfoundry][:git][:vcap][:repo]
  revision node[:cloudfoundry][:git][:vcap][:branch]
  depth 1
  enable_submodules _enable_submodules
  action :sync
  user node[:deployment][:user]
  group node[:deployment][:group]
end
unless _enable_submodules
  git "#{node[:cloudfoundry][:path]}/services" do
    repository node[:cloudfoundry][:git][:vcap_services][:repo]
    revision node[:cloudfoundry][:git][:vcap_services][:branch]
    depth 1
    action :sync
    user node[:deployment][:user]
    group node[:deployment][:group]
  end
  git "#{node[:cloudfoundry][:path]}/java" do
    repository node[:cloudfoundry][:git][:vcap_java][:repo]
    revision node[:cloudfoundry][:git][:vcap_java][:branch]
    depth 1
    action :sync
    user node[:deployment][:user]
    group node[:deployment][:group]
  end
end
bash "Chown vcap sources to the user in case git was executed from root" do
  #user node[:deployment][:user] #does not work: CHEF-2288
  #group node[:deployment][:group] #does not work: CHEF-2288
  #environment ({'HOME' => "/home/#{node[:deployment][:user]}",
  #              'USER' => "#{node[:deployment][:user]}"})
  code <<-EOH
    chown -R #{node[:deployment][:user]}:#{node[:deployment][:group]} #{node[:cloudfoundry][:path]}
EOH
  not_if do
    Process.uid != 0
  end
end

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
 File.join("", "var", "vcap.local", "staging"),
 File.join("", "var", "vcap.local", "dea"),
 File.join("", "var", "vcap.local", "dea", "apps")].each do |dir|
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
  group node[:deployment][:group]
  mode 0644
  variables({
    :name => node[:deployment][:name],
    :ruby_bin_dir => File.join(node[:ruby][:path], "bin"),
    :cloudfoundry_path => node[:cloudfoundry][:path],
    :deployment_log_path => node[:deployment][:log_path]
  })
end

# generates a file that contains the openstack_public_ip or empty if not running on openstack.
template "openstack_public_ip" do
  path File.join("", "etc", "init", "openstack_public_ip.conf")
  source "openstack_public_ip.conf.erb"
  mode 0644
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
  owner node[:deployment][:group]
  mode 0755
end

template "etc_issue.conf" do
  path File.join("", "etc", "init", "etc_issue.conf")
  source "etc_issue.conf.erb"
  owner "root"
  mode 0644
end

template "vcap_shutdown.conf" do
  path File.join("", "etc", "init", "vcap_shutdown.conf")
  source "vcap_shutdown.conf.erb"
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
  group node[:deployment][:group]
  mode 0755
end

case node['platform']
when "ubuntu"
  bash "invoke_hostname_unique" do
		code <<-EOH
/etc/network/if-up.d/hostname_uniq
EOH
  end 

	bash "Create some symlinks and customize .bashrc" do
    user node[:deployment][:user] #does not work: CHEF-2288
    group node[:deployment][:group] #does not work: CHEF-2288
    environment ({'HOME' => "/home/#{node[:deployment][:user]}",
                  'USER' => "#{node[:deployment][:user]}"})
      code <<-EOH
cd #{node[:cloudfoundry][:home]}
# few symbolic links (todo: too many assumptions on the layout of the deployment)
[ -h log ] && rm log
ln -s #{node[:deployment][:log_path]} log
[ -h config ] && rm config
ln -s #{node[:deployment][:config_path]} config
[ -h deployed_apps ] && rm deployed_apps
if [ ! -d /var/vcap.local/dea/apps ]; then
  mkdir -p /var/vcap.local/dea/apps
  chown #{node[:deployment][:user]}:#{node[:deployment][:group]} /var/vcap.local/dea/apps
fi
ln -s /var/vcap.local/dea/apps deployed_apps

cd /home/#{node[:deployment][:user]}
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
cmd="grep -E '#{Regexp.escape(ip)}[[:space:]].*[[:space:]]api\.#{Regexp.escape(node[:deployment][:domain])}[^[:alnum:]]?' /etc/hosts"
binding_exists=`grep -E '#{Regexp.escape(ip)}[[:space:]].*[[:space:]]api\.#{Regexp.escape(node[:deployment][:domain])}[^[:alnum:]]?' /etc/hosts`
echo "A $? $cmd returned $binding_exists"
if [ -z "$binding_exists" ]; then
  #cmd="grep -E '#{Regexp.escape(ip)}[[:space:]].*' /etc/hosts | head -1"
  cmd="grep #{ip} /etc/hosts"
  ip_already_bound=`grep #{ip} /etc/hosts`
  echo "B $? $cmd returned $ip_already_bound"
  if [ -z "$ip_already_bound" ]; then
    echo "#{ip}    api.#{node[:deployment][:domain]}" >> /etc/hosts
  else
    cmd2="echo '$ip_already_bound' | grep api.#{node[:deployment][:domain]}"
    nothing_to_do=`echo "$ip_already_bound" | grep api.#{node[:deployment][:domain]}`
    echo "C $? $cmd2 returned $nothing_to_do"
    if [ -z "$nothing_to_do" ]; then
      sed -i "s/^#{Regexp.escape(ip)}[[:space:]].*$/$ip_already_bound api.#{node[:deployment][:domain]}/g" /etc/hosts
    fi
  fi
else
  echo "#{ip} was already bound to api.#{node[:deployment][:domain]} in /etc/hosts"  
fi
EOH
Chef::Log.error(code)
    end
  end
  
end

file node[:deployment][:local_run_profile] do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  content <<-EOH
if [ -n "$GEM_HOME" -a -n $(echo "$GEM_HOME" | grep "/root")"" ]; then
  gemdir=`sudo -i -u #{node[:deployment][:user]} #{node[:ruby][:path]}/bin/gem env gemdir`
  echo "WARN: WRONG ENV. GEM_HOME is $GEM_HOME trying a sudo -i -u gem env gemdir -> $gemdir to fix things"
  export GEM_HOME=$gemdir
  export GEM_PATH=$gemdir
fi
[ -z $(echo $PATH | grep #{node[:ruby][:path]}/bin ) ] && export PATH=#{node[:ruby][:path]}/bin:`#{node[:ruby][:path]}/bin/gem env gemhome`/bin:$PATH
export CLOUD_FOUNDRY_CONFIG_PATH=#{node[:deployment][:config_path]}
export VMC_KNIFE_DEFAULT_RECIPE=#{node[:deployment][:vmc_knife_default_recipe]}
EOH
end

# rvm precautions:
#.bash_login (generated by the rvm install) being present will prevent .bashrc from being executed (!)
bash "Disable rvm for the ubuntu user" do
  code <<-EOH
if [ -f /home/#{node[:deployment][:user]}/.bash_login ]; then
  mv /home/#{node[:deployment][:user]}/.bash_login /home/#{node[:deployment][:user]}/.bash_login_disabled
fi
#if [ -f /etc/profile.d/rvm.sh ]; then
#  mv /home/#{node[:deployment][:user]}/.bash_login /home/#{node[:deployment][:user]}/.bash_login_disabled
#fi
EOH
  only_if do
    ::File.exists?("/home/#{node[:deployment][:user]}/.bash_login")
  end
end
