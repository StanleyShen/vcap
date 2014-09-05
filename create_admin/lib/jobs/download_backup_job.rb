require 'rubygems'

require 'jobs/job'

module Jobs
  class DownloadBackup < Job
  end
end

class ::Jobs::DownloadBackup
  def initialize(options)
    @backup_home = options['backup_home'] || "#{ENV['HOME']}/cloudfoundry/backup"
    @filename = options['filename']
  end
  
  def run
    file_path = File.join(@backup_home, @filename)
    if File.exists?(file_path)
      send_file(file_path)
    else
      failed({'success' => false, 'message' => 'No such file'})
    end
  end
  
  def send_file(file_path)
    
  end
end