#
# Cookbook Name:: cloudfoundry
# Recipe:: default
#
# Copyright 2011, VMWare
#
#
Chef::Log.debug("#{node[:ruby][:path]} is the current ruby_path")

# Gem packages have transient failures, so ignore failures
gem_package "vmc" do
  ignore_failure true
  version node[:cloudfoundry][:vmc][:version] if node[:cloudfoundry][:vmc] && node[:cloudfoundry][:vmc][:version]
  gem_binary "sudo -i -u #{node[:deployment][:user]} #{File.join(node[:ruby][:path], "bin", "gem")}"
end
