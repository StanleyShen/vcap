include_attribute "deployment"
#default[:ruby][:version] = "1.9.2-p180"
default[:ruby][:version] = "1.9.2-p290"
#default[:ruby][:version_regexp] =
default[:ruby][:source]  = "http://ftp.ruby-lang.org//pub/ruby/1.9/ruby-#{ruby[:version]}.tar.gz"
##default[:ruby][:path]    = File.join(node[:deployment][:home], "deploy", "rubies", "ruby-#{ruby[:version]}")

## old versions:
#default[:rubygems][:version] = "1.8.7"
#default[:rubygems][:bundler][:version] = "1.0.18"
#default[:rubygems][:rake][:version] = "0.8.7"

default[:rubygems][:version] = "1.8.17"
default[:rubygems][:bundler][:version] = "1.0.22"
default[:rubygems][:rake][:version] = "0.9.2.2"
default[:rubygems][:eventmachine][:version] = "0.12.11.cloudfoundry.3"
default[:rubygems][:thin][:version] = "1.3.1"
