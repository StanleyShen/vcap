module CloudFoundryAttributes
  # this is a workaround for the fact that we must not compute
  # default attributes values derived from other attributes.
  # directly in the attributes.rb files.
  # see http://help.opscode.com/discussions/questions/1161-expanding-node-attributes
  def compute_derived_attributes
    return unless node[:deployment][:compute_derived_attributes] = true
    node[:deployment][:compute_derived_attributes] = true
    Chef::Log.info("Compute the 'effective' deployment attributes from the ruby recipe library")
    
    node[:cloudfoundry][:user_home] = ENV["HOME"]=='/root' ? "/home/#{node[:deployment][:user]}" : ENV["HOME"] unless node[:cloudfoundry][:user_home] # messy
    node[:cloudfoundry][:home] = File.join(node[:cloudfoundry][:user_home], "cloudfoundry") unless node[:cloudfoundry][:home]
    node[:cloudfoundry][:path] = File.join(node[:cloudfoundry][:home], "vcap") unless node[:cloudfoundry][:path]
    node[:deployment][:home] = File.join(node[:cloudfoundry][:home], ".deployments", node[:deployment][:name]) unless node[:deployment][:home]
    node[:deployment][:config_path] = File.join(node[:deployment][:home], "config") unless node[:deployment][:config_path]
    node[:deployment][:info_file] = File.join(node[:deployment][:config_path], "deployment_info.json") unless node[:deployment][:info_file]
    node[:deployment][:log_path] = File.join(node[:deployment][:home], "log") unless node[:deployment][:log_path]
    node[:deployment][:profile] = File.expand_path(File.join(node[:cloudfoundry][:user_home], ".cloudfoundry_deployment_profile")) unless node[:deployment][:profile]
    Chef::Log.warn(" DEBUYG: #{node[:deployment][:local_run_profile]}")
    unless node[:deployment][:local_run_profile]
      node[:deployment][:local_run_profile] = File.expand_path(File.join(node[:cloudfoundry][:user_home], ".cloudfoundry_deployment_local"))
    else
      node[:deployment][:local_run_profile] = File.expand_path(node[:deployment][:local_run_profile])
    end
    Chef::Log.warn(" DEBUYG afecter compute: #{node[:deployment][:local_run_profile]}")
    node[:deployment][:vcap_exec] = File.join(node[:deployment][:home], "vcap") unless node[:deployment][:vcap_exec]

    node[:ruby][:path]    = File.join(node[:deployment][:home], "deploy", "rubies", "ruby-#{node[:ruby][:version]}") unless node[:ruby][:path]
    node[:ruby18][:path]    = File.join(node[:deployment][:home], "deploy", "rubies", "ruby-#{node[:ruby18][:version]}") unless node[:ruby18][:path]

    ## other recipe's derived attributes:
    if node[:redis]
      node[:redis][:path] = File.join(node[:deployment][:home], "deploy", "redis") unless node[:redis][:path]
    end
    if node[:erlang]
      node[:erlang][:path] = File.join(node[:deployment][:home], "deploy", "erlang") unless node[:erlang][:path]
    else
      raise "Testing / Debugging: expecting the erlang attributes to be present"
    end
    
    
  end
end

class Chef::Recipe
  include CloudFoundryAttributes
end

