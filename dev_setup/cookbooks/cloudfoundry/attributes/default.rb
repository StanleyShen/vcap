#include_attribute "ruby"
# these attributes were introduced to resolve issues with chef hosted that would not compute correctly the value of the attributes.
# in the 'deployment' recipe.
default[:cloudfoundry][:user_home] = ENV["HOME"]=='/root' ? "/home/ubuntu" : ENV["HOME"]
default[:cloudfoundry][:home] = File.join(default[:cloudfoundry][:user_home], "cloudfoundry")
default[:cloudfoundry][:path] = File.join(default[:cloudfoundry][:home], "vcap")

default[:cloudfoundry][:git][:vcap][:repo] = "https://github.com/intalio/vcap.git"
default[:cloudfoundry][:git][:vcap][:branch] = "4.0"
# use sub-modules by default. straight to the other repos is another style
default[:cloudfoundry][:git][:vcap][:enable_submodules] = true
# straight to the other repos is only used when submodules is disabled
default[:cloudfoundry][:git][:vcap_java][:repo] = "https://github.com/intalio/vcap-java.git"
default[:cloudfoundry][:git][:vcap_java][:branch] = "master"
default[:cloudfoundry][:git][:vcap_services][:repo] = "https://github.com/intalio/vcap-services.git"
default[:cloudfoundry][:git][:vcap_services][:branch] = "4.0"

default[:cloudfoundry][:git][:router][:repo] = "https://github.com/intalio/router.git"
default[:cloudfoundry][:git][:router][:branch] = "4.0"

default[:cloudfoundry][:vmc][:version] = '0.3.23'
