require 'rubygems'
require 'zip/zip'
require 'vmc_knife'
require 'vmc_knife/commands/knife_cmds'

require 'fileutils'

module Jobs
  class FullRestoreJob < Job; end
end
class ::Jobs::FullRestoreJob
  def self.job_name
    'Restore'
  end
  
  def initialize(options)
    @backup = options['name']
    raise "No backup provided" if (@backup.nil? || @backup.empty?)

    @backup_home = options['backup_home'] || "#{ENV['HOME']}/cloudfoundry/backup"
    @tmp_dir = "#{@backup_home}/tmp"
    @current_tmp_dir = "#{@backup_home}/current"
    @vmc_knife_data_dir = "#{ENV['HOME']}/vmc_knife_downloads"
  end

  def run
    verify_backup_version{
      perform_restore
    }
  end

  private

  def inc_step
    @num += 1
  end

  def remove_vmc_knife_data_dir
    FileUtils.remove_dir(@vmc_knife_data_dir, true) if File.directory?(@vmc_knife_data_dir)
  end

  def verify_backup_version
    backup_ver = nil
    match_data = @backup.match(/^\w+-\d+-\w+-\d+-\d+-(\d+\.\d+\.\d+)(-s)*.*$/)
    if match_data && match_data[1]
      backup_ver = match_data[1]
    end
    
    if (backup_ver.nil?)
      info("no version specified from backup: #{@backup}")
      return yield
    end
    
    cur_ver = CreateAdmin.get_build_number
    if cur_ver.nil?
      warn "can't current build version number."
      return yield
    end

    backup_ver_nums = backup_ver.split('.')
    cur_ver_nums = cur_ver.split('.')
    if backup_ver_nums[0] == cur_ver_nums[0] && backup_ver_nums[1] == cur_ver_nums[1]
      return yield
    end
    failed({'_code' => 'INCOMPATIBLE_VERSION', 'current_version' => cur_ver, 'backup_version' => backup_ver})
  end
  
  def perform_restore
    begin
      at(0, 1, "Preparing to restore")
      remove_vmc_knife_data_dir()

      manifest = @admin_instance.manifest(false)

      unless File.directory?(@current_tmp_dir)
        FileUtils.mkpath(@current_tmp_dir)
        FileUtils.mkpath(@tmp_dir) unless File.directory?(@tmp_dir)

        data_services = manifest['recipes'][0]['data_services']

        @num = 0
        total = (data_services.size * 2)+1
        backup_ext = '.tar.gz'
        client = @admin_instance.vmc_client(false)

        data_services.each { | name, attributes |
          dir = attributes['director']
          next if dir.nil? 

          if dir['backup'] == true || dir['backup'] == 'true'
            if attributes['vendor'] == 'postgresql'
              total = total + 2
              debug "Backing up latest #{name}"

              full_path_to_backup =   "#{@current_tmp_dir}/#{name}#{backup_ext}"
              configurer = VMC::KNIFE::RecipesConfigurationApplier.new(manifest, client, nil, nil, /^#{name}$/, {:file_names=> full_path_to_backup, :app_name=>'intalio', :data_only=>true})
              at(inc_step, total, "#{name} backup started")

              configurer.export()
              at(inc_step, total, "#{name} backup created")
            end
          end
        }

        archive = "#{@backup_home}/#{@backup}"
        debug "restoring backup up with #{archive}"

        backup_ext = '.tar.gz'
        backups = {}
        encryption_key_name = 'io_encryption_key'
        encryption_key_path = "/home/ubuntu/cloudfoundry/#{encryption_key_name}"

        intalio_dir = '/home/ubuntu/intalio/'
        cdn_dir = 'cdn'
        cdn_backup_dir = 'cdn.old'
        Zip::ZipFile.open(archive) do |zipfile|
          zipfile.each { |f|
            fname = f.name
            fullpath = "#{@tmp_dir}/#{fname}"
            zipfile.extract("#{fname}", fullpath)

            if (fname.start_with?('cdn.'))
              # backup original cdn files
              cdn_full_path = File.join(intalio_dir, cdn_dir)
              cdn_backup_path = File.join(intalio_dir, cdn_backup_dir)
              if File.directory?(cdn_full_path)
                FileUtils.rm_rf(cdn_backup_path)
                FileUtils.mv(cdn_full_path, cdn_backup_path)
              end

              Zip::ZipFile.open(fullpath) { |cdn_z_file|
                 cdn_z_file.each{|extrat_f|
                    t_path = File.join(intalio_dir, extrat_f.name)
                    FileUtils.mkdir_p(File.dirname(t_path))
                    cdn_z_file.extract(extrat_f, t_path) unless File.exist?(t_path)
                 }
              }
            elsif(fname.end_with?(backup_ext))
              name = fname.gsub(backup_ext, '')
              backups[name] = fullpath
            elsif(fname == encryption_key_name)
              FileUtils.cp(fullpath, encryption_key_path)  
            end
          }
        end

        raise "No backup archives found" unless backups.size > 0

        backups.each { |name, full_path_to_backup|
          if name =~ /^pg_intalio*/
            debug "Dropping tables for #{name}"
            drop_sql_file = "#{@tmp_dir}/#{name}.sql"
            cmd = "SELECT 'DROP TABLE ' || n.nspname || '.' || c.relname || ' CASCADE;' FROM pg_catalog.pg_class AS c LEFT JOIN pg_catalog.pg_namespace AS n ON n.oid = c.relnamespace WHERE relkind = 'r' AND n.nspname NOT IN ('pg_catalog', 'pg_toast') AND pg_catalog.pg_table_is_visible(c.oid) \\o #{drop_sql_file}"
            cmd_file = "#{@tmp_dir}/#{name}_command.sql"
            File.open(cmd_file, 'w') {|f| f.write(cmd) }
            # generate the drop sql file
            configurer = VMC::KNIFE::RecipesConfigurationApplier.new(manifest, client, nil, nil, /^#{name}$/, {:data_only => true, :file_name => cmd_file})
            configurer.shell()
            # now perform the drop
            configurer = VMC::KNIFE::RecipesConfigurationApplier.new(manifest, client, nil, nil, /^#{name}$/, {:data_only => true, :file_name => drop_sql_file})
            configurer.shell()
          end

          debug "Restoring #{name} backup from #{full_path_to_backup}"
          configurer = VMC::KNIFE::RecipesConfigurationApplier.new(manifest, client, nil, nil, /^#{name}$/, {:file_names=>full_path_to_backup, :app_name=>'intalio', :data_only=>true})
          at(inc_step, total, "#{name} restore in progress")

          configurer.import()
          at(inc_step, total, "#{name} restore completed.")

        }

        # remove current tmp dir if restore succeeds
        FileUtils.remove_dir(@current_tmp_dir, true)
        completed()
      else
        failed( {'message' => "The previous restore seems to have failed.
                              Database may be in a incosistent state.
                              Please perform restore manually.",
                'restore' => 'failed'})
      end
    rescue => e
      error "Got exception #{e.message}"
      error e
      failed( {'message' => "Restore failed: #{e.message}",
        'restore' => 'failed'})
    ensure
      FileUtils.remove_dir(@tmp_dir, true)
      # Also remove the data dir created by vmc_knife
      remove_vmc_knife_data_dir()
    end
  end
end
