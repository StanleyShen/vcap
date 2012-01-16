#
# Cookbook Name:: monit
# Recipe:: default
#
package "monit"

case node['platform']
  when "ubuntu"
    bash "Upgrade to monit-5.3" do
      user "root"
      code <<-EOH
cd /tmp
if [ ! -d monit-5.3 ]; then
  wget http://mmonit.com/monit/dist/monit-5.3.tar.gz
  tar xvfz monit-5.3.tar.gz
  cd monit-5.3
  ./configure --sysconfdir=/etc/monit/
  make
  sudo make install
  which monit > /dev/null
  [ $? != 0 ] && sudo monit quit
  
  # Configure as daemon with a 4 minutes start delay
  sudo sed -i 's/^#[[:space:]]*set daemon  120/set daemon  120/g' /etc/monit/monitrc
  sudo sed -i 's/^#[[:space:]]*     with start delay 240/     with start delay 240/g' /etc/monit/monitrc

  #Make sure that at least the localhost can connect to monit.
  # Otherwise sudo monit status will return 'errror connecting to monit daemon':
  # http://www.mail-archive.com/monit-general@nongnu.org/msg02887.html
  #Need to find the 3 lines here and uncomment them if that is not the case already:
  # set httpd port 2812 and
  #     use address localhost  # only accept connection from localhost
  #     allow localhost        # allow localhost to connect to the server and
  sudo sed -i 's/^#[[:space:]]*set httpd port 2812 and/set httpd port 2812 and/g' /etc/monit/monitrc
  sudo sed -i 's/^#[[:space:]]*use address localhost/    use address localhost/g' /etc/monit/monitrc
  sudo sed -i 's/^#[[:space:]]*allow localhost/    allow localhost/g' /etc/monit/monitrc
  sudo monit
fi
EOH
    end
    
    #Startup mode
    if node[:monit][:daemon_startup] == 1 || node[:monit][:daemon_startup] == 0
      bash "Setup monit daemon startup mode to #{node[:monit][:daemon_startup]}" do
        user "root"
        code <<-EOH
sed -i 's/^startup=.*$/startup=#{node[:monit][:daemon_startup]}/g' /etc/default/monit
sed -i 's/^#.*set daemon  120/set daemon  120/g' /etc/monit/monitrc
EOH
      end
    end
    if node[:monit][:network_startup] == 1 || node[:monit][:network_startup] == true
      template "/etc/network/if-up.d/monit_dameon" do
        path "/etc/network/if-up.d/monit_dameon"
        source "monit_dameon_if_up.erb"
        mode 0755
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
  nodes_components = node[:monit][:vcap_components].select{
    |name| name =~ /_node$/ || name =~ /^router$/ || name =~ /^cloud_controller$/
  }
  unless nodes_components.empty?
    dea_deps = node[:monit][:depends_on]["dea"].nil? ? nodes_components : ( node[:monit][:depends_on]["dea"] + nodes_components )
    node[:monit][:depends_on]["dea"] = dea_deps
  end
end

template node[:monit][:config_file] do
  path node[:monit][:config_file]
  source "vcap.monitrc.erb"
  owner node[:deployment][:user]
  mode 0644
end

