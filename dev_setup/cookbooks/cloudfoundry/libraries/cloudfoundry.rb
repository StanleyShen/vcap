require 'socket'

module CloudFoundry
  
  def cf_bundle_install(path)
    bash "Bundle install for #{path}" do
      cwd path
      environment ({'HOME' => "/home/#{node[:deployment][:user]}",
                    'USER' => "#{node[:deployment][:user]}"})
      code <<-EOH
      source $HOME/.bashrc
      cd #{path}
      cmd="#{File.join(node[:ruby][:path], "bin", "bundle")} install"
      set +e
      $cmd
      if [ $? != 0 ]; then
        echo "Retry 1 $cmd"
        $cmd
      fi 
      if [ $? != 0 ]; then
        echo "Retry 2 $cmd"
        $cmd
      fi
      set -e 
      if [ $? != 0 ]; then
        echo "Retry 3 $cmd"
        $cmd
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
