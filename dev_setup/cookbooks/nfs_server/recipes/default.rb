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
