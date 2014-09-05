require 'rubygems'
require 'wrest'
require 'sys/filesystem'

require "create_admin/util"
require "create_admin/http_proxy"
require "vmc/vmcapphelpers"
require "jobs/job"
require "route53/dns_gateway_client"

module Jobs
  class StatusJob < Job
  end
end

class ::Jobs::StatusJob
  include VMC::KNIFE::Cli
  include HttpProxy

  def initialize(options)
    options = options || {}

    @manifest_path = options['manifest']

    @admin_instance = CreateAdmin.instance
    @manifest = @admin_instance.manifest(false, @manifest_path)
    @client = @admin_instance.vmc_client(false, @manifest_path)

    @admin_env = @admin_instance.app_info('admin', true, @manifest_path)[:env]
    @version_file = options['INTALIO_VERSION_FILE'] || @admin_env['INTALIO_VERSION_FILE'] 
    @apps_in_recipe = ['intalio']
    @app_name_intalio = 'intalio'
    @app_status = {}
  end

  def run    
    begin
      client_info = @client.info
    rescue VMC::Client::TargetError => e
      return { "error" => "cloudfoundry is down", "message" => e.message, "exception" => e }.to_json
    end

    status = {}

    published_ip = @manifest['dns_provider']['dns_published_ip']
    status[:server_ip] = published_ip != "" ? published_ip: CreateAdmin.get_local_ipv4
    if usage = client_info[:usage] and limits = client_info[:limits]
      tmem  = CreateAdmin.pretty_size(limits[:memory]*1024*1024)
      mem   = CreateAdmin.pretty_size(usage[:memory]*1024*1024)
      tser  = limits[:services]
      ser   = usage[:services]
      tapps = limits[:apps] || 0
      apps  = usage[:apps]  || 0
    end

    status[:vmc_info] = { :description => client_info[:description],
                          :target => @client.target,
                          :support => client_info[:support],
                          :usage => { :memory => "#{mem} of #{tmem}",
                                      :services => "#{ser} of #{tser}",
                                      :apps => "#{apps} of #{tapps}",} }
    cli_client = VMC::Cli::Command::AppsExt.new
    cli_client.client = @client

    status[:free_disk_space] = get_free_disk_space()

    status[:app_stats] = apps_stats = {}
    @apps_in_recipe.each do |appname|
      apps_stats[appname.to_sym] = get_app_health(@client, cli_client, appname)
    end

    def_download_url = @admin_env['DEFAULT_DOWNLOAD_URL']
    begin
      intalio_health = apps_stats[@app_name_intalio.to_sym][:health]
