#
# Cookbook Name:: cloud_controller
# Recipe:: default
#
# Copyright 2011, VMware
#
#
cloud_controller_yml_path=File.join(node[:deployment][:config_path], node[:cloud_controller][:config_file])

bash "rake_migrate_ccdb" do
  user node[:deployment][:user] #does not work: CHEF-2288
  environment ({'HOME' => "/home/#{node[:deployment][:user]}",
                'USER' => "#{node[:deployment][:user]}"})
  cwd = File.join(node[:cloudfoundry][:path], "cloud_controller")
  code <<-EOH
source $HOME/.bashrc
cd #{File.join(node[:cloudfoundry][:path], "cloud_controller")}
echo "About to execute bundle exec rake db:migrate CLOUD_CONTROLLER_CONFIG=#{cloud_controller_yml_path}"
#{node[:ruby][:path]}/bin/bundle exec rake db:migrate CLOUD_CONTROLLER_CONFIG=#{cloud_controller_yml_path}
EOH
  notifies :restart, "service[vcap_cloud_controller]"
  action :nothing
end


template node[:cloud_controller][:config_file] do
  path cloud_controller_yml_path
  source "cloud_controller.yml.erb"
  owner node[:deployment][:user]
  mode 0644
  # see http://wiki.opscode.com/display/chef/Resources#Resources-Execute
  notifies :run, resources(:bash => "rake_migrate_ccdb")
  
  builtin_services = []
  case node[:cloud_controller][:builtin_services]
  when Array
    builtin_services = node[:cloud_controller][:builtin_services]
  when Hash
    builtin_services = node[:cloud_controller][:builtin_services].keys
  when String
    builtin_services = node[:cloud_controller][:builtin_services].split(" ")
  else
    Chef::Log.info("Input error: Please specify cloud_controller builtin_services as a list, \
                   it has an unsupported type #{node[:cloud_controller][:builtin_services].class}")
    exit 1
  end
  # make sure that indeed we are installing the node service for each one of those.
  builtin_services.collect do |service_name|
    unless node[(service_name + "_node").to_sym]
      Chef::Log.warn("The service #{service_name} is included in the builtin services of the cloud_controller \
                     but the #{service_name}_node is not configured in this recipe_run; can't use it in the cloud_controller.yml (probably not a big deal)")
    end
  end
  variables({
    :builtin_services => builtin_services
  })
end
cf_bundle_install(File.expand_path(File.join(node["cloudfoundry"]["path"], "cloud_controller")))

staging_dir = File.join(node[:deployment][:config_path], "staging")
node[:cloud_controller][:staging].each_pair do |framework, config|
  template config do
    path File.join(staging_dir, config)
    source "#{config}.erb"
    owner node[:deployment][:user]
    mode 0644
  end
end

service "vcap_cloud_controller" do
  provider CloudFoundry::VCapChefService
  supports :status => true, :restart => true, :start => true, :stop => true
  action [ :start ]
end

