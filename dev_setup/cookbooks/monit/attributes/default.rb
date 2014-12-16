include_attribute "deployment"
default[:monit][:vcap_exec] = node[:deployment][:vcap_exec]
default[:monit][:daemon_startup] = -1 #0, will disable starting as a daemon, 1 will enable it; anything else leaves it unchanged
default[:monit][:network_startup] = -1 #0, will create an /etc/network/if-up.d/monit_daemon script to start monit when a network interface is available
default[:monit][:vcap_components] = { :controller => ["cloud_controller", "health_manager", "redis_gateway", "redis_node", "router", "stager", "dns_publisher"], :db => ["mongodb_gateway", "mongodb_node", "postgresql_gateway", "postgresql_node","elasticsearch_gateway", "elasticsearch_node"], :dea => ["dea"] }
