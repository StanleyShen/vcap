module Jobs
  class AppsVersion < Job; end
end

class ::Jobs::AppsVersion

  def initialize(options)
    options = options || {}
    @app = options['app']
  end
  
  def run
    current_version = current_app_version(@app)
    available_version = available_app_version(@app)

    res = {}
    current_version.each{|k, v|
      ava_version = available_version[k]
      can_upgrade = false

      if (ava_version['version'] != 'NOT_AVAILABLE')
        if (v['version'] == 'NOT_AVAILABLE')
          can_upgrade = true
        else
          can_upgrade = ava_version['version'] > v['version']
        end
      end

      res[k] = {'current' => v, 'available' => ava_version, 'can_upgrade' => can_upgrade}
    }
    
    completed({'versions' => res})
  end
end