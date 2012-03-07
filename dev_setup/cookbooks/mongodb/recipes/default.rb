#
# Cookbook Name:: mongodb
# Recipe:: default
#
# Copyright 2011, VMware
#
#
compute_derived_attributes

mongod_bin_path=File.join(node[:mongodb_node][:path], 'bin','mongod')
expected_version=node[:mongodb_node][:version]
expected_version_found=`echo $(#{mongod_bin_path} --version 2>&1) | grep v#{expected_version}` if File.exists?(mongod_bin_path)

remote_file File.join("", "tmp", "mongodb-linux-#{node[:kernel][:machine]}-#{node[:mongodb_node][:version]}.tgz") do
  owner node[:deployment][:user]
  source node[:mongodb_node][:source]
  not_if do
    expected_version_found ||
        ::File.exists?(File.join("", "tmp", "mongodb-linux-#{node[:kernel][:machine]}-#{node[:mongodb_node][:version]}.tgz"))
  end
end

bash "Install Mongodb" do
  cwd File.join("", "tmp")
  user node[:deployment][:user] #does not work: CHEF-2288
  environment ({'HOME' => "/home/#{node[:deployment][:user]}",
                'USER' => "#{node[:deployment][:user]}"})
  code <<-EOH
source $HOME/.bashrc
cd /tmp
tar xvzf mongodb-linux-#{node[:kernel][:machine]}-#{node[:mongodb_node][:version]}.tgz
cd mongodb-linux-#{node[:kernel][:machine]}-#{node[:mongodb_node][:version]}
[ -d #{node[:mongodb_node][:path]} ] && rm -rf #{node[:mongodb_node][:path]}/*
mkdir -p #{node[:mongodb_node][:path]}/bin
cp #{File.join("bin", "*")} #{File.join(node[:mongodb_node][:path], "bin")}
# sanity check:
if [ ! -f #{mongod_bin_path} ]; then
  echo "Installation of mongod failed: #{mongod_bin_path} does not exist"
  exit 1
fi
echo $(#{mongod_bin_path} --version 2>&1) | grep v#{expected_version}
EOH
  not_if do
    expected_version_found
  end
end

directory File.join(node[:mongodb_node][:path], "bin") do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode "0755"
  recursive true
  action :create
end
