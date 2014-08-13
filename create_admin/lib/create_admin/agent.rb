require 'rubygems'
require 'json/pure'
require 'eventmachine'
require 'vcap/logging'

require "common/pid_file"
require "jobs/backup_job"
require "jobs/dns_update_job"
require "jobs/upgrade_job"

module CreateAdmin
  JOBS = {
    'upgrade' => 'Jobs::UpgradeJob',
    'backup' => 'Jobs::BackupJob',
    'dns_update' => 'Jobs::DNSUpdateJob'
  }
  class Agent
  end  
  class ConnectionHandler < EM::Connection
  end
end

class ::CreateAdmin::Agent

  def initialize(options)
    @options = options || {}

    begin
      pid_file = PidFile.new(@options['pid'])
      pid_file.unlink_at_exit
    rescue => e
      puts "ERROR: Can't create create_admin pid file #{@options['pid']}"
      exit 1
    end
      
    VCAP::Logging.setup_from_config(options['logging'])
    @logger = VCAP::Logging.logger('create_admin')

    @options[:logger] = @logger
    start_server()
  end

  def start_server()
    port = @options['port'] || 58080
    EM.run do    
      EM.start_server('0.0.0.0', port, ::CreateAdmin::ConnectionHandler){|dispather|
        dispather.options = @options
      }
    end
  end
end

class ::CreateAdmin::ConnectionHandler
  attr_accessor :options
  attr_reader :closed
  
  def initialize
    @closed = false
  end

  def receive_data(command)
    logger = @options[:logger]
    command.strip!

    logger.info("Command is  >>>  #{command}")

    job = parse(command)
    if job.nil?
      logger.error("Can't find the job with command: #{command}")
      close("Can't find the job with command: #{command}")
      return
    end

    job.logger = logger
    job.requester = self
    
    job.run()
  rescue => e
    logger.error("Failed to execute command #{command}")
    logger.error(e)
    close("Failed to execute command #{command}, message: #{e.message}")
  end

  def message(status)
    send_data(status)
  end
  
  def close(message)    
    return if @closed
    @closed = true

    EM.next_tick do
      send_data(message)
      close_connection_after_writing
    end
  end
  
  private
  def parse(command)
    logger = @options[:logger]

    job_type, paras = command.split(':', 2)
    job = CreateAdmin::JOBS[job_type]
    return if job.nil?

    klass = job.split('::').inject(Object) {|o,c| o.const_get c}
    parsed_paras = if paras.nil? || paras.empty?
      nil
    else
      begin
        JSON.parse(paras)
      rescue
        nil
      end
    end

    logger.info("the parsed parameters is .... #{parsed_paras}")

    klass.new(parsed_paras)
  end

end