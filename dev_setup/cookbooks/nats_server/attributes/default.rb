include_attribute "deployment"
default[:nats_server][:port] = "4222"
default[:nats_server][:user] = "nats"
default[:nats_server][:password] = "nats"
default[:nats_server][:logtime] = "true"
default[:nats_server][:debug] = "false"
default[:nats_server][:trace] = "false"
default[:nats_server][:is_os_daemon] = true
#default[:nats_server][:tracked_net_iface] = "eth0"
