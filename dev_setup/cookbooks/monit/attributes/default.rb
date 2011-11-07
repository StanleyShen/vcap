node[:monit][:config_file] = File.join(node[:deployment][:config_path], "vcap.monitrc")
node[:monit][:vcap_exec] = node[:deployment][:vcap_exec]
