#
# Cookbook Name:: cloudfoundry
# Recipe:: default
#
# Copyright 2011, VMWare
#
#
compute_derived_attributes
Chef::Log.debug("#{node[:ruby][:path]} is the current ruby_path")
raise "deployment_name: #{node[:deployment][:name]}; deployment_home: #{node[:deployment][:home]} Not the expected deployment_name ruby_path: #{node[:ruby][:path]}" if node[:ruby][:path] != "/home/ubuntu/cloudfoundry/.deployments/intalio_devbox/deploy/rubies/ruby-1.9.2-p290"

# Gem packages have transient failures, so ignore failures
gem_package "vmc" do
  ignore_failure true
  version node[:cloudfoundry][:vmc][:version] if node[:cloudfoundry][:vmc] && node[:cloudfoundry][:vmc][:version]
  gem_binary "sudo -u #{node[:deployment][:user]} #{File.join(node[:ruby][:path], "bin", "gem")}"
end
