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
  
  # for ubuntu-11.10 and more recent versions, java-6 is more difficult to install.
  %w[ curl openjdk-7-jre-headless openjdk-7-jdk ].each do |pkg|
    package pkg do
      not_if do
        ::File.exists?("/usr/bin/java")
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
      ::File.exists?("/usr/bin/java")
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
