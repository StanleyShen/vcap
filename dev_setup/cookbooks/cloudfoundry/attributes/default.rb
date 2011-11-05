default[:cloudfoundry][:home] = File.join(ENV["HOME"], "cloudfoundry")
default[:cloudfoundry][:path] = File.join(cloudfoundry[:home], "vcap")
default[:cloudfoundry][:vmc][:version] = nil

