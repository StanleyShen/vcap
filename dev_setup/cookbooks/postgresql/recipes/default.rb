#
# Cookbook Name:: postgresql
# Recipe:: default
#
# Copyright 2011, VMware
#
#
#

#this would always install the latest version of postgres.
#for now we keep it under our control
#%w[libpq-dev postgresql].each do |pkg|
#  package pkg
#end

case node['platform']
when "ubuntu"
  bash "Install postgres-#{node[:postgresql_node][:version]}" do
    code <<-EOH
POSTGRES_MAJOR_VERSION="#{node[:postgresql_node][:version]}"
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
        `echo "listen_addresses='#{node[:postgresql_node][:host]},localhost'" >> #{postgresql_conf_file}`
      else
        `sed -i.bkup -e "s/^\s*listen_addresses.*$/listen_addresses='#{node[:postgresql_node][:listen_addresses]}'/" #{postgresql_conf_file}`
      end

    end
  end
  # configure ltree.sql if necessary:
  if node[:postgresql_node][:ltree_in_template1]
    cf_pg_setup_ltree
  else
    `echo not configuring ltree on template1 #{node[:postgresql_node][:ltree_in_template1]}`
  end
  
  cf_pg_server_command 'restart'
  
else
  Chef::Log.error("Installation of PostgreSQL is not supported on this platform.")
end

cf_pg_update_hba_conf("all", "all", "#{cf_local_ip} 255.255.255.255", "md5")

unless node[:postgresql_node][:pg_hba_extra].nil?
  #relax the rules to connect to postgres.
  cf_pg_update_hba_conf(node[:postgresql_node][:pg_hba_extra][:database], node[:postgresql_node][:pg_hba_extra][:user], node[:postgresql_node][:pg_hba_extra][:ip_range], node[:postgresql_node][:pg_hba_extra][:pass_encrypt])
end

cf_pg_update_hba_conf(node[:postgresql_node][:database], node[:postgresql_node][:server_root_user])
cf_pg_setup_db(node[:postgresql_node][:database], node[:postgresql_node][:server_root_user], node[:postgresql_node][:server_root_password])



