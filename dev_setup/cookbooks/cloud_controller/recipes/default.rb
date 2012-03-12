#
# Cookbook Name:: cloud_controller
# Recipe:: default
#
# Copyright 2011, VMware
#
#
compute_derived_attributes
node[:cloud_controller][:cloud_controller_yml_path]=File.join(node[:deployment][:config_path], node[:cloud_controller][:config_file])

node[:cloud_controller][:bundle_exec_cmd]=CloudFoundry::cf_invoke_bundler_cmd(node,
                             File.join(node[:cloudfoundry][:path], "cloud_controller"),
                             "exec rake db:migrate CLOUD_CONTROLLER_CONFIG=#{node[:cloud_controller][:cloud_controller_yml_path]}")

## #max size of the unzipped app (overrides the 512M and makes it 768M): 768 * 1024 * 1024
## max_droplet_size: 805306368
max_droplet_size=node[:cloud_controller][:max_droplet_size]
if max_droplet_size
  if /M$/ =~ max_droplet_size
    max_droplet_size=max_droplet_size[0..-1].to_i * 1024 * 1024
  elsif /G$/ =~ max_droplet_size
    max_droplet_size=max_droplet_size[0..-1].to_i * 1024 * 1024 * 1024
  else
    max_droplet_size=max_droplet_size.to_i
  end
end

Chef::Log.info("bundle_exec_cmd #{node[:cloud_controller][:bundle_exec_cmd]}")

bash "rake_migrate_ccdb" do
  user node[:deployment][:user] #does not work: CHEF-2288
  environment ({'HOME' => "/home/#{node[:deployment][:user]}",
                'USER' => "#{node[:deployment][:user]}"})
  cwd = File.join(node[:cloudfoundry][:path], "cloud_controller")
  code <<-EOH
#source $HOME/.bashrc
#source $HOME/.cloudfoundry_deployment_profile
#cd #{File.join(node[:cloudfoundry][:path], "cloud_controller")}
#{node[:cloud_controller][:bundle_exec_cmd]}
EOH
  Chef::Log.warn("rake_migrate_ccdb: #{code}")
  #notifies :restart, "service[vcap_cloud_controller]"
  action :nothing
end

cf_bundle_install(File.join(node["cloudfoundry"]["path"], "cloud_controller"))
cf_gem_build_install(File.join(node["cloudfoundry"]["path"], "staging"))
add_to_vcap_components("cloud_controller")

template node[:cloud_controller][:config_file] do
  path node[:cloud_controller][:cloud_controller_yml_path]
  source "cloud_controller.yml.erb"
  owner node[:deployment][:user]
  mode 0644
  builtin_services = []
  case node[:cloud_controller][:builtin_services]
  when Array
    builtin_services = node[:cloud_controller][:builtin_services]
  when Hash
    builtin_services = node[:cloud_controller][:builtin_services].keys
  when String
    builtin_services = node[:cloud_controller][:builtin_services].split(" ")
  else
    Chef::Log.error("Input error: Please specify cloud_controller builtin_services as a list, \
                   it has an unsupported type #{node[:cloud_controller][:builtin_services].class}")
    exit 1
  end
  variables({
    :builtin_services => builtin_services,
    :max_droplet_size => max_droplet_size,
    :ruby18_enabled => node[:dea] && node[:dea][:runtimes].include?('ruby18') ? true : false
  })
  # see http://wiki.opscode.com/display/chef/Resources#Resources-Execute
  notifies :run, resources(:bash => "rake_migrate_ccdb")
end

staging_dir = File.join(node[:deployment][:config_path], "staging")
node[:cloud_controller][:staging].each_pair do |framework, config|
  template config do
    path File.join(staging_dir, config)
    source "#{config}.erb"
    owner node[:deployment][:user]
    mode 0644
    variables({
      :ruby18_enabled => node[:dea] && node[:dea][:runtimes].include?('ruby18') ? true : false
    })
  end
end

service "vcap_cloud_controller" do
  provider CloudFoundry::VCapChefService
  supports :status => true, :restart => true, :start => true, :stop => true
  action [ :start ]
end

