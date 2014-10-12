require 'uri'

require 'create_admin/admin_instance'
require 'create_admin/http_proxy'

module Jobs
  module Commons; end
end

module Jobs::Commons
  include HttpProxy

  VERSION_FILE = 'version_built.properties'
  APP_VERSION_PATH = "app/#{VERSION_FILE}"
  
  def version_file
  end
  
  def app_instances(apps)
    instances = {}
    apps.each{|app|
      app_instances = admin_instance.app_status(app)
      if app_instances.empty?
        instances[app] = [{'state' => 'STOPPED'}]
      else
        instances[app] = app_instances
      end       
    }
    instances
  end
  
  def current_app_version(app = nil)
    apps = nil
    if (app.nil?)
      # get all application versions
      manifest = admin_instance.manifest
      apps = manifest['recipes'].first['applications'].values.collect{|v| v['name']}
    else
      apps = [app]
    end

    res = {}
    apps.each{|app_name|
      version_file = admin_instance.app_files(app_name, APP_VERSION_PATH)
      if version_file.nil? || version_file.empty?
        message = "can't find the file #{APP_VERSION_PATH} from application #{app_name}."
        error(message)
        res[app_name] = {'version' => 'NOT_AVAILABLE', 'release_date' => 'NOT_AVAILABLE', 'message' => message}
        next
      end

      infos = version_file.split(%r{\n})

      version = extract_marker_content(infos, 'version=')
      release_date = extract_marker_content(infos, 'built=')
      res[app_name] = {'version' => version, 'release_date' => release_date}
    }
    res
  end
  
  def available_app_version(app = nil)
    manifest = admin_instance.manifest
    recipe_apps = manifest['recipes'].first['applications'].values
    raise "can't find application from intalio_recipe.json manifest." if recipe_apps.nil? || recipe_apps.empty?

    unless app.nil?
      recipe_apps.select!{|v| v['name'] == app}
    end
    
    if recipe_apps.nil? || recipe_apps.empty?
      message = "can't find the #{app} from intalio recipe."
      error(message)
      return {app => {'version' => 'NOT_AVAILABLE', 'release_date' => 'NOT_AVAILABLE', 'message' => message}}
    end
    
    repo_url = get_download_url()
    create_apps = admin_instance.governed_apps

    res = {}
    recipe_apps.each{|recipe_app|
      app_name = recipe_app['name']

      # right now, the repo url of system setting is dedicated for create applications(central, jobs, intalio and intalio-sch, not for oauth, admin ...)
      # so for oauth and admin, will use the url from the manifest file directly.
      version_url = nil
      if create_apps.include?(app_name)
        # version for create applications: intalio, intalio-sch, central and jobs
        version_url = URI::join(repo_url, VERSION_FILE).to_s
      else
        # version for non-create applications: admin, oauth
        base_url = CreateAdmin.get_base_url(recipe_app['repository']['url'])
        version_url = URI::join(base_url, VERSION_FILE).to_s
      end
      
      begin
        version = http_get(version_url)
        if version.code != '200'
          message = "could not read the available version from #{version_url}: http status code #{version.code}"
          error(message)
          res[app_name] = {
            'version' => 'NOT_AVAILABLE',
            'release_date' => 'NOT_AVAILABLE',
            'message' => message
          }
          next
        end
        
        body = version.body    
        infos = body.split(%r{\n})
        version = extract_marker_content(infos, 'version=')
        release_date = extract_marker_content(infos, 'built=')
    
        res[app_name] = {'version' => version, 'release_date' => release_date}
      rescue => e
        message = "could not read the latest available version from #{version_url}: #{e.message}"
        error(message)
        res[app_name] = {
          'version' => 'NOT_AVAILABLE',
          'release_date' => 'NOT_AVAILABLE',
          'message' => message
        }
      end
    }

    res
  end
  
  def admin_instance
    ::CreateAdmin::AdminInstance.instance
  end


  def get_download_url
    url = CreateAdmin.get_repository_url
    return url if url && !url.empty?

    def_url = ENV['DEFAULT_DOWNLOAD_URL']
    return CreateAdmin.get_base_url(def_url)
  end
  
  def extract_marker_content(content, marker)
    info = content.select { |line|
      line.start_with?(marker)
    }

    if (info.size > 0)
      /(#{marker})(.*)?$/ =~ info[0]
      info = $2 unless $2.nil?
      return info
    end

    return 0
  end
end