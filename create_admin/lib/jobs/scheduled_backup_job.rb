require 'rubygems'
require 'clockwork'
require 'vmc_knife'
require 'vmc_knife/commands/knife_cmds'

require "create_admin/log"
require "create_admin/util"
require 'vmc/vmchelpers'
require 'dataservice/postgres_ds'

class ScheduledBackup
  include DataService::PostgresSvc
  include ::CreateAdmin::Log
  include VMC::KNIFE::Cli

  @@id_mapping = { 's' => 'io_backup_lifespan'}

  def initialize(options = {})
    @manifest_path = options['manifest'] || ENV['VMC_KNIFE_DEFAULT_RECIPE']
    @backup_home = options['backup_home'] || "#{ENV['HOME']}/cloudfoundry/backup"
  end
    
  def create(settings)
    # clear all clockwork events
    clear!
    tg = []
    settings.each { |setting|
      period = setting.period
      if(period < 3600)
        th = Thread.new do
          debug "Waiting for #{period} before scheduling backup"
          sleep(period)
          schedule_backup(setting)
        end
        tg << th
      else
        schedule_backup(setting)
      end
    }

    every(1.minute, 'Check backup settings') {
      # need to fork a new thread to prevent the checker from
      # holding on to the @@backup_thread in CF
      Thread.new do
        CreateAdmin.check_and_update_backup_settings()
      end
    }

    tg << start_clockwork_thread()
    return tg
  end

  private

  def schedule_backup(setting)
    period = setting.period
    at = setting.at
    options = {}
    options[:at] = at unless setting.at.nil?
    debug "Creating new scheduled backup for every #{setting.label} at #{at}"
    #every(10.seconds, 'backup intalio') {
    every(period.send(:seconds), "Backup intalio", options) {
      debug "Running backup for every #{setting.label} at #{at}"
      begin
        start_backup_job(setting.identifier)
      rescue Exception => e
        error "Caught exception #{e.message}"
        error e.backtrace
      end
    }
  end

  def start_backup_job(identifier)
    CreateAdmin.backup_schedule_started
    housekeep_backups(identifier)

    warn "Max storage exceeded!!! Please increase max storage setting or delete old backup archives." if max_storage_exceeded?(identifier)

    manifest = load_manifest(@manifest_path)
    client = vmc_client_from_manifest(manifest, true)

    client_json = client_to_json(client)
    debug "Vmc client #{client_json}"
    job_params = { 'client_json' => client_json, 'suffix' => identifier }

    debug "Preparing to create backup"
    FullBackupJob.create(job_params)
  end

  def start_clockwork_thread
    retry_count = 3
    th = Thread.new do
      begin
        # run clockwork
        run
      rescue
        error "Clock has crashed? Restarting"
        retry_count -= 1
        retry if retry_count > 0
      end
    end

    return th
  end

  def housekeep_backups(identifier)
    debug "Housekeeping backups for #{identifier}"

    backups = get_back_ups(identifier)
    debug "Found #{backups.size} backups for #{identifier}"
    # do cleanup
    delete_expired_backups(backups, identifier)

    while max_storage_exceeded?(identifier)
      delete_oldest_backup(backups, identifier)
    end

  end

  def get_back_ups(identifier)
    backups = []
    Dir.foreach(@backup_home) { |filename|
      backups << filename if filename =~ /^\w+-\d+-\w+-\d+-\d+-#{identifier}.zip/
    }
    backups
  end

  def delete_oldest_backup(backups, identifier)
    backups = Dir.glob("#{@backup_home}/*-#{identifier}.zip").sort_by{ |f| File.mtime(f) }
    if backups.size > 0
      oldest = backups[0]
      File.delete(oldest)
      debug "Deleted backup #{oldest}"
    else
      debug "No old scheduled archives found that can be deleted"
    end
  end

  def delete_expired_backups(backups, identifier)
    lifespan = get_setting("extract(epoch from #{@@id_mapping[identifier]})", 0)
    backups.each { |filename|
      fullapth = "#{@backup_home}/#{filename}"
      time = File.stat(fullapth).mtime.to_i
      now = Time.now.to_i
      lived = now - time
      if lived > lifespan
        File.delete(fullapth)
        debug "Deleted #{filename}"
      end
    }
  end

  def max_storage_exceeded?(identifier)
    total = 0
    Dir.foreach(@backup_home) { |filename|
      total += File.size("#{ENV['BACKUP_HOME']}/#{filename}") if filename =~ /-#{identifier}.zip$/
    }
    # read max from db
    max = get_setting('io_backup_storage_space_quantity[1]', -1)
    debug "Current total backup space used #{(total/1024)/1024} Mb. Max allowed #{max} Mb"
    total > (max * 1024 * 1024)
  end

  def get_setting(name, default)
    begin
      conn = get_postgres_db()
      result = conn.exec("select #{name} from io_system_setting where io_active='t';")
      result.getvalue(0, 0).to_i || default
    rescue Exception => e
      warn e
      debug e.backtrace
      debug "Using default value of #{default} for #{name}"
      return default
    ensure
      conn.close() unless conn.nil?
    end
  end

end

class BackupSetting

  attr_reader :period
  attr_reader :label
  attr_reader :at
  attr_reader :identifier
  attr_reader :storage

  def initialize(period, label, storage)
    @period = period
    @label = label
    @at = '**:00' if period >= 3600
    @storage = storage
    @identifier = 's'
  end
end

