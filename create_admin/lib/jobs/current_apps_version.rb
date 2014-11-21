module Jobs
  class CurrentAppsVersion < Job; end
end

class ::Jobs::CurrentAppsVersion

  def initialize(options)
    options = options || {}
    @app = options['app']
  end
  
  def run
    completed(current_app_version(@app))  
  end
end