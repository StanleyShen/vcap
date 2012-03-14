module RubyInstall
  def cf_ruby_install(ruby_version, ruby_source, ruby_path)
    rubygems_version = node[:rubygems][:version]
    bundler_version = node[:rubygems][:bundler][:version]
    rake_version = node[:rubygems][:rake][:version]
    ubuntu_version=`lsb_release -sr`
    if ubuntu_version =~ /^10\./
      package "libreadline5-dev"
    else
      package "libreadline6-dev"
      package "libffi-dev"
    end

    %w[ build-essential libssl-dev zlib1g-dev libxml2-dev libpq-dev].each do |pkg|
      package pkg
    end

    remote_file File.join("", "tmp", "ruby-#{ruby_version}.tar.gz") do
      retries 4
      owner node[:deployment][:user]
      source ruby_source
      not_if { ::File.exists?(File.join("", "tmp", "ruby-#{ruby_version}.tar.gz")) }
    end

    directory ruby_path do
      owner node[:deployment][:user]
      group node[:deployment][:group]
      mode "0755"
      recursive true
      action :create
    end
    
    bash "Install Ruby #{ruby_path}" do
      cwd File.join("", "tmp")
      user node[:deployment][:user] #does not work: CHEF-2288
      group node[:deployment][:group] #does not work: CHEF-2288
      environment ({'HOME' => "/home/#{node[:deployment][:user]}",
                    'USER' => "#{node[:deployment][:user]}"})
      code <<-EOH
      source $HOME/.bashrc
      cd /tmp
      if [ -d "ruby-#{ruby_version}/.ext" ]; then
        rm -rf ruby-#{ruby_version}/.ext
      fi
      if [ ! -d "ruby-#{ruby_version}" ]; then
        echo "Unzipping the ruby-#{ruby_version}"
        tar xzf ruby-#{ruby_version}.tar.gz
      fi
      cd ruby-#{ruby_version}
      # disable SSLv2: it is not present in modern linux distrib as it is insecure.
      sed -e -i 's/^[[:space:]]*OSSL_SSL_METHOD_ENTRY(SSLv2)/\/\/    OSSL_SSL_METHOD_ENTRY(SSLv2)/g' ext/openssl/ossl_ssl.c
      sed -e -i 's/^[[:space:]]*OSSL_SSL_METHOD_ENTRY(SSLv2_/\/\/    OSSL_SSL_METHOD_ENTRY(SSLv2_/g' ext/openssl/ossl_ssl.c
      echo "About to do: configure --disable-pthread --prefix=#{ruby_path}"
      ./configure --disable-pthread --prefix=#{ruby_path}
      make
      make install
EOH
      not_if do
        ::File.exists?(File.join(ruby_path, "bin", "ruby"))
      end
    end

    remote_file File.join("", "tmp", "rubygems-#{rubygems_version}.tgz") do
      owner node[:deployment][:user]
      source "http://production.cf.rubygems.org/rubygems/rubygems-#{rubygems_version}.tgz"
      not_if { ::File.exists?(File.join("", "tmp", "rubygems-#{rubygems_version}.tgz")) }
    end

    bash "Install RubyGems #{ruby_path}" do
      cwd File.join("", "tmp")
      user node[:deployment][:user] #does not work: CHEF-2288
      group node[:deployment][:group] #does not work: CHEF-2288
      environment ({'HOME' => "/home/#{node[:deployment][:user]}",
                    'USER' => "#{node[:deployment][:user]}"})
      code <<-EOH
      source $HOME/.bashrc
      cd /tmp
      tar xzf rubygems-#{rubygems_version}.tgz
      cd rubygems-#{rubygems_version}
      #{File.join(ruby_path, "bin", "ruby")} setup.rb
EOH
      not_if do
        ::File.exists?(File.join(ruby_path, "bin", "gem")) &&
            system("#{File.join(ruby_path, "bin", "gem")} -v | grep -q '#{rubygems_version}$'")
      end
    end
    
    ruby_block "compute_gemdir" do
      block do
        if Process.uid == 0
          gemdir=`sudo -u #{node[:deployment][:user]} #{node[:ruby][:path]}/bin/gem env gemdir`.strip
        else
          gemdir=`#{node[:ruby][:path]}/bin/gem env gemdir`.strip
        end
        raise "Unexpected gemdir #{gemdir}" unless gemdir && (/^#{Regexp.quote("/home/"+node[:deployment][:user])}"/ =~ gemdir)
        node[:ruby][:gemdir]=gemdir
      end
      action :create
    end

    gem_package "bundler" do
      options "--config-file #{ruby_path}/lib/chef.gemrc"
      retries 4
      version bundler_version
      gem_binary "sudo -i -u #{node[:deployment][:user]} #{File.join(ruby_path, "bin", "gem")}"
    end

    gem_package "rake" do
      retries 4
      version rake_version
      gem_binary "sudo -i -u #{node[:deployment][:user]} #{File.join(ruby_path, "bin", "gem")}"
    end

    # The default chef installed with Ubuntu 10.04 does not support the "retries" option
    # for gem_package. It may be a good idea to add/use that option once the ubuntu
    # chef package gets updated.

    # ruby install will install the myql gem so we need its dependnecy:
    package "mysql-client"
    package "libmysqlclient-dev"
    
    %w[ rack eventmachine thin sinatra mysql pg ].each do |gem|
      gem_package gem do
        retries 4
        gem_binary "sudo -i -u #{node[:deployment][:user]} #{File.join(ruby_path, "bin", "gem")}"
      end
    end
  end
end

class Chef::Recipe
  include RubyInstall
end

