# author hmalphettes
# handles the installation of a vcap component.
# - adds the component to the json file config/vcap_components.json
# - provider for Chef's service API.
require 'json'

module CloudFoundry
  
  # Add the component name to the list of components
  def add_to_vcap_components(component_name)
    vcap_components_path = node[:deployment][:vcap_components]
    raise "Unexpected path #{node[:deployment][:vcap_components]}" unless "/home/ubuntu/cloudfoundry/.deployments/intalio_devbox/config/vcap_components.json" == node[:deployment][:vcap_components]
    if File.exists?(vcap_components_path)
      begin
        vcap_components = File.open(vcap_components_path, "r") do |infile| JSON.parse infile.read end
        components_list = vcap_components["components"]
        components_list.uniq!
      rescue
        #components_list = Array.new
        puts "Warning: can't parse the #{vcap_components_path} file"
      end
    end
    vcap_components ||= Hash.new
    components_list ||= Array.new
    components_list << component_name unless components_list.include?(component_name)
    vcap_components["components"] = components_list
    FileUtils.rm_r(node[:deployment][:config_path], :force => true)
    FileUtils.mkdir_p File.dirname(vcap_components_path)
    File.open(vcap_components_path, 'w') do |f|
      f.write(JSON.pretty_generate(vcap_components))
    end
    Chef::Log.warn "WROTE #{vcap_components_path}"
    ## change the ownership of the file to the proper user when chef executes as root
    if Process.uid == 0
      user_id = `id -u #{node[:deployment][:user]}`.strip.to_i
      group_id = `id -g #{node[:deployment][:group]}`.strip.to_i
      File.chown user_id, group_id, vcap_components_path
      cur_dirname=File.dirname(vcap_components_path)
      if cur_dirname.start_with?("/home/#{node[:deployment][:user]}")
        while cur_dirname && cur_dirname != "/home/#{node[:deployment][:user]}"
          File.chown user_id, group_id, cur_dirname
          cur_dirname = File.dirname(cur_dirname)
        end
      end
    end
  end

  # support for Chef's service API for the vcap components.
  # The name of the vcap component is derived from the name of the service.
  # If it starts with 'vcap_' it is stripped of it.
  # example:
  #  service "vcap_cloud_controller" do
  #    provider CloudFoundry::VCapChefService
  # ...
  # will support vcap start/stop/restart/status for Chef.
  class VCapChefService < Chef::Provider::Service::Simple
    def initialize(new_resource, run_context)
      @new_resource = new_resource
      @run_context = run_context
      @component_name = @new_resource.service_name
      @component_name.gsub!(/^vcap_?/, '')
      if Process.uid == 0
        @exec_vcap_cmd="sudo -i -u #{@run_context.node[:deployment][:user]} #{@run_context.node[:deployment][:vcap_exec]}"
      else
        @exec_vcap_cmd=@run_context.node[:deployment][:vcap_exec]
      end
      @new_resource.status_command "echo 'about to vcap status';#{@exec_vcap_cmd} status #{@component_name}" unless @new_resource.status_command
      # be nice with start; just fork and go ahead for now.
      @new_resource.restart_command "echo 'about to vcap restart';#{@exec_vcap_cmd} restart #{@component_name}" unless @new_resource.restart_command
      @new_resource.start_command "echo 'about to vcap start';#{@exec_vcap_cmd} start #{@component_name}" unless @new_resource.start_command
      @new_resource.stop_command "echo 'about to vcap stop';#{@exec_vcap_cmd} stop #{@component_name}" unless @new_resource.stop_command
      super
    end
    def reload_service
      if @new_resource.reload_command
        run_command(:command => @new_resource.reload_command)
      else
        Chef::Log.warn "reload vcap's #{@component_name} is not supported. Restarting instead"
        restart_service
      end
    end
  end
end

class Chef::Recipe
  include CloudFoundry
end
