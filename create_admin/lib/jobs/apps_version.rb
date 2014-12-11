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
          can_upgrade = can_upgrade?(v['version'], ava_version['version'])
        end
      end

      res[k] = {'current' => v, 'available' => ava_version, 'can_upgrade' => can_upgrade}
    }
    
    completed({'versions' => res})
  end

  # upgrade logic:
  # 1) current version has same major number as available version 
  # and
  # 2) available version has bigger minor number than current version 
  # 2b) if minor numbers are then same, available version has bigger patch number than current version
  # 2c) if minor numbers and patch numbers are the same, available version has bigger build number than current version
  def can_upgrade?(cur_ver, ava_ver)
    cur_nums = cur_ver.split('.')
    ava_nums = ava_ver.split('.')

    return false if cur_nums[0] != ava_nums[0]

    # version format is: Major.minor.patch.build
    return true if (ava_nums[1].to_i > cur_nums[1].to_i)

    if (ava_nums[1].to_i == cur_nums[1].to_i)
      return true if (ava_nums[2].to_i > cur_nums[2].to_i)

      if (ava_nums[2].to_i == cur_nums[2].to_i)
        return true if (ava_nums[3].to_i > cur_nums[3].to_i)
      end
    end

    false
  end
end