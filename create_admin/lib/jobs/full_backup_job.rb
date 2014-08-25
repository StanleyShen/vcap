require 'rubygems'
require 'zip/zip'
require 'vmc_knife'
require 'vmc_knife/commands/knife_cmds'

require 'jobs/job'
require 'fileutils'

#
# Job responsible for updating the hostnames for all the applications
# running on the cloudfoundry instance
#
#

module Jobs
  class FullBackupJob < Job
  end
end

class ::Jobs::FullBackupJob

  def initialize(options)
    options = options || {}

    @manifest_path = options['manifest']
    @auth_headers= options['oauth_access_headers']
    @backup_ext = options['backup_ext'] || '.zip'
    @backup_home = options['backup_home'] || "#{ENV['HOME']}/cloudfoundry/backup"
    @tmp_dir = "#{@backup_home}/tmp"

    if options['suffix'].nil?
      @file_suffix = ''
    else
      @file_suffix = "-#{options['suffix']}"
    end
  end

  def run
    begin
      manifest = @admin_instance.manifest(false, @manifest_path)
      client = @admin_instance.vmc_client(false, @manifest_path)

      at(0, 1, "Preparing to backup")
      filename = "backup#{@backup_ext}"      

      backup_ext = '.tar.gz'
      FileUtils.mkpath(@tmp_dir) unless File.directory?(@tmp_dir)

      data_services = manifest['recipes'][0]['data_services']
      total = (data_services.size * 2) + 1
      @num = 0
      backups = {}

      data_services.each { | name, attributes |
        dir = attributes['director']
        next if dir.nil? 

        if dir['backup'] == true || dir['backup'] == 'true'
          full_path_to_backup =   "#{@tmp_dir}/#{name}#{backup_ext}"

          configurer = VMC::KNIFE::RecipesConfigurationApplier.new(manifest, client, nil, nil, /^#{name}$/, {:file_names=> full_path_to_backup, :app_name=>'intalio', :data_only=>true})
          at(inc_step, total, "#{name} backup started")
          configurer.export()

          at(inc_step, total, "#{name} backup created")
          backups[name] = full_path_to_backup
        end
      }

      raise "No data services found for backup" unless backups.size > 0

      encryption_key_name = 'io_encryption_key'
      encryption_key_path = "/home/ubuntu/cloudfoundry/#{encryption_key_name}"
      archive = "#{@backup_home}/#{filename}"

      Zip::ZipFile.open(archive, 'w') do |zipfile|
        backups.each { |name, path|
          zipfile.add("#{name}#{backup_ext}", path)
        }
        zipfile.add(encryption_key_name, encryption_key_path) if File.exists?(encryption_key_path)
      end
      
      # backup for cdn
      intalio_dir = '/home/ubuntu/intalio/'
      cdn_dir = 'cdn'

      if File.directory?(File.join(intalio_dir, cdn_dir))
        cdn_zip_path = File.join(Dir.tmpdir, "cdn-#{Time.now.strftime("%d-%b-%Y-%H%M%s")}.zip")
    
        # create zip file for all cdn files
        Zip::ZipFile.open(cdn_zip_path,  Zip::ZipFile::CREATE) do |zipfile|
          Dir[File.join(intalio_dir, 'cdn', '**', '**')].each do |file|
            zipfile.add(file.sub(intalio_dir, ''), file)
          end
        end
    
        Zip::ZipFile.open(archive, 'w') do |zipfile|
          zipfile.add("cdn.zip", cdn_zip_path)
        end
        FileUtils.rm(cdn_zip_path)
      end

      ts_filename = File.stat(archive).mtime.strftime("%a-%d-%b-%Y-%H%M")+"#{@file_suffix}#{@backup_ext}"
      File.rename(archive, "#{@backup_home}/#{ts_filename}")

      call_extensible_backup(client, archive)

      completed
    rescue => e
      error "Got exception #{e.message}"
      error e.backtrace
      debug "Rolling back if applicable"
      rollback(archive)
      failed( {'message' => "Backup failed: #{e.message}",
               'backup' => 'failed', 'exception' => e.backtrace })
    ensure
      FileUtils.remove_dir(@tmp_dir, true)
    end

  end

  private
  def call_extensible_backup(client, filepath)
    app_name_intalio = ENV['cf_app_name_intalio']||'intalio'
    debug "Preparing to call extensible backup"

    app_stats = client.app_stats(app_name_intalio)
    instance = app_stats.first

    unless(instance.nil? || @auth_headers.nil?)
      stats = instance[:stats]
      intalio_hostname = stats[:uris][0]
      uri = "http://#{intalio_hostname}/pipes/wss/backup"
      debug "Calling extensible backup at #{uri} with #{@auth_headers}"

      xml_req = <<-XML
      <?xml version="1.0" encoding="utf-8"?>
      <backup><filename><![CDATA[#{filepath}]]></filename></backup>
      XML

      begin
        response = uri.to_uri(:timeout => 50).post(xml_req.strip!, @auth_headers)
        if response.code.to_i == 200
          debug "Extensible backup successfully called"
        else
          warn "Failed to call extensible backup => #{response.code} : #{response.message}"
        end
      rescue => e
        warn "Failed to call extensible backup => #{e.message}"
      end
    else
      warn "Intalio may not be up. Not calling extensible backup" if instance.nil?
      warn "In scheduling backup mode. No credentials available to call extensible backup" if @auth_headers.nil?
    end

  end

  def rollback(archive)
    File.delete(archive) if !archive.nil? && File.exists?(archive)
  end

  def inc_step
    @num += 1
  end

end
