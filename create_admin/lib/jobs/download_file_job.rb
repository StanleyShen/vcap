require 'rubygems'

require 'jobs/job'
require 'create_admin/util'

module Jobs
  class DownloadFile < Job
  end
end

class ::Jobs::DownloadFile
  def initialize(options)
    raise "path is required!" if options['path'].nil?

    @path = CreateAdmin.normalize_file_path(options['path'])
    raise "path #{path} isn't one file!" unless File.file?(@path)
    raise "You aren't allowed to read file #{@path}" unless File.readable?(@path)
  end

  def run
    meta_data = file_metadata(@path)
    send_data("#{meta_data.to_json}\r\n")

    streamer = EventMachine::FileStreamer.new(@requester, @path)
    streamer.callback{
      # file was sent successfully
      @requester.close
    }
  end
  
  private
  def file_metadata(file_path)
    name = File.basename(file_path)
    size = File.size(file_path)
    last_modified = File.mtime(file_path).to_i
    {'name' => name, 'size' => size, 'last_modified' => last_modified}
  end
end