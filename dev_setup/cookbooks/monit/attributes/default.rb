node[:monit][:config_file] = File.join(node[:deployment][:config_path], "vcap.monitrc")
node[:monit][:vcap_exec] = node[:deployment][:vcap_exec]
node[:monit][:daemon_startup] = -1 #0, will disable starting as a daemon, 1 will enable it; anything else leaves it unchanged