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

  def process_non_cmd_data(data)
    return if @upload_done
    if (data == ::CreateAdmin::CONNECTION_EOF)
      if @received_size != @size
        error "The upload file isn't integrity, expected size: #{@size} bytes, but received: #{@received_size} bytes"
        @tmp_file.unlink if @tmp_file
      else
        upload_finised
      end
      return
    end

    @tmp_file.write(data)
    @received_size = @received_size + data.bytesize
    upload_finised if (@received_size == @size)
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
  
      FileUtils.mv(@tmp_file, @output_path)
    ensure
      @requester.close
    end
  end

  def parse_metadata(meta)
    @size = meta['size']
    raise 'Must provide size property for uploading.' if @size.nil?

    type = meta['type']
    path = meta['path']
    name = meta['name']

    if (path.nil?)
      raise 'name and type must specified.' if name.nil? && type.nil?
      case type
      when 'backup'
        path = File.join("#{ENV['HOME']}/cloudfoundry/backup", name)
      when 'cdn'
        path = File.join("#{ENV['HOME']}/intalio/cdn/resources", name)
      end
    else
      path = CreateAdmin.normalize_file_path(path)
    end

    @tmp_file = Tempfile.new('create_admin_file_upload')
    @output_path = path
  end
end
