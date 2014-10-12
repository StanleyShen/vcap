Dir[File.dirname(__FILE__) + '/../jobs/*.rb'].each do |file|
  require file
end

module CreateAdmin
  JOBS = {
    'upgrade' => Jobs::UpgradeJob,
    'dns_update' => Jobs::DNSUpdateJob,
    'update_license' => Jobs::UpdateLicenseJob,
    'license_status' => Jobs::LicenseStatusJob,
    'ip_map' => Jobs::IPMapJob,
    'full_backup' => Jobs::FullBackupJob,
    'full_restore' => Jobs::FullRestoreJob,
    'status' => Jobs::StatusJob,
    'download' => Jobs::DownloadFile,
    'upload' => Jobs::UploadFile,
    'list_files' => Jobs::ListFilesJob,
    'delete_file' => Jobs::DeleteFileJob,
    'stop_apps' => Jobs::StopAppJob,
    'start_apps' => Jobs::StartAppJob,
    'app_file' => Jobs::AppFileJob,
    'generate_instance_id' => Jobs::GenJobInstanceId,
    'job_status' => Jobs::JobStatus,
    'app_info' => Jobs::AppInfo,
    'admin_app_env' => Jobs::AdminApplicationEnv,
    'app_instances' => Jobs::AppInstances,
    'change_app_instance' => Jobs::ChangeAppInstance,
    'apps_version' => Jobs::AppsVersion
  }

  EXCLUSIVE_JOBS = {
    'upgrade' => ['upgrade', 'dns_update', 'full_backup', 'full_restore', 'stop_apps', 'start_apps', 'app_file'],
    'dns_update' => ['upgrade', 'stop_apps', 'start_apps', 'full_backup', 'full_restore'],
    'update_license' => ['upgrade', 'stop_apps', 'start_apps', 'full_backup', 'full_restore'],
    'full_backup' => ['upgrade', 'dns_update', 'update_license', 'full_backup', 'full_restore', 'stop_apps', 'start_apps'],
    'full_restore' => ['upgrade', 'dns_update', 'update_license', 'full_backup', 'full_restore', 'stop_apps', 'start_apps'],
    'stop_apps' => ['upgrade', 'dns_update', 'update_license', 'full_backup', 'full_restore', 'stop_apps', 'start_apps'],
    'start_apps' => ['upgrade', 'dns_update', 'update_license', 'full_backup', 'full_restore', 'stop_apps', 'start_apps']
  }

  # the client only needs to consider: none, working, failed and success.
  JOB_STATES = {
    'none' => 'none', # indicate undefined state
    'working' => 'working',
    'completed' => 'completed', # this state is used internally
    'failed' => 'failed',
    'success' => 'success'
  }

  class ::CreateAdmin::ConnetionClosedFlag
    def bytesize
      0
    end

    def size
      0
    end

    def to_s
      ''
    end

    def to_str
      ''
    end
  end
  

  # constand to indicate the connection is closed
  CONNECTION_EOF = ::CreateAdmin::ConnetionClosedFlag.new
end