#
# Cookbook Name:: essentials
# Recipe:: default
#
# Copyright 2011, VMWARE
#
#

%w{apt-utils build-essential libssl-dev
   libxml2 libxml2-dev libxslt1.1 libxslt1-dev git-core sqlite3 libsqlite3-ruby
   libsqlite3-dev unzip zip ruby-dev libmysql-ruby libmysqlclient-dev libcurl4-openssl-dev libpq-dev python-software-properties}.each do |p|
  package p do
    action [:install]
  end
end

if node[:deployment][:profile]
  file node[:deployment][:profile] do
    owner node[:deployment][:user]
    group node[:deployment][:group]
  content <<-EOH
if [ -n "$GEM_HOME" -a $(echo "$GEM_HOME" | grep "/root") ]; then
  echo "WARN: WRONG ENV. GEM_HOME is $GEM_HOME trying a sudo -i -u gem env gemdir to fix things"
  gemdir=`sudo -i -u #{node[:deployment][:user]} #{node[:ruby][:path]}/bin/gem env gemdir`
  export GEM_HOME=$gemdir
  export GEM_PATH=$gemdir
fi
[ -z $(echo $PATH | grep #{node[:ruby][:path]}/bin ) ] && export PATH=#{node[:ruby][:path]}/bin:`#{node[:ruby][:path]}/bin/gem env gemhome`/bin:$PATH
EOH
  end
end
