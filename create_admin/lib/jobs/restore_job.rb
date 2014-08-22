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

  def initialize(options)
    @backup = options['backup']
    raise "No backup provided" if (@backup.nil? || @backup.empty?)

    @manifest_path = options['manifest']
    @backup_home = options['backup_home'] || "#{ENV['HOME']}/cloudfoundry/backup"
  end
  
  def run
    begin
      total = 2

      at(0, total, "Preparing to restore")
      manifest = @admin_instance.manifest(false, @manifest_path)
      client = @admin_instance.vmc_client(false, @manifest_path)

      filename = "#{@backup_home}/#{@backup}"
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
