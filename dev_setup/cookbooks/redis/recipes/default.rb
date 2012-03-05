compute_derived_attributes
node[:redis][:redis_bin_path] = File.join(node[:redis][:path], "bin", "redis-server")
expected_version=node[:redis][:version]
expected_version_found=`echo $(#{node[:redis][:redis_bin_path]} --version 2>&1) | grep #{expected_version}` if File.exists?(node[:redis][:redis_bin_path])

remote_file File.join("", "tmp", "redis-#{node[:redis][:version]}.tar.gz") do
  owner node[:deployment][:user]
  source "http://redis.googlecode.com/files/redis-#{node[:redis][:version]}.tar.gz"
  not_if do
    expected_version_found ||
      ::File.exists?(File.join("", "tmp", "redis-#{node[:redis][:version]}.tar.gz"))
  end
end

directory "#{node[:redis][:path]}" do
  owner node[:deployment][:user]
  group node[:deployment][:user]
  mode "0755"
end

%w[bin etc var].each do |dir|
  directory File.join(node[:redis][:path], dir) do
    owner node[:deployment][:user]
    group node[:deployment][:user]
    mode "0755"
    recursive true
    action :create
  end
end

bash "Install Redis" do
  cwd File.join("", "tmp")
  user node[:deployment][:user] #does not work: CHEF-2288
  environment ({'HOME' => "/home/#{node[:deployment][:user]}",
                'USER' => "#{node[:deployment][:user]}"})
  code <<-EOH
  source $HOME/.bashrc
  cd /tmp
  tar xzf redis-#{node[:redis][:version]}.tar.gz
  cd redis-#{node[:redis][:version]}
  make
  cd src
  cp redis-benchmark redis-cli redis-server redis-check-dump redis-check-aof #{File.join(node[:redis][:path], "bin")}
EOH
  not_if do
    expected_version_found
  end
end

template File.join(node[:redis][:path], "etc", "redis.conf") do
  source "redis.conf.erb"
  mode 0600
  owner node[:deployment][:user]
  group node[:deployment][:user]
end
