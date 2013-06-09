#
# Cookbook Name:: ccdb
# Recipe:: default
#
# Copyright 2011, VMware
#
#
cf_pg_update_hba_conf(node[:ccdb][:database], node[:ccdb][:user], node[:postgresql_node][:system_version])
cf_pg_setup_db(node[:ccdb][:database], node[:ccdb][:user], node[:ccdb][:password], node[:ccdb][:adapter] == "postgresql" && node[:postgresql_node][:system_version] == node[:postgresql_node][:service_version] && node[:postgresql_node][:system_port] == node[:postgresql_node][:service_port], node[:postgresql_node][:system_port])
