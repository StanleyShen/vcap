require 'jobs/job'
require 'create_admin/util'

require 'fileutils'

module Jobs
  class ListFilesJob < Job
  end
end

class ::Jobs::ListFilesJob

  def initialize(options)
    @path = CreateAdmin.get_file(options, false)
    @force_create = options['force_create']

    if !File.directory?(@path) && @force_create
      FileUtils.mkdir_p(@path)
    else
      raise "path #{@path} isn't one directory!" unless File.directory?(@path)  
    end

    @filter = options['filter']
  end

  def run
    search_path = if @filter
      File.join(@path, @filter)
    else
      File.join(@path, '*')
    end

    files = []
    Dir.glob(search_path).each{|f|
      files << CreateAdmin.file_metadata(f)
    }
    
    completed({'files' => files})
  end
end