require 'rubygems'
require 'vmc_knife'
require 'vmc_knife/commands/knife_cmds'
require 'fileutils'

require "jobs/job"

module Jobs
  class BackupJob < Job
  end
end

class ::Jobs::BackupJob
  include VMC::KNIFE::Cli

  def initialize(options = nil)
    @options = options || {} 
    @manifest_path = @options['manifest'] || ENV['VMC_KNIFE_DEFAULT_RECIPE']
    @file_suffix = @options['suffix'].nil? ? '' : "-#{@options['suffix']}"
    @backup_home = @options['backup_home'] || "#{ENV['HOME']}/cloudfoundry/backup"
  end

  def run()
    total = 3
    at(0, total, "Preparing to backup")

    filename = Time.now.strftime("%a-%d-%b-%Y-%H%M")+"#{@file_suffix}.tar.gz"
    manifest = load_manifest(@manifest_path)

    FileUtils.mkpath(@backup_home) unless File.directory?(@backup_home)      
    @full_path_to_backup = File.join('', @backup_home, filename)

    client = vmc_client_from_manifest(manifest)
    configurer = VMC::KNIFE::RecipesConfigurationApplier.new(manifest, client, nil, nil, /pg_intalio/, {:file_names=> @full_path_to_backup, :app_name=>'intalio', :data_only=>true})

    at(1, total, "Backup started")
    configurer.export()
    
    at(2, total, "Backup created")

    completed("Backup completed!")
  rescue => e
    error "Got exception #{e.message}"
    error e.backtrace
    debug "Rolling back if applicable"
    rollback(@full_path_to_backup) unless @full_path_to_backup.nil?

    failed( {'message' => "Backup failed: #{e.message}",
             'backup' => 'failed', 'exception' => e.backtrace })
  end
  
  def rollback(full_path_to_backup)
    File.delete(full_path_to_backup) if File.exists?(full_path_to_backup)
  end
end