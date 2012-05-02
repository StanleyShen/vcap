include_attribute "deployment"
default[:monit][:vcap_exec] = node[:deployment][:vcap_exec]
default[:monit][:daemon_startup] = -1 #0, will disable starting as a daemon, 1 will enable it; anything else leaves it unchanged
default[:monit][:network_startup] = -1 #0, will create an /etc/network/if-up.d/monit_daemon script to start monit when a network interface is available
