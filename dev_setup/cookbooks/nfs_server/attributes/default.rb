include_attribute "deployment"

default[:nfs][:server_path] = "/var/vcap/services/nfs"
default[:nfs][:client_path] = "/home/ubuntu/intalio/sharedfs"
