#
# Cookbook Name: nfs_server
# Recipe: default
# Copyright 2014, Intalio
#
#

service "monit" do
  action :stop

  only_if do
    ::File.exists?('/usr/bin/monit')
  end
end

directory node[:nfs][:server_path] do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode "0755"
  recursive true
  action :create
end

template "#{node[:nfs][:server_path]}/.mounted" do
  source "mounted"
  mode 0644
  action :create
end

package "nfs-kernel-server" do
  action :install
end

bash "Update /etc/exports" do
  code <<-EOH
file=/etc/exports
string="#{node[:nfs][:server_path]} *(rw,sync,root_squash,no_subtree_check)"
if grep -q #{node[:nfs][:server_path]} $file ; then
  echo "already configured"
else
  echo $string | sudo tee -a $file
fi
EOH
end

service "nfs-kernel-server" do
  action :restart
end

# no nfs client on the nfs server vm, just make one symbol link
bash "Make nfs server link" do
  user node[:deployment][:user]
  group node[:deployment][:group]
  cwd "/home/#{node[:deployment][:user]}"

  code <<-EOH
# just to make sure the client path wil be existed
mkdir -p #{node[:nfs][:client_path]}
rm -rf #{node[:nfs][:client_path]}
ln -s #{node[:nfs][:server_path]} #{node[:nfs][:client_path]}
EOH
end

service "monit" do
  action :start

  only_if do
    ::File.exists?('/usr/bin/monit')
  end
end
