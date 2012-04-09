module CloudFoundryAttributes
  
  @@already=false
  # this is a workaround for the fact that we must not compute
  # default attributes values derived from other attributes.
  # directly in the attributes.rb files.
  # see http://help.opscode.com/discussions/questions/1161-expanding-node-attributes
  def compute_derived_attributes
    return if @@already
    @@already = true
    Chef::Log.info("Compute the derived attributes from the ruby recipe library")
    
    node[:cloudfoundry][:user_home] = ENV["HOME"]=='/root' ? "/home/#{node[:deployment][:user]}" : ENV["HOME"] unless node[:cloudfoundry][:user_home] # messy
    node[:cloudfoundry][:home] = File.join(node[:cloudfoundry][:user_home], "cloudfoundry") unless node[:cloudfoundry][:home]
    node[:cloudfoundry][:path] = File.join(node[:cloudfoundry][:home], "vcap") unless node[:cloudfoundry][:path]
    node[:deployment][:home] = File.join(node[:cloudfoundry][:home], ".deployments", node[:deployment][:name]) unless node[:deployment][:home]
    node[:deployment][:config_path] = File.join(node[:deployment][:home], "config") unless node[:deployment][:config_path]
    node[:deployment][:vcap_components] = File.join(node[:deployment][:config_path], "vcap_components.json") unless node[:deployment][:vcap_components]
    node[:deployment][:info_file] = File.join(node[:deployment][:config_path], "deployment_info.json") unless node[:deployment][:info_file]
    node[:deployment][:log_path] = File.join(node[:deployment][:home], "log") unless node[:deployment][:log_path]
    node[:deployment][:profile] = File.expand_path(File.join(node[:cloudfoundry][:user_home], ".cloudfoundry_deployment_profile")) unless node[:deployment][:profile]
    unless node[:deployment][:local_run_profile]
      node[:deployment][:local_run_profile] = File.expand_path(File.join(node[:cloudfoundry][:user_home], ".cloudfoundry_deployment_local"))
    else
      node[:deployment][:local_run_profile] = File.expand_path(node[:deployment][:local_run_profile])
    end
    node[:deployment][:vcap_exec] = File.join(node[:deployment][:home], "vcap") unless node[:deployment][:vcap_exec]

    node[:ruby][:path]    = File.join(node[:deployment][:home], "deploy", "rubies", "ruby-#{node[:ruby][:version]}") unless node[:ruby][:path]
    node[:ruby18][:path]    = File.join(node[:deployment][:home], "deploy", "rubies", "ruby-#{node[:ruby18][:version]}") unless node[:ruby18][:path]

    node[:ruby][:version_regexp] = Regexp.quote(node[:ruby][:version]).gsub(/-/, '.?')
    node[:ruby][:version_regexp_yaml] = node[:ruby][:version_regexp].gsub( Regexp.new("\\\\"), '\\\\\\' )
    if node[:ruby18]
      node[:ruby18][:version_regexp] = Regexp.quote(node[:ruby18][:version])
      node[:ruby18][:version_regexp_yaml] = node[:ruby18][:version_regexp].gsub( Regexp.new("\\\\"), '\\\\\\' )
    end
    
    ## other recipe's derived attributes:
    if node[:redis]
      node[:redis][:path] = File.join(node[:deployment][:home], "deploy", "redis") unless node[:redis][:path]
    end
    if node[:erlang] || node[:cloud_controller] # used by the cloud_controller templates
      node[:erlang] = {} unless node[:erlang]
      node[:erlang][:path] = File.join(node[:deployment][:home], "deploy", "erlang") unless node[:erlang][:path]
    end
    if node[:nodejs] || node[:cloud_controller] # used by the cloud_controller templates
      node[:nodejs] = {} unless node[:nodejs]
      node[:nodejs][:source] = "http://nodejs.org/dist/node-v#{node[:nodejs][:version]}.tar.gz" unless node[:nodejs][:source]
      node[:nodejs][:path] = File.join(node[:deployment][:home], "deploy", "nodejs") #unless node[:nodejs][:path]
    end
    if node[:mongodb_node]
      node[:mongodb_node][:path] = File.join(node[:deployment][:home], "deploy", "mongodb") unless node[:mongodb_node][:path]
      node[:mongodb_node][:source] = "http://fastdl.mongodb.org/linux/mongodb-linux-#{node[:kernel][:machine]}-#{node[:mongodb_node][:version]}.tgz"# unless node[:mongodb_node][:source]
    end
    node[:nats_server][:host] ||= cf_local_ip if node[:nats_server]
    node[:ccdb][:host] ||= cf_local_ip node[:ccdb] if node[:ccdb]
    node[:postgresql_node][:host] ||= cf_local_ip if node[:postgresql_node]
    if node[:dea]
      # make the dea runtimes' completly overridable. if we don't do this we get a deep merge instead.
      # the trick to prevent the deep merge is deprecated
      node[:dea][:runtimes] = node[:dea][:runtimes_default] unless node[:dea][:runtimes]
    end
    node[:cloud_controller] = {} unless node[:cloud_controller]
    node[:cloud_controller][:service_api_uri] = "http://api.#{node[:deployment][:domain]}" unless node[:cloud_controller][:service_api_uri]
  end
end

class Chef::Recipe
  include CloudFoundryAttributes
end

