module RubyInstall
  def cf_ruby_install(ruby_version, ruby_source, ruby_path)
    bundler_version = node[:rubygems][:bundler][:version]
    ubuntu_version=`lsb_release -sr`
    if ubuntu_version =~ /^10\./
      package "libreadline5-dev"
    else
      package "libreadline6-dev"
    end

    %w[ build-essential libssl-dev zlib1g-dev libxml2-dev libpq-dev libyaml-dev].each do |pkg|
      package pkg
    end

    remote_file File.join("", "tmp", "ruby-#{ruby_version}.tar.gz") do
      retries 4
      owner node[:deployment][:user]
      group node[:deployment][:group]
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
      if [ ! -d "ruby-#{ruby_version}" ]; then
        echo "Unzipping the ruby-#{ruby_version}"
        tar xzf ruby-#{ruby_version}.tar.gz
        if [ "$?" != "0" ]; then
          # http://tickets.opscode.com/browse/CHEF-3140
          # let's attempt a simple untar as the file is probably uncompressed
          # already
          tar xf ruby-#{ruby_version}.tar.gz
          if [ "$?" != "0" ]; then
            echo "Failed to unzip "`pwd`"/ruby-#{ruby_version}.tar.gz"
            exit 1
          fi
        fi
      fi
      cd ruby-#{ruby_version}
      echo "About to do: configure --disable-pthread --prefix=#{ruby_path}"
      ./configure --disable-pthread --prefix=#{ruby_path}
      make
      make install
EOH
      not_if do
        ::File.exists?(File.join(ruby_path, "bin", "ruby"))
      end
    end

    gem_package "bundler" do
      options "--config-file #{ruby_path}/lib/chef.gemrc"
      retries 4
      version bundler_version
      gem_binary "sudo -i -u #{node[:deployment][:user]} #{File.join(ruby_path, "bin", "gem")}"
    end
  end
end

class Chef::Recipe
  include RubyInstall
end

