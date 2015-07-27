#
# Cookbook Name: nfs_client
# Recipe: default
# Copyright 2014, Intalio
#
#

directory node[:nfs][:client_path] do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode "0755"
  recursive true
  action :create
end


package "nfs-common" do
  action :install
end

# place the partition in fstab
bash "Update /etc/fstab" do
  code <<-EOH
file=/etc/fstab
string="db.intalio.priv:#{node[:nfs][:server_path]} #{node[:nfs][:client_path]} nfs _netdev,noauto,bg,noatime,intr 0 0"
if grep -q #{node[:nfs][:server_path]} $file ; then
  echo "already configured"
else
  echo $string | sudo tee -a $file
fi
EOH
end

bash "Mount NFS" do
  code "mount #{node[:nfs][:client_path]}"
end
