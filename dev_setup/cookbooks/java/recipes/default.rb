#
# Cookbook Name:: java
# Recipe:: default
#
# Copyright 2011, VMware
#
#
package "python-software-properties"

case node['platform']
when "ubuntu"
  # sun-java6-bin sun-java6-jre sun-java6-jdk
  %w[ curl openjdk-7-jre-headless openjdk-7-jdk ].each do |pkg|
    package pkg do
      not_if do
        ::File.exists?("/usr/bin/java")
      end
    end
  end

else
  Chef::Log.error("Installation of Sun Java packages not supported on this platform.")
end
