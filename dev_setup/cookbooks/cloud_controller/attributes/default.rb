include_recipe "deployment"
default[:deployment][:welcome] = "VMware's Cloud Application Platform"

default[:cloud_controller][:config_file] = "cloud_controller.yml"
##default[:cloud_controller][:service_api_uri] = "http://api.#{node[:deployment][:domain]}"
default[:cloud_controller][:local_route] = nil
default[:cloud_controller][:admins] = ["dev@cloudfoundry.org"]
default[:cloud_controller][:description] = "VMware's Cloud Application Platform"
default[:cloud_controller][:support_address] = "http://support.cloudfoundry.com"

# Specifies if new users can register only from the host that is running the cloud controller
default[:cloud_controller][:allow_registration] = true
default[:cloud_controller][:app_uris][:allow_external] = false

# Staging
default[:cloud_controller][:staging][:grails] = "grails.yml"
default[:cloud_controller][:staging][:lift] = "lift.yml"
default[:cloud_controller][:staging][:node] = "node.yml"
default[:cloud_controller][:staging][:otp_rebar] = "otp_rebar.yml"
default[:cloud_controller][:staging][:platform] = "platform.yml"
default[:cloud_controller][:staging][:rails3] = "rails3.yml"
default[:cloud_controller][:staging][:sinatra] = "sinatra.yml"
default[:cloud_controller][:staging][:spring] = "spring.yml"
default[:cloud_controller][:staging][:java_web] = "java_web.yml"
default[:cloud_controller][:staging][:java_start] = "java_start.yml"
default[:cloud_controller][:staging][:php] = "php.yml"

# keys
default[:cloud_controller][:keys][:password] = 'password key goes here'
default[:cloud_controller][:keys][:token] = 'token key goes here'
default[:cloud_controller][:keys][:token_expiration] = 604800 # 7 * 24 * 60 * 60 (= 1 week)

#Stager
default[:cloud_controller][:stager][:max_staging_runtime] = 120 #seconds
default[:cloud_controller][:stager][:secure] = false
default[:cloud_controller][:stager][:new_stager_percent] = 0
default[:cloud_controller][:stager][:new_stager_email_regexp] = '@@' #won't match any email.
default[:cloud_controller][:stager][:auth][:user] = "vcap"
default[:cloud_controller][:stager][:auth][:password] = "vcap"

# Enable/disable starting apps in debug modes.
default[:cloud_controller][:allow_debug] = true

# Default builtin services
default[:cloud_controller][:builtin_services] = ["redis", "mongodb", "mysql", "neo4j", "postgresql"]

# Default capacity
default[:capacity][:memory] = 2048
default[:capacity][:max_uris] = 4
default[:capacity][:max_services] = 16
default[:capacity][:max_apps] = 20
