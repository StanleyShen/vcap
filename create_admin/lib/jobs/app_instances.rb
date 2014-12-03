module Jobs
  class AppInstances < Job; end
end

class ::Jobs::AppInstances

  def initialize(options)
    options = options || {}
    @apps = options['apps']
  end
  
  def run
    manifest = @admin_instance.manifest(false)
    apps = @apps.nil? ? manifest['recipes'].first['applications'].values.collect{|v| v['name']} : @apps.split(',')

    app_info = {}
    apps.each{|app|
      app_info[app] = @admin_instance.app_info(app, false)
    }
    completed({
      'instances' => app_instances(apps),
      'app_info' => app_info
    })
  end
end