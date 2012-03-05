require 'socket'

module CloudFoundry

  # returns the appropriate bundle command
  # call this before the bash/ruby block. not inside it.
  def self.cf_invoke_bundler_cmd(node, path, cmd='install --verbose')
    Chef::Log.warn("CURENT Process.uid=#{Process.uid}")
    if Process.uid == 0
      gemdir=`sudo -i -u #{node[:deployment][:user]} #{node[:ruby][:path]}/bin/gem env gemdir`.strip
      path_option = /install/ =~ cmd ? "--path #{gemdir}" : ""
      # why is it so difficult to correctly load the gem environment for the ubuntu user?
      # so far this has been the best formula to prevent bundler from using the root's user's gem install directory.
      # I suspect that rvm (used by root) is really setting its directories everywhere.
      ## env GEM_HOME=#{gemdir} GEM_PATH=#{gemdir} RUBYOPT=rubygems
      "sudo -i -u #{node[:deployment][:user]}\
 bash -c \"source $HOME/.bashrc; source $HOME/.cloudfoundry_deployment_profile; cd #{path};\
 #{File.join(node[:ruby][:path], "bin", "bundle")} #{cmd}#{path_option}\""
    else
      Chef::Log.warn("NOT using sudo")
      File.join(node[:ruby][:path], "bin", "bundle")
    end
  end

  def cf_bundle_install(path)
    bundle_install_cmd=CloudFoundry::cf_invoke_bundler_cmd(node, path, 'install --verbose')
    Chef::Log.warn("bundle_install_cmd #{bundle_install_cmd}")
    bash "Bundle install for #{path}" do
      cwd path
      environment ({'HOME' => "/home/#{node[:deployment][:user]}",
                    'USER' => "#{node[:deployment][:user]}"})
      code <<-EOH
source $HOME/.bashrc
cd #{path}
set +e
#{bundle_install_cmd}
if [ $? != 0 ]; then
  echo "Retry 1"
  #{bundle_install_cmd}
fi
if [ $? != 0 ]; then
  echo "Retry 2"
  #{bundle_install_cmd}
fi
set -e 
if [ $? != 0 ]; then
  echo "Retry 3"
  #{bundle_install_cmd}
fi
EOH
      only_if { ::File.exist?(File.join(path, 'Gemfile')) }
    end
  end

  A_ROOT_SERVER = '198.41.0.4'
  def cf_local_ip(route = A_ROOT_SERVER)
    begin
      route ||= A_ROOT_SERVER
      orig, Socket.do_not_reverse_lookup = Socket.do_not_reverse_lookup, true
      UDPSocket.open {|s| s.connect(route, 1); s.addr.last }
    rescue
      # this is when the public internet is not reachable.
      # for example a 'Host-only' private network. On mac we should use ifconfig getifaddr <if_name>
      ifconfig = File.exist?("/sbin/ifconfig") ? "/sbin/ifconfig" : "ifconfig"
      ip=`#{ifconfig} | grep "inet addr" | grep -v "127.0.0.1" | awk '{ print $2 }' | awk -F: '{ print $2 }'`
      raise "Network unreachable." unless ip
      ip.strip
    ensure
      Socket.do_not_reverse_lookup = orig
    end
  end
    
end

class Chef::Recipe
  include CloudFoundry
end
