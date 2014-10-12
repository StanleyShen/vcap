require 'rubygems'

require 'jobs/job'

module Jobs
  class AdminApplicationEnv < Job
  end
end

class ::Jobs::AdminApplicationEnv
  def run
    res = {}
    # application information
    apps = {}
    vmc_client = @admin_instance.vmc_client
    vmc_client.apps.each{|v|
      name = v[:name]
      apps[name] = {'name' => name,'uri' => v[:uris].first}
    }
    res['apps'] = apps
   
    # default user
    manifest = @admin_instance.manifest
    res['default_user'] = manifest['default_user'] || ''

    send_data(res, true)
  end
end