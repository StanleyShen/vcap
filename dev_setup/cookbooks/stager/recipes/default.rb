#
# Cookbook Name:: stager
# Recipe:: default
#
node[:stager][:config_file] = File.join(node[:deployment][:config_path], "stager.yml")
node[:stager][:config_file_redis] = File.join(node[:deployment][:config_path], "stager-redis-server.conf")

template node[:stager][:config_file] do
  path node[:stager][:config_file]
  source "stager.yml.erb"
  owner node[:deployment][:user]
  mode 0644
end
template node[:stager][:config_file_redis] do
  path node[:stager][:config_file_redis]
  source "stager-redis-server.conf.erb"
  owner node[:deployment][:user]
  mode 0644
end

cf_bundle_install(File.expand_path(File.join(node["cloudfoundry"]["path"], "stager")))
