#
# Cookbook Name:: postgresql
# Recipe:: default
#
# Copyright 2011, VMware
#
#
#
%w[libpq-dev postgresql].each do |pkg|
  package pkg
end

case node['platform']
when "ubuntu"
  bash "Install postgres-#{node[:postgresql][:version]}" do
    code <<-EOH
POSTGRES_MAJOR_VERSION="#{node[:postgresql][:version]}"
apt-get install python-software-properties
add-apt-repository ppa:pitti/postgresql
apt-get -qy update
apt-get install -qy postgresql-$POSTGRES_MAJOR_VERSION postgresql-contrib-$POSTGRES_MAJOR_VERSION
apt-get install -qy postgresql-server-dev-$POSTGRES_MAJOR_VERSION libpq-dev libpq5
EOH
  end
  
  ruby_block "postgresql_conf_update" do
    block do
      / \d*.\d*/ =~ `pg_config --version`
      pg_major_version = $&.strip

      # update postgresql.conf
      postgresql_conf_file = File.join("", "etc", "postgresql", pg_major_version, "main", "postgresql.conf")
      `grep "^\s*listen_addresses" #{postgresql_conf_file}`
      if $?.exitstatus != 0
        `echo "listen_addresses='#{node[:postgresql][:host]},localhost'" >> #{postgresql_conf_file}`
      else
        `sed -i.bkup -e "s/^\s*listen_addresses.*$/listen_addresses='#{node[:postgresql][:listen_addresses]}'/" #{postgresql_conf_file}`
      end

      # configure ltree.sql if necessary:
      if node[:postgresql][:ltree_in_template1]
        cf_pg_setup_ltree
      end
          
      pg_server_command 'restart'
    end
  end
  
else
  Chef::Log.error("Installation of PostgreSQL is not supported on this platform.")
end
