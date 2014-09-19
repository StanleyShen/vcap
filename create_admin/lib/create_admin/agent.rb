require 'rubygems'
require 'json/pure'
require 'eventmachine'

require "create_admin/log"
require "create_admin/admin_instance"
require "common/pid_file"
require 'em/protocols/object_protocol'

Dir[File.dirname(__FILE__) + '/../jobs/*.rb'].each do |file| 
  require file
end

module CreateAdmin  
  JOBS = {
    'upgrade' => 'Jobs::UpgradeJob',
    'backup' => 'Jobs::BackupJob',
    'dns_update' => 'Jobs::DNSUpdateJob',
    'update_license' => 'Jobs::UpdateLicenseJob',
    'license_status' => 'Jobs::LicenseStatusJob',
    'ip_map' => 'Jobs::IPMapJob',
    'full_backup' => 'Jobs::FullBackupJob',
    'restore' => 'Jobs::RestoreJob',
    'full_restore' => 'Jobs::FullRestoreJob',
    'status' => 'Jobs::StatusJob',
    'download' => 'Jobs::DownloadFile',
    'upload' => 'Jobs::UploadFile',
    'list_files' => 'Jobs::ListFilesJob',
    'delete_file' => 'Jobs::DeleteFileJob',
    'stop_app' => 'Jobs::StopAppJob',
    'start_app' => 'Jobs::StartAppJob',
    'app_file' => 'Jobs::AppFileJob'
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

  def self.instance
    ::CreateAdmin::AdminInstance.instance
  end

  class Agent
  end
  class ConnectionHandler < EM::Connection
  end
end

class ::CreateAdmin::Agent
  include ::CreateAdmin::Log

  def initialize(options)
    @options = options

    begin
      pid_file = PidFile.new(@options['pid'])
      pid_file.unlink_at_exit
    rescue => e
      error "ERROR: Can't create create_admin pid file #{@options['pid']}"
      exit 1
    end

    # start schedule backup job
    ScheduledBackup.instance.bootstrap_schedule

    start_server()
  end

  def start_server()
    port = @options['port'] || 59080
    EM.run do    
      EM.start_server('0.0.0.0', port, ::CreateAdmin::ConnectionHandler){|dispather|
        dispather.options = @options
      }
    end
  end
end

class ::CreateAdmin::ConnectionHandler
  include ::CreateAdmin::Log
  include ::EventMachine::Protocols::ObjectProtocol

  attr_accessor :options
  attr_reader :closed

  # max length for the command string(it must be enough)
  MAX_COMMAND_SIZE = 16 * 1024
  
  def initialize
    @closed = false
    @marshal = true
  end

  # if the command starts with underscore, the command string won't be deserializer, it is for debug purpose
  # for example: _delete_file:{"path": "/path/of/file"}
  def receive_data(data)
    if @job.nil?
      @marshal = false if (data.start_with?('_'))
      
      if @marshal
        (@buf ||= '') << data
        while (@buf.size >= 4 && @job.nil?)
          size = @buf.unpack('N').first
          if @buf.size >= (4 + size)
            @buf.slice!(0,4)
            @job = parse_command(serializer.load(@buf.slice!(0,size)), @buf)
            @buf = nil
          end
          break
        end
      else
        command = data[1..-1]
        @job = parse_unserialize_command(command)
      end
    elsif @job.respond_to?(:process_non_cmd_data)
      @job.process_non_cmd_data(data)
    end
  rescue => e
    error("Failed to execute command #{@debug_str}")
    error(e)
    close("Failed to execute command #{@debug_str}, message: #{e.message}")
  end

  def unbind
    EM::next_tick {
      begin
        @job.process_non_cmd_data(::CreateAdmin::CONNECTION_EOF) if @job.respond_to?(:process_non_cmd_data)
      rescue => e
        error("Encount exception when sent the connecton EOF flag.")
        error(e)
      end
    }        
  end

  def message(data)
    puts "[send data] data is .... #{data}"
    if @marshal
      send_object(data)
    else
      send_data(data)
    end
  end

  def close(data = nil)
    return if @closed
    @closed = true

    EM.next_tick do
      message(data) if data
      close_connection_after_writing
    end
  end

  private
  
  def parse_unserialize_command(command)
    vals = command.split("\r\n", 2)
    parse_command(vals[0], vals[1])
  end

  def parse_command(command, more_data)
    job_type, paras = command.split(':', 2)

    @debug_str = "#{job_type}:#{paras}"     
    job = find_job(job_type, paras)

    raise "Failed to parse the command: #{@debug_str}" if job.nil?

    info("Command is  >>>  #{@debug_str}")

    job.requester = self
    job.admin_instance = CreateAdmin.instance
    job.run()
    
    # should process the more data? 
    job.process_non_cmd_data(more_data) if more_data && !more_data.empty? && job.respond_to?(:process_non_cmd_data)
    job
  end
  
  def find_job(job_type, paras)
    job_cf = CreateAdmin::JOBS[job_type]
info("job_type is  >>>  #{job_type}, and found the job...#{job_cf}")
    return if job_cf.nil?

    klass = job_cf.split('::').inject(Object) {|o,c| o.const_get c}
    parsed_paras = if paras.nil? || paras.empty?
      nil
    else
      begin
        JSON.parse(paras)
      rescue => e
        error("Failed to parse the paras to json: #{paras}.")
        error(e)
      end
    end

    klass.new(parsed_paras)
  end

end