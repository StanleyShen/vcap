require 'jobs/job'
require 'create_admin/util'

module Jobs
  class DeleteFileJob < Job
  end
end

class ::Jobs::DeleteFileJob
  def initialize(options)
    @file = CreateAdmin.get_file(options, true)
  end
  
  def run
    return failed("The file #{@file} doesn't exist.") unless File.exist?(@file)
    return failed("File #{@file} isn't one file!") unless File.file?(@file)
    
    File.delete(@file)
    completed("File #{@file} is deleted successfully.")
  end

end