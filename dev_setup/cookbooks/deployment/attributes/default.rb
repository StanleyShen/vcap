include_attribute "cloudfoundry"
default[:deployment][:name] = "devbox"
default[:deployment][:user] = ENV["USER"]
default[:deployment][:group] = "vcap"
default[:deployment][:home] = File.join(node[:cloudfoundry][:home], ".deployments", deployment[:name])
default[:deployment][:config_path] = File.join(deployment[:home], "config")
default[:deployment][:info_file] = File.join(deployment[:config_path], "deployment_info.json")
default[:deployment][:domain] = "vcap.me"
default[:deployment][:log_path] = File.join(deployment[:home], "log")
default[:deployment][:profile] = File.expand_path(File.join(ENV["HOME"], ".cloudfoundry_deployment_profile"))
default[:deployment][:local_run_profile] = File.expand_path(File.join(ENV["HOME"], ".cloudfoundry_deployment_local"))
default[:deployment][:vcap_exec] = File.join(default[:deployment][:home], "vcap")
default[:deployment][:vcap_exec_alias] = "vcap"

default[:deployment][:etc_issue_msg] = "Welcome to CloudFoundry #{default[:deployment][:name]}"
default[:deployment][:etc_hosts][:api_dot_domain] = [ "127.0.0.1" ]
default[:deployment][:is_micro] = false
default[:deployment][:tracked_inet] = "eth0" # name of the network interface used
#Force the local IP to something else.
#default[:cloudfoundry][:local_ip] = 127.0.0.1