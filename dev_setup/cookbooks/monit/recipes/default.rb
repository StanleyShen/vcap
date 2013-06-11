#
# Cookbook Name:: monit
# Recipe:: default
#

package "monit"

# this will run /etc/init.d/monit start
service "monit" do
  # does not fail if the service was not running
  restart_command "/etc/init.d/monit stop; /etc/init.d/monit start"
  action :nothing
end

directory "/etc/monit/config.d" do
  mode "0755"
  recursive true
  action :create
end

# this will fail and prevent us from restarting nagios if we broke the config
execute "test-monit-config" do
  command "/etc/init.d/monit syntax"
  notifies :restart, "service[monit]"
  action :nothing
end

node[:monit][:config_file] = File.join(node[:deployment][:config_path], "vcap.monitrc")

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
              
            fi
            EOH
      notifies :run, "execute[test-monit-config]", :immediately
      not_if do
        # only 10.04 has a really old version of monit that needs an upgrade
        node[:platform_version].to_f >= 11.10
      end
    end


    bash "Configure monit" do
      user "root"
      code <<-EOH
              # Configure as daemon with a 4 minutes start delay
              sudo sed -i 's/set daemon[[:space:]]*120/set daemon  10/g' /etc/monit/monitrc
              sudo sed -i 's/^#[[:space:]]*with start delay 240/     with start delay 240/g' /etc/monit/monitrc
              #sudo sed -i 's/monit quit/sudo service monit stop/g' /etc/init/vcap_reconfig.conf
              #sudo sed -i 's/monit start/sudo service monit start/g' /etc/init/vcap_reconfig.conf
              #Make sure that at least the localhost can connect to monit.
              # Otherwise sudo monit status will return 'errror connecting to monit daemon':
              # http://www.mail-archive.com/monit-general@nongnu.org/msg02887.html
              #Need to find the 3 lines here and uncomment them if that is not the case already:
              # set httpd port 2812 and
              #     use address localhost  # only accept connection from localhost
              #     allow localhost        # allow localhost to connect to the server and
              # this is set by default in 12.04
              sudo sed -i 's/^#[[:space:]]*set httpd port 2812 and/set httpd port 2812 and/g' /etc/monit/monitrc
              sudo sed -i 's/^#[[:space:]]*use address localhost/    use address localhost/g' /etc/monit/monitrc
              sudo sed -i 's/^#[[:space:]]*allow localhost/    allow localhost/g' /etc/monit/monitrc
              EOH
      notifies :run, "execute[test-monit-config]", :immediately
      only_if do
        return true unless ::File.exists?('/etc/monit/monitrc')
        monitrc_lines = File.readlines('/etc/monit/monitrc')
        matches = monitrc_lines.select { |line| line[/^#[\s]*set httpd port 2812/] ||
                                line[/^#[\s]*set daemon[\s]*120/] ||
                                line[/^#[\s]*with start delay 240/] }
        !matches.empty? 
      end
    end

    #Startup mode
    template "/etc/network/if-up.d/monit_dameon" do
      path "/etc/network/if-up.d/monit_dameon"
      source "monit_dameon_if_up.erb"
      mode 0755
      action :create
      only_if do
        node[:monit][:network_startup] == 1 || node[:monit][:network_startup] == true
      end
    end
        
###found=`egrep "^[[:space:]]*include \/etc\/monit\/config\.d\/\*" /etc/monit/monitrc`
    #Include directive and Startup mode
    bash "Setup monit daemon startup mode to #{node[:monit][:daemon_startup]}" do
      user "root"
      code <<-EOH
              sed -i 's/^startup=.*$/startup=#{node[:monit][:daemon_startup]}/' /etc/default/monit
              found=`egrep "^[[:space:]]*include /etc/monit/config\.d/\*" /etc/monit/monitrc`
              [ -z "$found" ] && echo "include /etc/monit/config.d/*" >> /etc/monit/monitrc
              found=`egrep "^[[:space:]]*with start delay " /etc/monit/monitrc`
              echo "Found start delay: $found"
              if [ -z "$found" ]; then
                found_commented=`egrep "^#[[:space:]]*with start delay " /etc/monit/monitrc`
                if [ -z "$found_commented" ]; then
                  echo "Could not find the commented line for the delay '#   with start delay 240' in /etc/monit/monitrc: not supported"
                  exit 1
                else
                  sed -i 's/^#[[:space:]]*with start delay .*/   with start delay 240 # delay the start by 4 minutes/' /etc/monit/monitrc
                fi
              fi
              EOH
      notifies :run, "execute[test-monit-config]", :immediately
      only_if do
        def monit_already_configured()
          Chef::Log.debug("::File.exists?(/etc/monit/monitrc) #{::File.exists?('/etc/monit/monitrc')}")
          Chef::Log.debug("::File.exists?(/etc/default/monit) #{::File.exists?('/etc/default/monit')}")
          return true unless ::File.exists?("/etc/monit/monitrc")
          return true unless ::File.exists?("/etc/default/monit")
          start_delay = nil
          include_config_d = nil
          ::File.readlines("/etc/monit/monitrc").collect do |name|
            start_delay ||= name[/^[[:space:]]*with start delay/]
            include_config_d ||= name[/^[[:space:]]*include \/etc\/monit\/config\.d\/\*/]
          end
          Chef::Log.debug("start_delay #{start_delay}")
          Chef::Log.debug("include_config_d #{include_config_d}")
          return true if start_delay.nil? || include_config_d.nil?
          startup_yes = nil
          ::File.readlines("/etc/default/monit").collect do |name|
            startup_yes ||= name == "startup=#{node[:monit][:daemon_startup]}"
          end
          Chef::Log.debug("startup_yes #{startup_yes}")
          return true if startup_yes.nil?
          Chef::Log.info("monit is already configured to start as a daemon with a delay")
          return false
        end
        monit_already_configured()
      end
    end
    
    #postgres?
    
    template "/etc/monit/config.d/postgresql.monitrc" do
      path "/etc/monit/config.d/postgresql.monitrc"
      source "postgresql.monitrc.erb"
      mode 0644
      action :create
      notifies :run, "execute[test-monit-config]", :immediately
      only_if do
        !node[:monit][:others].nil? && node[:monit][:others].include?("postgresql")
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
      dea_deps = node[:monit][:depends_on]["dea"].nil? ?
        nodes_components : ( node[:monit][:depends_on]["dea"] + nodes_components )
      node[:monit][:depends_on]["dea"] = dea_deps
    end
  end

  execute "vcap_monitrc" do
    command "sudo ln -sf /home/ubuntu/cloudfoundry/.deployments/intalio_devbox/config/vcap.monitrc /etc/monit/config.d/vcap.monitrc"
    action :nothing
  end

  template node[:monit][:config_file] do
    path node[:monit][:config_file]
    source "vcap.monitrc.erb"
    action :create
    notifies :run, "execute[test-monit-config]", :immediately
    notifies :run, 'execute[vcap_monitrc]', :immediately
    owner node[:deployment][:user]
    mode 0644
  end
