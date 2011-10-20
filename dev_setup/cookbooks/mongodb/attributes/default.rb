include_attribute "deployment"
default[:mongodb][:version] = "1.8.1"
default[:mongodb][:source] = "http://fastdl.mongodb.org/linux/mongodb-linux-#{node[:kernel][:machine]}-#{mongodb[:version]}.tgz"
default[:mongodb][:path] = File.join(node[:deployment][:home], "deploy", "mongodb")
default[:mongodb][:index] = "0"
default[:mongodb][:available_memory] = "4096"
default[:mongodb][:max_memory] = "128"
default[:mongodb][:token] = "changemongodbtoken"
default[:mongodb][:node_timeout] = 2 #the value hardocded here: https://github.com/cloudfoundry/vcap-services/commit/fe6415a8142f11b93e4197eb5663fd61b272eef3#L2R15
