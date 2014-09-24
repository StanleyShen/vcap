require 'fileutils'
require 'tempfile'
require 'jobs/job'
require 'create_admin/util'
require 'create_admin/agent'

module Jobs
  class UploadFile < Job
  end
end

class ::Jobs::UploadFile
  def initialize(options)
    parse_metadata(options)
    @upload_done = false
    @received_size = 0
  end

  def run()
  end

  def process_non_cmd_data(queue)
    return if @upload_done
    
    loop do
      data = queue.pop
      if (data == ::CreateAdmin::CONNECTION_EOF)
        if @received_size != @size
          error "The upload file isn't integrity, expected size: #{@size} bytes, but received: #{@received_size} bytes"
          @tmp_file.unlink if @tmp_file
        else
          upload_finised
        end
        break
      end
  
      @tmp_file.write(data)
      @received_size = @received_size + data.bytesize
      
      if (@received_size == @size)
        upload_finised
        break
      end
    end
  end

  private

  def upload_finised
    begin
      @upload_done = true
      @tmp_file.close
      # mv current with old extension if have
      backup_path = @output_path + '.old'
      FileUtils.rm(backup_path) if File.file?(backup_path)
      FileUtils.mv(@output_path, backup_path) if File.file?(@output_path)
  
      FileUtils.cp(@tmp_file, @output_path)
    ensure
      @requester.close
    end
  end

  def parse_metadata(meta)
    @size = meta['size']
    raise 'Must provide size property for uploading.' if @size.nil?

    @output_path = CreateAdmin.get_file(meta, true)
    @tmp_file = Tempfile.new('create_admin_file_upload')
  end
end
