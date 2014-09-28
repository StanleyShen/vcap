require 'rubygems'
require 'json/pure'
require 'eventmachine'

require 'em/protocols/object_protocol'

require 'create_admin/constants'
require "create_admin/log"
require "common/pid_file"
require "create_admin/admin_instance"

module CreateAdmin
  def self.instance
    ::CreateAdmin::AdminInstance.instance
  end

  class Agent; end
  class ConnectionHandler < EM::Connection; end
  class JobFailedPassError < StandardError; end
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
    @queue_data = nil
    @queue_processed = false
  end

  # if the command starts with underscore, the command string won't be deserializer, it is for debug purpose
  # for example: _delete_file:{"path": "/path/of/file"}
  def receive_data(data)
    begin
      if @job.nil?
        @marshal = false if (data.start_with?('_'))

        if @marshal
          (@buf ||= '') << data
          while (@buf.size >= 4 && @job.nil?)
            size = @buf.unpack('N').first
            if @buf.size >= (4 + size)
              @buf.slice!(0,4)
              run_command(serializer.load(@buf.slice!(0,size)), @buf)
              @buf = nil
            end
            break
          end
        else
          command = data[1..-1]
          run_unserialize_command(command)
        end
      else
        process_queue_data(data)
      end
    rescue CreateAdmin::JobFailedPassError => e
      error(e.message)
      failed(e.message)
    rescue => e
      error("Failed to execute command #{@debug_str}")
      error(e)
      failed("Failed to execute command #{@debug_str}, message: #{e.message}")
    end
  end

  def unbind
    begin
      process_queue_data(CreateAdmin::CONNECTION_EOF)
    rescue => e
      error("Encount exception when sent the connecton EOF flag.")
      error(e)
    end
    if @job && @instance_id
      CreateAdmin.instance.complete_instance(@job_type, @instance_id)
    end
  end

  def message(data)
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
  
  def failed(message)
    status = {'_status' => CreateAdmin::JOB_STATES['failed'], 'message' => message}
    if (@instance_id)
      CreateAdmin.instance.update_instance_execution_result(@instance_id, status)
    end    
    close(status)
  end
  
  def process_queue_data(data, run_in_defer = true)
    return unless @job.respond_to?(:process_non_cmd_data)
    @queue_data = @queue_data || Queue.new
    @queue_data.push(data) if data

    return if @queue_processed
    @queue_processed = true

    process_data = proc{
      begin
        @job.process_non_cmd_data(@queue_data)
      rescue =>e
        error("Encount exception when process the non-command data.")
        error e
        failed("Encount exception when process the non-command data, message: #{e.message}")
      end
    }
    
    if run_in_defer      
      EM.defer process_data
    else
      process_data.call
    end
  end

  def run_unserialize_command(command)
    vals = command.split("\r\n", 2)
    run_command(vals[0], vals[1])
  end

  def run_command(command, more_data)
    job_type, paras = command.split(':', 2)

    @debug_str = "#{job_type}:#{paras}"
    @job = find_job(job_type, paras)

    info("Command is  >>>  #{@debug_str}")

    @job.requester = self
    @job.admin_instance = CreateAdmin.instance
    @job.instance_id = @instance_id

    if more_data && !more_data.empty?
      @queue_data = @queue_data || Queue.new
      @queue_data.push(more_data)
    end

    EM.defer {
      begin
        @job.run()
        process_queue_data(nil, false) if more_data && !more_data.empty?
      rescue =>e
        error("Encount exception when runing the job: #{@debug_str}.")
        error e
        failed("Encount exception when runing the job: #{@debug_str}, message: #{e.message}")
      end
    }    
  end

  def find_job(job_type, paras)
    job_klass = CreateAdmin::JOBS[job_type]
    raise "Failed to parse the command: #{@debug_str}, can not find the job." if job_klass.nil?

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

    @job_type = job_type
    @instance_id = parsed_paras['_instance'] if parsed_paras 
    if (@instance_id)
      # we only monitor the job if the parameter has _instance.
      accept = CreateAdmin.instance.accept_job?(@job_type, @instance_id)
      raise CreateAdmin::JobFailedPassError.new(accept[:message]) unless accept[:accept]
    end

    job_klass.new(parsed_paras)
  end
end