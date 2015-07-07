include_attribute "deployment"
default[:nodejs][:version] = "0.12.4"
default[:nodejs][:path] = File.join(node[:deployment][:home], "deploy", "nodejs")
default[:nodejs][:source] = "http://nodejs.org/dist/v#{node[:nodejs][:version]}/node-v#{node[:nodejs][:version]}-linux-x64.tar.gz"

default[:scrypt][:version] = "4.0.7"