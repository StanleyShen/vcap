#
# Cookbook Name: nfs_client
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

bash "Umount NFS" do
  code <<-EOH
if grep -qs '#{node[:nfs][:client_path]}' /proc/mounts; then
    echo "#{node[:nfs][:client_path]} was mounted."
    umount -l #{node[:nfs][:client_path]}
fi
EOH
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

# always make sure the nfs is mounted
template "/sbin/ensure-nfs-mounted" do
  source "ensure-nfs-mounted"
  mode 0755
  action :create
end

template "/sbin/ensure-nfs-umounted" do
  source "ensure-nfs-umounted"
  mode 0755
  action :create
end

template "/etc/init/nfs-upstart-fixer.conf" do
  source "nfs-upstart-fixer.conf"
  mode 0644
  action :create
end

template "/etc/init/nfs-umount.conf" do
  source "nfs-umount.conf"
  mode 0644
  action :create
end

template "/etc/monit/config.d/nfs.monitrc" do
  source "nfs.monitrc.erb"
  mode 0644
  action :create
end

bash "Mount NFS" do
  code "mount #{node[:nfs][:client_path]}"
end

service "monit" do
  action :start

  only_if do
    ::File.exists?('/usr/bin/monit')
  end
end
