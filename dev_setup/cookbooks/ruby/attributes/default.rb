include_attribute "deployment"

default[:ruby][:version] = "1.9.3-p547"
default[:ruby][:version_regexp] = Regexp.quote(ruby[:version]).gsub(/-/, '-?')
default[:ruby][:source]  = "http://ftp.ruby-lang.org//pub/ruby/1.9/ruby-#{ruby[:version]}.tar.gz"
default[:ruby][:path]    = File.join(node[:deployment][:home], "deploy", "rubies", "ruby-#{ruby[:version]}")

default[:rubygems][:version] = "2.2.2"
default[:rubygems][:bundler][:version] = "1.6.2"
default[:rubygems][:rake][:version] = "10.1.0"
default[:rubygems][:eventmachine][:version] = "0.12.11.cloudfoundry.3"
default[:rubygems][:thin][:version] = "1.6.2"
