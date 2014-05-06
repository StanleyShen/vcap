include_attribute "cloudfoundry"
default[:deployment][:name] = "intalio_devbox"
default[:deployment][:user] = ENV["USER"]=='root' ? "ubuntu" : ENV["USER"] # this is in fact computed as `id -nu` by the chef-sololaunch.rb
default[:deployment][:group] = "ubuntu" # this is in fact computed as `id -ng` by the chef-sololaunch.rb

default[:deployment][:home] = File.join(node[:cloudfoundry][:home], ".deployments", deployment[:name])
default[:deployment][:config_path] = File.join(deployment[:home], "config")
default[:deployment][:vcap_components] = File.join(deployment[:config_path], "vcap_components.json")
default[:deployment][:info_file] = File.join(node[:deployment][:config_path], "deployment_info.json")
default[:deployment][:domain] = "intalio.priv"
default[:deployment][:log_path] = File.join(deployment[:home], "log")
default[:deployment][:profile] = File.join(node[:cloudfoundry][:user_home], ".cloudfoundry_deployment_profile")
default[:deployment][:local_run_profile] = File.join(node[:cloudfoundry][:user_home], ".cloudfoundry_deployment_local")
default[:deployment][:vcap_exec] = File.join(deployment[:home], "vcap")
default[:deployment][:vcap_exec_alias] = "vcap"

default[:deployment][:etc_issue_msg] = "Welcome to CloudFoundry #{deployment[:name]}"
default[:deployment][:etc_hosts][:api_dot_domain] = [ "127.0.0.1" ]
default[:deployment][:is_micro] = false
default[:deployment][:tracked_inet] = "eth0" # name of the network interface used

default[:deployment][:setup_cache] = File.join("", "var", "cache", "dev_setup") 
