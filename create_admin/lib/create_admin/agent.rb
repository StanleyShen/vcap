require 'rubygems'
require 'logging'
require 'eventmachine'
require 'vcap/logging'

require "create_admin/backup_job"
require "create_admin/dns_update_job"
require "create_admin/upgrade_job"


module CreateAdmin
  JOBS = {
    'upgrade' => 'CreateAdmin::UpgradeJob',
    'backup' => 'CreateAdmin::BackupJob',
    'dns_update' => 'CreateAdmin::DNSUpdateJob'
  }
  class Agent
  end  
  class ConnectionHandler < EM::Connection
  end
end

class ::CreateAdmin::Agent

  def initialize(options)
    @options = options || {}

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

  def receive_data(command)
    logger = @options[:logger]
    command.strip!

    logger.info("Command is  >>>  #{command}")

    job = parse(command)
    job.logger = logger
    
    job.run(self)
  end

  def message(status)
    send_data(status)
  end
  
  def close(message)
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
    logger.error("Can't find the job: #{job}") if job.nil?

    klass = job.split('::').inject(Object) {|o,c| o.const_get c}          
    klass.new(paras)
  end

end