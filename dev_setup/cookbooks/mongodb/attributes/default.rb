include_attribute "deployment"

default[:mongodb_node][:version] = "2.6.3"
default[:mongodb_node][:source] = "http://fastdl.mongodb.org/linux/mongodb-linux-#{node[:kernel][:machine]}-#{mongodb_node[:version]}.tgz"
default[:mongodb_node][:path] = File.join(default[:deployment][:home], "deploy", "mongodb")

default[:mongodb_node][:index] = "0"
default[:mongodb_node][:available_memory] = "4096"
default[:mongodb_node][:max_memory] = "128"
default[:mongodb_node][:token] = "0xdeadbeef"
default[:mongodb_node][:node_timeout] = 2 #the value hardcoded here: https://github.com/cloudfoundry/vcap-services/commit/fe6415a8142f11b93e4197eb5663fd61b272eef3#L2R15

default[:mongodb_node][:mongod_conf][:journal] = false
default[:mongodb_node][:mongod_conf][:noprealloc] = false
default[:mongodb_node][:mongod_conf][:quota] = true
default[:mongodb_node][:mongod_conf][:quotafiles] = 4
default[:mongodb_node][:mongod_conf][:smallfiles] = true

