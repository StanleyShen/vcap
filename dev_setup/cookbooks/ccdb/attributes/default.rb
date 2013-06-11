include_attribute "deployment"
include_attribute "postgresql"

default[:ccdb][:user] = node[:postgresql_node][:server_root_user]
default[:ccdb][:password] = node[:postgresql_node][:server_root_password]
default[:ccdb][:database] = "cloud_controller"
default[:ccdb][:port] = node[:postgresql_node][:system_port]
default[:ccdb][:adapter] = "postgresql"
default[:ccdb][:data_dir] = File.join(node[:deployment][:home], "ccdb_data_dir")
