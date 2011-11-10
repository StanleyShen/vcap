#
# Cookbook Name:: monit
# Recipe:: default
#
package "monit"

case node['platform']
  when "ubuntu"
    #Startup mode
    if node[:monit][:daemon_startup] == 1 || node[:monit][:daemon_startup] == 0
      bash "Setup monit daemon startup mode to #{node[:monit][:daemon_startup]}" do
        user "root"
        code <<-EOH
sed -i 's/^startup=.*$/startup=#{node[:monit][:daemon_startup]}/g' /etc/default/monit
EOH
      end
    end
    
    #Include directive.
    bash "Setup monit daemon startup mode to #{node[:monit][:daemon_startup]}" do
      user "root"
      code <<-EOH
    found=`egrep ^include\ \/etc\/monit\/conf\.d\/\* /etc/monit/monitrc`
    [ -z "$found" ] && echo "include /etc/monit/conf.d/*" >> /etc/monit/monitrc
    echo "include #{node[:monit][:config_file]}" > /etc/monit/conf.d/include_vcap.monitrc
EOH
    end
    
    #postgres?
    if !node[:monit][:others].nil? && node[:monit][:others].include?("postgresql")
      template "/etc/monit/conf.d/postgresql.monitrc" do
        path "/etc/monit/conf.d/postgresql.monitrc"
        source "postgresql.monitrc.erb"
        mode 0644
      end
    end
    
end

node[:monit][:vcap_components] ||= Hash.new
node[:monit][:vcap_daemons] ||= Hash.new
node[:monit][:others] ||= Hash.new
node[:monit][:depends_on] ||= Hash.new

#every vcap component requires nats_server if we are running it on this machine:
if node[:monit][:vcap_daemons].include?("nats_server")
  node[:monit][:vcap_components].each do |name|
    node[:monit][:depends_on][name] = [ "nats_server" ]
  end
end

#the dea must not be started before the service nodes are ready
#true at least in a micro-setup:
if node[:monit][:vcap_components].include?("dea")
  nodes_components = node[:monit][:vcap_components].select{|name| name =~ /_node$/}
  unless nodes_components.empty?
    dea_deps = node[:monit][:depends_on]["dea"].nil? ? [ ] : [ node[:monit][:depends_on]["dea"] ]
    dea_deps << nodes_components
    node[:monit][:depends_on]["dea"] = dea_deps
  end
end

template node[:monit][:config_file] do
  path node[:monit][:config_file]
  source "vcap.monitrc.erb"
  owner node[:deployment][:user]
  mode 0644
end

