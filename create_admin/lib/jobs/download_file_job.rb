require 'jobs/job'
require 'create_admin/util'

module Jobs
  class DownloadFile < Job
  end
end

class ::Jobs::DownloadFile
  def initialize(options)
    @path = CreateAdmin.get_file(options, true)
    raise "path #{@path} isn't one file!" unless File.file?(@path)
    raise "You aren't allowed to read file #{@path}" unless File.readable?(@path)
  end

  def run
    meta_data = CreateAdmin.file_metadata(@path)
    send_data(meta_data)

    streamer = EventMachine::FileStreamer.new(@requester, @path)
    streamer.callback{
      # file was sent successfully
      debug "File is sent successfully with path #{@path}."

      update_execution_result({'_status' => CreateAdmin::JOB_STATES['success']})

      @requester.close
    }

  end
end