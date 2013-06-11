#
# Cookbook Name:: erlang
# Recipe:: default
#
# Copyright 2011, VMware
#
#
%w[ build-essential libncurses5-dev openssl libssl-dev ].each do |pkg|
  package pkg
end

erl_bin_path=File.join(node[:erlang][:path], "bin", "erl")
erl_release_folder_path=File.join(node[:erlang][:path], "lib/erlang/releases/R14B02")

remote_file File.join("", "tmp", "otp_src_#{node[:erlang][:version]}.tar.gz") do
  owner node[:deployment][:user]
  source node[:erlang][:source]
  not_if do
    ::File.exists?(File.join("", "tmp", "otp_src_#{node[:erlang][:version]}.tar.gz")) ||
          (::File.exists?(erl_bin_path) && ::File.exists?(erl_release_folder_path))
  end
end

directory node[:erlang][:path] do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode "0755"
  recursive true
  action :create
end

bash "Install Erlang" do
  cwd File.join("", "tmp")
  user node[:deployment][:user] #does not work: CHEF-2288
  environment ({'HOME' => "/home/#{node[:deployment][:user]}",
                'USER' => "#{node[:deployment][:user]}"})
  code <<-EOH
  cd /tmp
  tar xvzf otp_src_#{node[:erlang][:version]}.tar.gz
  cd otp_src_#{node[:erlang][:version]}
  #{File.join(".", "configure")} --prefix=#{node[:erlang][:path]}
  make
  make install
EOH
  not_if do
    ::File.exists?(erl_bin_path) && ::File.exists?(erl_release_folder_path)
  end
end
