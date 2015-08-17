include_attribute "deployment"
default[:postgresql_node][:host] = "127.0.0.1"
default[:postgresql_node][:server_root_password] = "changeme"
default[:postgresql_node][:server_root_user] = "root"
default[:postgresql_node][:database] = "pg_service"
default[:postgresql_node][:version] = "9.4"
default[:postgresql_node][:index] = "0"
default[:postgresql_node][:max_db_size] = "500"
default[:postgresql_node][:available_storage] = "1024"
default[:postgresql_node][:token] = "0xdeadbeef"
default[:postgresql_node][:max_long_query] = 3
default[:postgresql_node][:max_long_tx] = 30
default[:postgresql_node][:max_db_conns] = 20
default[:postgresql_node][:node_timeout] = 2 #the value hardocded here: https://github.com/cloudfoundry/vcap-services/commit/fe6415a8142f11b93e4197eb5663fd61b272eef3#L2R15
default[:postgresql_node][:listen_addresses] = "*"
default[:postgresql_node][:extensions_in_template1] = "ltree,uuid-ossp" #for example: "ltree,uuid-ossp"
default[:postgresql_node][:local_acl] = "md5" #enable psql local connections for admin jobs
default[:postgresql_node][:system_port] = 5432
default[:postgresql_node][:db_hostname] = node[:deployment][:db_hostname]
#default[:postgresql_node][:pg_hba_extra][:user] = "all"
#default[:postgresql_node][:pg_hba_extra][:database] = "all"
#default[:postgresql_node][:pg_hba_extra][:ip_and_mask] = "0.0.0.0/0"
#default[:postgresql_node][:pg_hba_extra][:pass_encrypt] = "md5"
