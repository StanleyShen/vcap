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
#    send_data("#{meta_data.to_json}\r\n")
    send_data(meta_data)

    streamer = EventMachine::FileStreamer.new(@requester, @path)
    streamer.callback{
      # file was sent successfully
      @requester.close
    }
  end
end