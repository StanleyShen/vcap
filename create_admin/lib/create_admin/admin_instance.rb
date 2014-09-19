require 'rubygems'
require 'vmc_knife'
require 'vmc_knife/commands/knife_cmds'

require "create_admin/log"

module CreateAdmin
  class AdminInstance
  end
end

class ::CreateAdmin::AdminInstance
  include ::CreateAdmin::Log
  include VMC::KNIFE::Cli

  @@instance = nil  

  def app_info(app, parse_env = true, manifest_path = nil)
    client = vmc_client(false, manifest_path)
    app_info = client.app_info(app)
    return if app_info.nil?

    return app_info unless parse_env

    app_env = app_info[:env]
    parsed_env = {}
    app_env.each do |e|
      k,v = e.split('=', 2)
      parsed_env[k] = v
    end
    app_info[:env] = parsed_env
    app_info
  end
  
  def governed_apps
    ['intalio']
  end
  
  def manifest(refresh = false, manifest_path = nil)
    if (refresh)
      return refresh_manifest(manifest_path)
    end
    @manifest = @manifest || refresh_manifest(manifest_path) 
  end
  
  def manifest_path(path)
    path || ENV['VMC_KNIFE_DEFAULT_RECIPE']
  end
  
  def vmc_client(renew = false, manifest_path = nil)
    return @vmc_client if @vmc_client && !renew

    manifest = manifest(renew, manifest_path)

    target = manifest['target']
    user = manifest['email']
    password = manifest['password']

    @vmc_client = vmc_client_by_credential(target, user, password)    
  end

  def vmc_client_by_credential(target, user, password)
    client = VMC::Client.new(target || 'api.intalio.priv')
    client.login(user || 'system@intalio.com', password || 'gold')
    client
  end

  def self.instance
   @@instance =  @@instance || ::CreateAdmin::AdminInstance.new
  end

  # instance cache  
  def add_cache(key, value)
    @instance_cache[key] = value
  end
  
  def get_cache(key, value)
    @instance_cache[key]
  end
  
  def delete_cache(key = nil)
    if key.nil?
      @instance_cache = {}
    else
      @instance_cache.delete(key)
    end
  end

  private
  @instance_cache = nil

  def initialize
    @@instance_cache = {}
  end
  
  def refresh_manifest(manifest_path = nil)
    @vmc_client = nil

    manifest = manifest_path || ENV['VMC_KNIFE_DEFAULT_RECIPE']
    @manifest = load_manifest(manifest_path)
  end
end