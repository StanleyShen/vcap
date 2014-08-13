require 'rubygems'
require 'json/pure'

module Jobs
  class Job
  end
end

class Jobs::Job
  attr_accessor :logger, :requester

  JOB_STATES = { :queued => 'queued',
                 :working => 'working',
                 :failed => 'failed',
                 :completed => 'completed',
                 :killed => 'killed' }

  def run()
    raise 'Subclass needs to implement this run method.'
  end

  def vmc_client_from_manifest(manifest)
    target = manifest['target']
    user = manifest['email']
    password = manifest['password']

    vmc_client(target, user, password, false)
  end
  
  def vmc_client(target, user, password, renew = false)
    begin
      log_debug "Getting vmc client"
      @vmc_client = login_vmc_client(target, user, password) if @vmc_client.nil? || renew
      @vmc_client
    rescue => e
      log_error "Unable to login #{e.message}"
      log_error e.backtrace
      nil
    end
  end

  def log_error(message)
    @logger.error(message)
  end
  alias :error :log_error

  def log_info(message)
    @logger.info(message)
  end
  alias :info :log_info
    
  def log_debug(message)
    @logger.debug(message)
  end
  alias :debug :log_debug
  
  def log_warn(message)
    @logger.warn(message)
  end
  alias :warn :log_warn

  def at(num, total, *messages)
    send_status({:status => JOB_STATES[:working], :num => num, :total => total}, false, *messages)
  end

  def completed(*messages)
    send_status({:status => JOB_STATES[:completed]}, true, *messages)
  end

  def failed(*messages)
    send_status({:status => JOB_STATES[:failed]}, true, *messages)
  end

  private
  def login_vmc_client(target, user, password)
    target = target || 'api.intalio.priv'
    user = user || 'system@intalio.com'
    password = password || 'gold'

    client = VMC::Client.new(target)
    client.login(user, password)
    client
  end

  def send_status(status, end_request, message = nil)
    if message
      if message.is_a?(String)
        status[:message] = message
      elsif message.is_a?(Hash)
        message.each{|k,v|
          k = k.to_sym() if k.is_a?(String)
          status[k] = v
        }
      end
    end

    if end_request
      @requester.close(status.to_json)
    else
      @requester.message(status.to_json)
    end
  end
end