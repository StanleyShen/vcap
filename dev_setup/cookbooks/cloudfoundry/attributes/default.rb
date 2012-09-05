#include_attribute "ruby"
# these attributes were introduced to resolve issues with chef hosted that would not compute correctly the value of the attributes.
# in the 'deployment' recipe.
##default[:cloudfoundry][:user_home] = ENV["HOME"]=='/root' ? "/home/ubuntu" : ENV["HOME"] # messy
##default[:cloudfoundry][:home] = File.join(node[:cloudfoundry][:user_home], "cloudfoundry")
##default[:cloudfoundry][:path] = File.join(cloudfoundry[:home], "vcap")
default[:cloudfoundry][:vmc][:version] = nil

default[:cloudfoundry][:git][:vcap][:repo] = "https://github.com/cloudfoundry/vcap.git"
default[:cloudfoundry][:git][:vcap][:branch] = "master"
# use sub-modules by default. straight to the other repos is another style
default[:cloudfoundry][:git][:vcap][:enable_submodules] = true
# straight to the other repos is only used when submodules is disabled
default[:cloudfoundry][:git][:vcap_java][:repo] = "https://github.com/cloudfoundry/vcap-java.git"
default[:cloudfoundry][:git][:vcap_java][:branch] = "master"
default[:cloudfoundry][:git][:vcap_services][:repo] = "https://github.com/cloudfoundry/vcap-services.git"
default[:cloudfoundry][:git][:vcap_services][:branch] = "master"

default[:cloudfoundry][:git][:router][:repo] = "https://github.com/cloudfoundry/router.git"
default[:cloudfoundry][:git][:router][:branch] = "master"

