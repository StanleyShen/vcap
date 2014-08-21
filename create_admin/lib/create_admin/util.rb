require 'rubygems'
require 'vmc_knife'

require "dataservice/postgres_ds"
require "create_admin/log"


module CreateAdmin
  include ::DataService::PostgresSvc
  include ::CreateAdmin::Log

  @@vmc_client = nil
  @@backup_threads = nil
  @@current_setting = nil
  @@backup_schedule_start_time = nil
  @@backup_schedule_failure = 0
  @@is_new_backup_schedule = false
  
  def self.backup_schedule_start_time
    @@backup_schedule_start_time
  end

  def self.get_backup_schedule_failure
    @@backup_schedule_failure
  end

  def self.flag_backup_schedule_failure
    @@backup_schedule_failure+=1
  end

  def self.reset_backup_schedule_failure
    @@backup_schedule_failure=0
  end
  
  def self.backup_schedule_started
    @@is_new_backup_schedule = false
  end
  
  def self.is_new_backup_schedule
    @@is_new_backup_schedule
  end
  
  def self.get_download_url(def_url)
    puts "get_download_url .... def_url i s..... #{def_url}"
    begin
      conn = ::DataService::PostgresSvc.get_postgres_db()
      puts "get_download_url .... conn i s..... #{conn}"
      result = conn.exec("select io_repository_url from io_system_setting where io_active='t';")
      
      puts "get_download_url .... result i s..... #{result}"
      
      url = result.getvalue(0, 0)
      return url.nil? ? def_url : "#{url}/create-distrib.tar.gz"
    rescue Exception => e
      puts "exception is ... #{e}"
      warn e
      #debug e.backtrace
      warn "Using default download url"
      return def_url
    ensure
      conn.close() unless conn.nil?
    end
  end
  
  # Index the urls
  # @param app_urls The list of app_urls either as an array either a string with commas.
  def self.index_urls(app_urls)
    app_urls = app_urls.split(',') if app_urls.kind_of? String
    indexed_app_urls = Hash.new
    app_urls.each do |app_url|
      if app_url =~ /\/\/([\w\.\d-]*)/
        app_url = $1
      end
      indexed_app_urls[app_url.strip] = app_url.split('.').map { |url| url.strip }
    end

    indexed_app_urls
  end
  
  # Compute the closest url selected in a list of url according to a hostname
  # @param scheme The scheme to return a URL nil to return a hostname
  # @param hostname The current hostname
  # @param indexed_urls List of urls, indexed by the method index_urls
  def self.get_closest_url(scheme, hostname, indexed_urls)
    #p "Got #{@@indexed_auth_urls}"
    return "#{DOMAIN_PREFIX}#{DEFAULT_APP_DOMAIN}" if hostname == 'localhost'
    # compute which url is the closest to the current host.
  
    curr_toks = hostname.split('.')
    url_with_best_score = nil
    bestScore = -1
    indexed_urls.each do |url,toks|
     # p "Looking at #{url} #{toks}"
      index_of_url_tok = toks.length-1
      score = 0
      curr_toks.reverse.each do |tok|
      #  p "comparing #{tok} with #{toks[index_of_url_tok]}"
        if tok == toks[index_of_url_tok]
          score += 1
        else
          break
        end
        index_of_url_tok -= 1
      end
      if score > bestScore
       # p "url_with_best_score so far: #{url}"
        url_with_best_score = url
        bestScore = score
      end
    end
    return scheme ? "#{scheme}://#{url_with_best_score}" : url_with_best_score
  end

  def self.app_info(manifest, app, parse_env = true)
    client = vmc_client_from_manifest(manifest)
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
  
#  def get_app(client,name)
#    app = client.app_info(name)
#    raise "No application called #{name} is deployed." if app.nil?
#    app
#  end
  
  def self.get_local_ipv4
    ip = Socket.ip_address_list.detect{ |intf|
      intf.ipv4? or intf.ipv4_private? and !(intf.ipv4_loopback? or intf.ipv4_multicast?)
    }
    ip.ip_address
  end
  
  def self.uptime_string(delta)
    num_seconds = delta.to_i
    days = num_seconds / (60 * 60 * 24);
    num_seconds -= days * (60 * 60 * 24);
    hours = num_seconds / (60 * 60);
    num_seconds -= hours * (60 * 60);
    minutes = num_seconds / 60;
    num_seconds -= minutes * 60;
    "#{days}d:#{hours}h:#{minutes}m:#{num_seconds}s"
  end

  @@filesize_conv = {
    1024 => 'B',
    1024*1024 => 'KB',
    1024*1024*1024 => 'MB',
    1024*1024*1024*1024 => 'GB',
    1024*1024*1024*1024*1024 => 'TB',
    1024*1024*1024*1024*1024*1024 => 'PB',
    1024*1024*1024*1024*1024*1024*1024 => 'EB'
  }
  
  def self.pretty_size(size)
    size = size.to_f
    @@filesize_conv.keys.each { |mult|
      next if size >= mult
      suffix = @@filesize_conv[mult]
      return "%.2f %s" % [ size / (mult / 1024), suffix ]
    }
  end
  
  class BackupDataService
    include ::DataService::PostgresSvc
    include ::CreateAdmin::Log
    
    def get_backup_setting()
      begin
        conn = get_postgres_db()
        pgresult = conn.exec("select extract(epoch from io_backup_period), io_backup_period, io_backup_storage_space_quantity[1] from io_system_setting where io_active='t';")
        result_to_setting(pgresult)
      rescue Exception => e
        warn e
        debug e.backtrace
        return nil
      ensure
        conn.close unless conn.nil?
      end
  
    end
  
    def result_to_setting(pgresult)
      period = pgresult.getvalue(0, 0).to_i || 0
      label = pgresult.getvalue(0, 1)
      storage = pgresult.getvalue(0, 2).to_i * (1024*1024) || -1
      BackupSetting.new(period, label, storage)
    end
  end
  
  def self.vmc_client_from_manifest(manifest, renew = false)
    target = manifest['target']
    user = manifest['email']
    password = manifest['password']

    vmc_client(target, user, password, renew)
  end
  
  def self.vmc_client(target, user, password, renew = false)
    begin
      Log.debug "Getting vmc client"
      @@vmc_client = login_vmc_client(target, user, password) if @@vmc_client.nil? || renew
      @@vmc_client
    rescue => e
      Log.error "Unable to login #{e.message}"
      Log.error e.backtrace
      nil
    end
  end
  
  def self.login_vmc_client(target, user, password)
    target = target || 'api.intalio.priv'
    user = user || 'system@intalio.com'
    password = password || 'gold'

    client = VMC::Client.new(target)
    client.login(user, password)
    client
  end
  
  def self.check_and_update_backup_settings()
    Log.debug "check_and_update_backup_settings......" 
    svc = BackupDataService.new()
    setting = svc.get_backup_setting()

    changed = @@current_setting.nil? || @@current_setting.period != setting.period

    Log.debug "Backup setting changed => #{changed} with settings #{setting}" if changed
    self.create_new_backup_schedules(setting) if changed
    setting
  end
end