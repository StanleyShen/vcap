require 'rubygems'

require 'vmc_knife'
require 'vmc_knife/commands/knife_cmds'
require 'fileutils'

#
# Job responsible for updating the hostnames for all the applications
# running on the cloudfoundry instance
#
#
module Jobs
  class RestoreJob < Job
  end
end

class ::Jobs::RestoreJob
  include VMC::KNIFE::Cli

  def initialize(options)
    @backup = options['backup']
    raise "No backup provided" if (@backup.nil? || @backup.empty?)

    @manifest_path = options['manifest'] || ENV['VMC_KNIFE_DEFAULT_RECIPE']
    @backup_home = options['backup_home'] || "#{ENV['HOME']}/cloudfoundry/backup"
  end
  
  def run
    begin
      total = 2

      at(0, total, "Preparing to restore")
      manifest = load_manifest(@manifest_path)
      filename = "#{@backup_home}/#{@backup}"
      client = vmc_client_from_manifest(manifest)

      debug "restoring backup up with #{filename}"
      configurer = VMC::KNIFE::RecipesConfigurationApplier.new(manifest, client, nil, nil, /pg_intalio/, {:file_names=>filename, :app_name=>'intalio', :data_only=>true})

      at(1, total, "Restore in progress")
      configurer.import()
      completed("Restore completed!")
    rescue => e
      error "Got exception #{e.message}"
      failed( {'message' => "Restore failed: #{e.message}",
               'restore' => 'failed', 'exception' => e.backtrace })
    end
  end
end
