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

    completed({
      'instances' => app_instances(apps)
    })
  end
end