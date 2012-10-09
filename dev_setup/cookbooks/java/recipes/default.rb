#
# Cookbook Name:: java
# Recipe:: default
#
# Copyright 2011, VMware
#
#
package "python-software-properties"

java_bin_path= "/usr/bin/java"
java_version_str=`echo $(#{java_bin_path} -version 2>&1)`.strip if File.exists?(java_bin_path)
expected_version=node[:java][:expected_version] if node[:java]
expected_version||="1.7.0"
expected_version_found=`echo $(#{java_bin_path} -version 2>&1) | grep #{expected_version}` if File.exists?(java_bin_path)

case node['platform']
when "ubuntu"

  # for ubuntu-11.10 and more recent versions, java-6 is more difficult to install.
  node[:java][:apt].split(" ").each do |pkg|
    package pkg do
      not_if do
        expected_version_found
      end
    end
  end

  ruby_block "reload_client_config" do
    block do
      version_found=`echo $(#{java_bin_path} -version 2>&1)`
      expected_version_found=`echo $(#{java_bin_path} -version 2>&1) | grep #{expected_version}`
      raise "java -v returned #{version_found} instead of the expected version #{expected_version}" unless expected_version_found
    end
    #action :create
  end
else
  Chef::Log.error("Installation of Sun Java packages not supported on this platform.")
end
