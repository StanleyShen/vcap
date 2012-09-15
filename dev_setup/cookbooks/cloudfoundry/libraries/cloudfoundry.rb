require 'socket'

module CloudFoundry

  # returns the appropriate bundle command
  # call this before the bash/ruby block. not inside it.
  def self.cf_invoke_bundler_cmd(node, path, cmd='install --local --verbose')
    CloudFoundry::cf_invoke_ruby_cmd(node, path, 'bundle', cmd)
  end

  # returns the appropriate bundle command
  # call this before the bash/ruby block. not inside it.
  def self.cf_invoke_ruby_cmd(node, path, bundle_or_gem, cmd)
    if Process.uid == 0
      # why is it so difficult to correctly load the gem environment for the ubuntu user?
      # so far this has been the best formula to prevent bundler from using the root's user's gem install directory.
      # I suspect that rvm (used by root) is really setting its directories everywhere.
      ## env GEM_HOME=#{gemdir} GEM_PATH=#{gemdir} RUBYOPT=rubygems
      "sudo -i -u #{node[:deployment][:user]} gemdir=\"$gemdir\"\
 bash -c \"source /home/#{node[:deployment][:user]}/.bashrc; source /home/#{node[:deployment][:user]}/.cloudfoundry_deployment_profile;\
 cd #{path};\
 #{File.join(node[:ruby][:path], "bin", bundle_or_gem)} #{cmd}\""
    else
      "#{File.join(node[:ruby][:path], "bin", bundle_or_gem)} #{cmd}"
    end
  end

  # gem build, gem install when we want to use the local vcap sources
  # this is the case for vcap_common and vcap_staging
  def cf_gem_build_install(path,gem_name=nil)
    gem_name||="vcap_#{File.basename(path)}"
    path=File.expand_path(path)
    gem_install_cmd=CloudFoundry::cf_invoke_ruby_cmd(node, path, 'gem', "build #{gem_name}.gemspec")
    gem_dir_cmd=CloudFoundry::cf_invoke_ruby_cmd(node, path, 'gem', "env gemdir")
    gem_build_cmd=CloudFoundry::cf_invoke_ruby_cmd(node, path, 'gem', "install #{gem_name}*.gem --local --no-rdoc --no-ri --install-dir $gemdir")
    bash "Gem build and install for #{gem_name} in #{path}" do
      cwd path
      environment ({'HOME' => "/home/#{node[:deployment][:user]}",
                    'USER' => "#{node[:deployment][:user]}"})
      code <<-EOH
source $HOME/.bashrc
source $HOME/.cloudfoundry_deployment_profile
cd #{path}
if [ ! -f 'Gemfile' ]; then
  echo "Nothing to build not Gemfile in "`pwd`
  exit 1
fi
if [ ! -f 'Gemfile.lock' ]; then
  echo "Nothing to build not Gemfile.lock in "`pwd`"; Use bundle update and commit the lock file in git?"
  exit 1
fi
# re-install vcap_common to make sure that it is the one as found in the current sources
set -e
cd #{path}
ls #{gem_name}.gemspec
if [ "$?" != "0" ]; then
  echo "Nothing to build: Can't find a #{gem_name}.gemspec file"
fi
[ $(ls | egrep #{gem_name}*.gem$) ] && rm #{gem_name}*.gem
# #{File.join(node[:ruby][:path], "bin", "gem")} build #{gem_name}.gemspec
#{gem_install_cmd}
ls #{gem_name}*.gem
if [ "$?" != "0" ]; then
  echo "Failed to build the gem: can't find a #{gem_name}*.gem file"
fi
gemdir=`#{gem_dir_cmd}`
# #{File.join(node[:ruby][:path], "bin", "gem")} install #{gem_name}*.gem --local --no-rdoc --no-ri --install-dir $gemdir
#{gem_build_cmd}
if [ "$?" != "0" ]; then
  echo "Failed to install the gem"
  exit 1
fi
echo "Installed "`#{gem_name}*.gem`" in "$gemdir
EOH
    end

  end

  def cf_bundle_install(path, cmd='install --local --verbose')
    path=File.expand_path(path)
    bundle_install_cmd=CloudFoundry::cf_invoke_bundler_cmd(node, path, cmd)
    bash "Bundle install for #{path}" do
      cwd path
      environment ({'HOME' => "/home/#{node[:deployment][:user]}",
                    'USER' => "#{node[:deployment][:user]}"})
      code <<-EOH
source $HOME/.bashrc
source $HOME/.cloudfoundry_deployment_profile
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
#{Process.uid == 0 ? "sudo -i -u #{node[:deployment][:user]} gemdir=\"$gemdir\" && sudo chown -R "+node[:deployment][:user]+":"+node[:deployment][:user]+" $gemdir" : ""}
EOH
      only_if { ::File.exist?(File.join(path, 'Gemfile')) }
    end
    # (re-)install vcap_common as mostlikely this bundle install overrode us.
    cf_gem_build_install(File.join(node["cloudfoundry"]["path"], "common"))
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
