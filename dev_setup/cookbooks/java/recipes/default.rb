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
  
=begin
  # this installs java6 on ubuntu-10.04
  bash "Setup java" do
    code <<-EOH
    add-apt-repository "deb http://archive.canonical.com/ lucid partner"
    apt-get -qqy update
    echo sun-java6-jdk shared/accepted-sun-dlj-v1-1 boolean true | /usr/bin/debconf-set-selections
    echo sun-java6-jre shared/accepted-sun-dlj-v1-1 boolean true | /usr/bin/debconf-set-selections
    EOH
    not_if do
      expected_version_found
    end
  end

  %w[ curl sun-java6-bin sun-java6-jre sun-java6-jdk].each do |pkg|
    package pkg do
      not_if do
        ::File.exists?("/usr/bin/java")
      end
    end
  end

=end

else
  Chef::Log.error("Installation of Sun Java packages not supported on this platform.")
end