#      status[:intalio_master_test] = get_intalio_status(request, intalo_health)
      status[:available_update] = get_update_version_info(CreateAdmin.get_download_url(def_download_url), intalio_health)
    rescue => e
      error "system error when querying the master test: #{e.message}"
      error e.backtrace
      status[:intalio_master_test] = {:colored_status => "red",
                                      :message => "system error when querying the master test: #{e.message}",
                                      :exception => e.backtrace}
    end

    # TODO:......
    status[:admin_version] = 10#ADMIN_VERSION
    send_json(status, true)
  end
  
  private
  
  def get_free_disk_space
    begin
      stat = Sys::Filesystem.stat("/")
      mb_available = stat.block_size * stat.blocks_available / 1024 / 1024
    rescue Exception => e
      warn "Unable to query free disk space #{e.message}"
      mb_available = 0
    end    
  end
  
  def download_update_version_info(download_url)
    download_url = download_url.sub(/([^\/]*\.tar\.gz)/, "version_built.properties")
    puts "Checking download repo #{download_url}"
  
    begin
      version = http_get(download_url)
      puts "version is ...... #{version}"
      if version.code != "200"
        return { :success => false, :message => "could not read the available version from #{download_url}: http status code #{version.code}",
               :body => version.body }
      end
      body = version.body
  
      infos = body.split(%r{\n})
      build_number = get_app_info(infos, 'version=')
      release_date = get_app_info(infos, 'built=')
      debug "Next version #{build_number} on #{release_date}"
  
      version_info = { :release_date => release_date, :build_number => build_number }
      return version_info
    rescue => e
      warn "could not read the latest available version from #{download_url}: #{e.message}"
      return nil
    end
  end

  def get_app_info(infos, marker)
    info = infos.select { | line |
      line.start_with?(marker)
    }
  
    if(info.size>0)
      /(#{marker})(.*)?$/ =~ info[0]
      info = $2 unless $2.nil?
      debug "App info for #{marker} = #{info}"
      return info
    end
  
    return 0
  end
  
  # Parse the version.xml next to the intalio.war and returns the timestamp and version extracted out of it.
  def get_update_version_info(download_url, intalio_health)
    unless intalio_health == 'RUNNING'
      debug "Intalio is not running"
      version_info = @app_status['version_info'] || {}
      return { :success => true, :message => "Application is not running. Using cached version info"}.merge!(version_info)
    end
  
    begin
      cli_client = VMC::Cli::Command::AppsExt.new
      cli_client.client = @client
      manifest = cli_client.__files(@app_name_intalio, @version_file)
      debug "App manifest #{manifest}"
  
      version = 0
      unless(manifest.nil?)
        infos = manifest.split(%r{\n})
  
        version = get_app_info(infos, 'version=')
        release_date = get_app_info(infos, 'built=')
        debug "Current version #{version}"
  
        latest_version = download_update_version_info(download_url)
        puts "latest_version is .... #{latest_version}"

        next_build = latest_version[:build_number] unless latest_version.nil?
        debug "Latest version info #{latest_version}"

        has_next_build = false
        has_next_build = next_build.to_s > version.to_s if next_build
  
        @app_status['version_info'] = { :build_number => version, :release_date => release_date, :next_version => has_next_build, :next_build => latest_version }
        return @app_status['version_info']
      else
        return { :success => false, :message => "No version info available from #{version_file}", :build_number => version}
      end
    rescue => e
      error "Encountered some VMC client error while querying #{version_file} => #{e.message}"
      error e.backtrace
      return { :success => false, :message => "could not read the available version from #{version_file}",
             :exception => e.message, :build_number => version}
    end
  
  end
  
  def get_intalio_status(request, intalio_health)  
    jobs = get_app_jobs_info(@app_name_intalio)
    debug "Current job #{jobs}"
  
    backup_info = get_backup_dates()
  
    if jobs.nil?
      jobs = {}
    elsif jobs[:status] != 'completed' && jobs[:status] != 'failed'
      #we report the last jobs statuses that took place.
      #so if all the report
      return { :colored_status => "orange", :status => "jobs going on",
             :message => "Application #{@app_name_intalio} has some jobs going on",
             :jobs => jobs, :backups => backup_info }
    end
  
    # get the uri of the intalio application
    app_stats = @client.app_stats(@app_name_intalio)
  
    #debug "App stats #{app_stats}"
    license = @app_status['license'] || ''
  
    return { :colored_status => "red",
             :message => "Application #{@app_name_intalio} not running",
             :jobs => jobs,
             :backups => backup_info,
             :license => license } if (app_stats.nil? || app_stats.empty?) && intalio_health == 'STOPPED'
  
    instance = app_stats.first
  
    return { :colored_status => "orange", :status => "no-stats",
             :message => "No stats available for application #{@app_name_intalio} yet",
             :jobs => jobs,
             :backups => backup_info,
             :license => license } if instance.nil?
  
    stats = instance[:stats]
  
    # This may be some CF error, set to orange and try again
    return { :colored_status => "orange", :status => "no-public-uri",
             :message => "Application #{@app_name_intalio} is not mapped to a public URI",
             :jobs => jobs,
             :backups => backup_info,
             :license => license } if stats[:uris].nil?
  
    # find the uri closest to the current one:
    intalio_uris_indexed = CreateAdmin.index_urls(stats[:uris])
    intalio_hostname = CreateAdmin.get_closest_url(nil,request.host,intalio_uris_indexed)
    uri = "http://#{intalio_hostname}/startup_status"
  
    master_test_response = get_master_test(uri, app_stats)
    master_test_response[:jobs] = jobs
    master_test_response[:backups ] = backup_info
    master_test_response[:license] = get_license(intalio_hostname) if master_test_response[:colored_status] == 'green'
    master_test_response[:license] ||= @app_status['license']
    return master_test_response
  
  end
  
  def get_backup_dates
    last_backup = t.status_panel.value.no_backup #'None'
    next_backup = t.status_panel.value.no_schedule #'Not scheduled'
    last_failure = ''
  
    begin
      setting = CreateAdmin.check_and_update_backup_settings()
      period = setting.period
      debug "Got backup period #{period}"
  
      base_dir = ENV['BACKUP_HOME']
      backups = Dir.entries(base_dir).select { |f|
        f =~ /.zip/
      }.sort {|a,b|
        File.stat("#{base_dir}/#{b}").mtime <=> File.stat("#{base_dir}/#{a}").mtime
      }

      if(backups.size > 0)
        # calculate last backup only against scheduled ones
        last_backup = File.stat("#{base_dir}/#{backups[0]}").mtime.to_i * 1000
  
        backups.select! {|f|
          f =~ /^\w+-\d+-\w+-\d+-\d+-s.zip/
        }
        last_scheduled_backup = File.stat("#{base_dir}/#{backups[0]}").mtime.to_i * 1000 if(backups.size > 0)
      end
  
      round_backup = proc { | backup_time, period |
        if(period >= 3600)
          if(period >= (3600 * 24) && CreateAdmin.is_new_backup_schedule)
            minute = Time.now().min
            (Time.now().to_i - (minute * 60) + 3600) * 1000
          else
            minute = Time.at(backup_time).min
            debug "Rounding to nearest hour. Got minute #{minute}"
            (backup_time - (minute * 60)) * 1000
          end
        else
          backup_time * 1000
        end
      }
  
      unless period.nil? || period == 0
        start_time = CreateAdmin.backup_schedule_start_time || START_UP_TIME
        backup_time = (last_scheduled_backup.to_i > 0 && last_scheduled_backup/1000 > start_time) ? last_scheduled_backup/1000 : start_time
  
        past_failures = CF.get_backup_schedule_failure()
        if past_failures > 0
          new_period = period + (period * past_failures)
          next_backup = round_backup.call(backup_time + new_period, period)
          last_failure = round_backup.call(backup_time + (new_period - period), period)
        else
          next_backup = round_backup.call(backup_time + period, period)
        end
      end
      debug "Next backup #{next_backup}"
    rescue Exception => e
      warn e
      debug e.backtrace
    end
  
    info = { :last_backup => last_backup, :next_backup => next_backup, :backup_failure => last_failure}
    debug "Backup info #{info}"
    return info
  end
  
  def get_license(intalio_hostname)
    uri = "http://#{intalio_hostname}/instance/get_license_terms"
    debug "getting license from #{uri}"
    begin
      response = uri.to_uri(:timeout => 50).get()
      @app_status['license'] = JSON.parse(response.body) if response.ok?
    rescue Exception => e
      warn "Unable to get license #{e.message}"
      return ""
    end
  end
  
  def get_master_test(uri, app_stats)
    debug "Doing a master test request on #{uri}" #with #{oauth_access_headers.inspect}
    master_test = uri.to_uri(:timeout => 50).get()

    # check master test on intalio
    master_test_code = master_test.code.to_str
  
    if master_test_code == '200'
      begin
        res = JSON.parse(master_test.body)
        status = res && res['startup'] && res['startup']['status']
        color = (status == 'finished') ? 'green' : 'orange'
      rescue Exception => e
        warn "Unable to parse startup status #{e.message}"
        color = 'orange'
      end
    elsif master_test_code == '500'
      color = 'red'
      message = "The master test returns an error. Pease contact the system administrator"
    elsif master_test_code == '404' && (app_stats.nil? || app_stats.empty?)
      # This confirms app is stopped
      color = 'red'
      message = "Application #{@app_name_intalio} is not running"
    elsif (master_test_code == '503' || master_test_code == '404')
        color = 'orange'
        message = 'starting'
    elsif master_test_code == '401'
      color = 'red'
      message = 'Authentication required'
    else
      color = 'red'
      message = "Unexpected response from the master page - #{master_test.code}"
    end
  
    return { :colored_status => color, :message => message }
  end
  
  # Query the 'secret' GET /apps/:name/update defined inside cloud_controller's apps_controller.rb
  # Returns a hash with ':state' and ':since'
  # The state is one of NONE | FAILED | SUCCEEDED | UPDATING | CANARY_FAILED
  def get_app_update_info(client, name)
    begin
      update_info = client.app_update_info(name)
      since = Time.now.to_i - update_info[:since].to_i
      since_str = uptime_string(Time.now.to_i - update_info[:since].to_i)
      update_info[:since_str] = since_str
      if update_info[:state] == "UPDATING"
        #check since how long it has been in the updating state.
        thirty_minutes_updating_timeout = (ENV['CF_UPDATING_TIMEOUT'] || 30).to_i
        if since <= thirty_minutes_updating_timeout * 60
          #still reasonable to wait and not let a new upgrade job be piled up
          #unless there is a force=yes in the parameters.
          ready_for_upgrade = false
          #puts "Not updating because there is already an update happening on the CF side."
          update_info[:message] = "Not starting a new update because there is already an update happening on the CF side for less than #{thirty_minutes_updating_timeout} minutes."
        else
          ready_for_upgrade = true
          update_info[:message] = "There is an update happening on the CF side but it has been over #{thirty_minutes_updating_timeout} minutes."
        end
      elsif update_info[:state] != "SUCCEEDED"
        #TODO: not sure where to place this important piece of info.
        update_info[:message] = "Warning: the last upgrade attempt did not succeed."
      end
      update_info[:ready_for_upgrade] = ready_for_upgrade
      update_info
    rescue => e
      error "Unable to read the update info of the app #{name}"
      error e.message
      error e.backtrace.inspect
      { :success => false, :message => "No update info for #{name}", :exception => e }.to_json
    end
  end
  
  def get_app_health(client, cli_client, name)
    begin
      app = @admin_instance.app_info(name, true, @manifest_path)
      return { :status => "not-deployed"} if app.nil?

      health = cli_client.__health(app)
      stats = client.app_stats(name)
      t=Array.new
      begin
        stats.each do |entry|
          index = entry[:instance]
          stat = entry[:stats]
          hp = "#{stat[:host]}:#{stat[:port]}"
          uptime = uptime_string(stat[:uptime])
          usage = stat[:usage]
          if usage
            cpu   = usage[:cpu]
            mem   = (usage[:mem] * 1024) # mem comes in K's
            disk  = usage[:disk]
          end
          uris = stat[:uris]
          # force the uri closest to the current one to be the first uri
          # so that the browser's javascript will display that one as the hostname of the intalio app
          # in the info panel.
#          intalio_uris_indexed = CreateAdmin.index_urls(uris)
#          intalio_hostname = CreateAdmin.get_closest_url(nil,request.host,intalio_uris_indexed)
#          ind = uris.index(intalio_hostname)
#          if ind != 0
#            uris.delete_at(ind) if ind > 0
#            uris.unshift(intalio_hostname)
#          end
  
          mem_quota = stat[:mem_quota]
          disk_quota = stat[:disk_quota]
          mem  = "#{CreateAdmin.pretty_size(mem)} (#{CreateAdmin.pretty_size(mem_quota)})"
          disk = "#{CreateAdmin.pretty_size(disk)} (#{CreateAdmin.pretty_size(disk_quota)})"
          cpu = cpu ? cpu.to_s : 'NA'
          cpu = "#{cpu}% (#{stat[:cores]})"
          if stats.size == 1
            t << {:health => health, :cpu => cpu, :mem => mem, :disk => disk, :uptime => uptime, :uris => uris}
          end
        end
      rescue => e
        error "Error retrieving stats on an application"
        error e.message
        error e.backtrace
      end
      update_info = get_app_update_info(client, name)
      if t.size == 1
        up_info = {:state => update_info[:state], :since => uptime_string(Time.now.to_i - update_info[:since])}
        t[0][:update_info] = up_info
        t[0][:jobs] = update_info[:jobs] unless update_info[:jobs].nil?
        t[0]
      elsif t.size == 0
        if update_info[:jobs].nil?
          { :health => health, :update_info => update_info }
        else
          { :health => health, :update_info => update_info, :jobs=> update_info[:jobs] }
        end
      else
        { :health => health, :update_info => update_info, :instances => t}.to_json
      end
    rescue => e
      error e.message
      error e.backtrace
      { :success => false, :message => "No stats for #{name}", :exception => e }.to_json
    end
  end
end