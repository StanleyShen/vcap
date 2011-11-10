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
 File.join(node[:deployment][:config_path], "staging")].each do |dir|
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

template "etc_issue_with_ip" do
  path File.join("", "etc", "network", "if-up.d", "update-etc-issue")
  source "etc_issue_with_ip.erb"
  owner node[:deployment][:user]
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
  ruby_block "user bashrc update" do
    block do
      Dir.chdir cloudfoundry_home do
        # few symbolic links (todo: too many assumptions on the layout of the deployment)
        `[ -h _vcap ] && rm _vcap`
        `ln -s #{node[:deployment][:vcap_exe]} _vcap`
        `[ -h log ] && rm log`
        `ln -s #{node[:deployment][:log_path]} log`
        `[ -h config ] && rm config`
        `ln -s #{node[:deployment][:config_path]} config`
        `[ -h deployed_apps ] && rm deployed_apps`
        `mkdir -p /var/vcap.local/dea/apps`
        `ln -s /var/vcap.local/dea/apps deployed_apps`
      end
      
      # add the profile to the user's  home.
      `grep #{node[:deployment][:local_run_profile]} #{ENV["HOME"]}/.bashrc; [ $? != 0 ] && echo "source #{node[:deployment][:local_run_profile]}" >> #{ENV["HOME"]}/.bashrc`
      `grep alias\ #{default[:deployment][:vcap_exec_alias]}=\' #{ENV["HOME"]}/.bashrc; [ $? != 0 ] && echo "alias vcap='#{node[:deployment][:vcap_exec]}'" >> #{ENV["HOME"]}/.bashrc`
   end
  end
end

file node[:deployment][:local_run_profile] do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  content <<-EOH
    export PATH=#{node[:ruby][:path]}/bin:`#{node[:ruby][:path]}/bin/gem env gempath`/bin:$PATH
    export CLOUD_FOUNDRY_CONFIG_PATH=#{node[:deployment][:config_path]}
  EOH
end

