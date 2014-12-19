#
# Cookbook Name: nfs
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

bash "stop vcap" do
  user node[:deployment][:user] 
  environment ({'HOME' => "/home/#{node[:deployment][:user]}",
                'USER' => "#{node[:deployment][:user]}"})
  cwd "/home/#{node[:deployment][:user]}"
  code "#{node[:deployment][:vcap_exec]} stop"

  only_if do
    ::File.exists?("#{node[:deployment][:vcap_exec]}")
  end
end

bash "Umount NFS" do
  code <<-EOH
if grep -qs '#{node[:nfs][:client_path]}' /proc/mounts; then
    echo "#{node[:nfs][:client_path]} was mounted."
    umount -l #{node[:nfs][:client_path]}
fi
EOH
end

directory "/var/vcap/services/" do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode "0755"
  recursive true
  action :create
end

directory node[:nfs][:server_path] do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode "0755"
  recursive true
  action :create
end

directory node[:nfs][:client_path] do
  owner node[:deployment][:user]
  group node[:deployment][:group]
  mode "0755"
  recursive true
  action :create
end

package "nfs-kernel-server" do
  action :install
end

package "nfs-common" do
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

service "nfs-kernel-server" do
  action :restart
end

bash "Mount NFS" do
  code "mount #{node[:nfs][:client_path]}"
end

# use symbol link from shared fs to origin cf locations
bash "shared files for nfs" do
  user node[:deployment][:user]
  code <<-EOH
  sleep 5
  mkdir -p /var/vcap/services/nfs/cloudfoundry
  cp -r /home/ubuntu/cloudfoundry/.deployments/intalio_devbox/config #{node[:nfs][:server_path]}/cloudfoundry

  rm -rf /home/ubuntu/cloudfoundry/.deployments/intalio_devbox/config
  ln -s #{node[:nfs][:client_path]}/cloudfoundry/config /home/ubuntu/cloudfoundry/.deployments/intalio_devbox/config
  
  rm /home/ubuntu/cloudfoundry/config
  ln -s #{node[:nfs][:client_path]}/cloudfoundry/config /home/ubuntu/cloudfoundry/config
  EOH

  not_if "test -L /home/ubuntu/cloudfoundry/.deployments/intalio_devbox/config"
end

bash "stop vcap" do
  user node[:deployment][:user] 
  environment ({'HOME' => "/home/#{node[:deployment][:user]}",
                'USER' => "#{node[:deployment][:user]}"})
  cwd "/home/#{node[:deployment][:user]}"
  code "#{node[:deployment][:vcap_exec]} restart"

  only_if do
    ::File.exists?("#{node[:deployment][:vcap_exec]}")
  end
end

service "monit" do
  action :start

  only_if do
    ::File.exists?('/usr/bin/monit')
  end
end
