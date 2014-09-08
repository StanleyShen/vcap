require 'jobs/job'
require 'create_admin/util'

module Jobs
  class ListFilesJob < Job
  end
end

class ::Jobs::ListFilesJob

  def initialize(options)
    @path = CreateAdmin.get_file(options, false)
    raise "path #{@path} isn't one directory!" unless File.directory?(@path)
    @filter = options['filter']
  end

  def run
    search_path = if @filter
      File.join(@path, @filter)
    else
      File.join(@path, '*')
    end

    res = []
    files = Dir.glob(search_path).each{|f|
      res << CreateAdmin.file_metadata(f)
    }
    
    send_data(res, true)
  end
end