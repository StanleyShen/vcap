default[:dea][:config_file] = "dea.yml"
default[:dea][:local_route] = nil
default[:dea][:runtimes_default] = ["ruby19", "nodejs", "java"]
# see http://lists.opscode.com/sympa/arc/chef/2011-12/msg00203.html
default[:dea][:max_memory] = 2048
default[:dea][:logging] = 'debug'
default[:dea][:secure] = false
default[:dea][:multi_tenant] = true
default[:dea][:enforce_ulimit] = false
default[:dea][:force_http_sharing] = true