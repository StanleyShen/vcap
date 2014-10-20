require 'rubygems'

require 'uri'

require "jobs/job"
require "create_admin/util"
require "create_admin/http_proxy"
require "vmc/vmcapphelpers"
require 'jobs/scheduled_backup_job'
require "route53/dns_gateway_client"
require "create_admin/license_manager"

module Jobs
  class StatusJob < Job; end
end

class ::Jobs::StatusJob
  include HttpProxy
  include CreateAdmin::LicenseManager

  def run
    init_variables

    hostname = intalio_host_name
    
    apps = @manifest['recipes'].first['applications'].values.collect{|v| v['name']}

    completed({
      'ip_address' => published_ip,
      'hostname' => hostname,
      'license' => get_license_terms(hostname),
      'backup_info' => get_backup_info,
      'instances' =>  app_instances(apps),
      'current_version' => CreateAdmin.get_build_number
    })
  end
  
  private
  def init_variables
    @manifest = @admin_instance.manifest(false)
    @client = @admin_instance.vmc_client(false)
  end
  
  # the host name is the intalio app uris
  def host_name
    intalio_app = @admin_instance.app_info('intalio', false)
    intalio_app[:uris].first
  end
  
  def published_ip
    published_ip = @manifest['dns_provider']['dns_published_ip']
    (published_ip.nil? || published_ip.empty?) ? CreateAdmin.get_local_ipv4 : published_ip
  end
  
  def get_backup_info
    last_backup, last_scheduled_backup = nil, 0

    base_dir = CreateAdmin.instance.backup_home
    if File.directory?(base_dir)
      backups = Dir.entries(base_dir).select { |f|
        f =~ /.zip/
      }.sort {|a,b|
        File.stat("#{base_dir}/#{b}").mtime <=> File.stat("#{base_dir}/#{a}").mtime
      } 

      if(backups.size > 0)
        # calculate last backup only against scheduled ones
        last_backup = File.stat("#{base_dir}/#{backups[0]}").mtime.to_i * 1000
        scheduled_backups = backups.select{|f| f =~ /^\w+-\d+-\w+-\d+-\d+-s.zip/ }
        last_scheduled_backup = File.stat("#{base_dir}/#{scheduled_backups[0]}").mtime.to_i * 1000 if (scheduled_backups.size > 0)
      end
    end
    
    # find the next backup
    backup_instance = ScheduledBackup.instance
    round_backup = proc { | backup_time, period |
      if(period >= 3600)
        if(period >= (3600 * 24) && !backup_instance.backup_job_started)
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

    last_failure, next_backup = nil, nil
     
    backup_settings = backup_instance.get_backup_setting    
    unless backup_settings.nil? || backup_settings.period == 0
      start_time = backup_settings.schedule_start_time
      backup_time = (last_scheduled_backup.to_i > 0 && last_scheduled_backup/1000 > start_time) ? last_scheduled_backup/1000 : start_time

      past_failures = backup_instance.backup_failures
      if past_failures > 0
        new_period = period + (period * past_failures)
        next_backup = round_backup.call(backup_time + new_period, period)
        last_failure = round_backup.call(backup_time + (new_period - period), period)
      else
        next_backup = round_backup.call(backup_time + period, period)
      end
    end
    
    return {'last_backup' => last_backup, 'next_backup' => next_backup, 'backup_failure' => last_failure}
  end
end