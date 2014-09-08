require 'rubygems'
require 'json/pure'

require "create_admin/log"
require "create_admin/util"

module Jobs
  class Job
  end
end

class Jobs::Job
  include ::CreateAdmin::Log

  attr_accessor :requester, :admin_instance

  JOB_STATES = { :queued => 'queued',
                 :working => 'working',
                 :failed => 'failed',
                 :completed => 'completed',
                 :killed => 'killed' }

  def run()
    raise 'Subclass needs to implement this run method.'
  end
    
  def at(num, total, *messages)
    send_status({:status => JOB_STATES[:working], :num => num, :total => total}, false, *messages)
  end

  def completed(*messages)
    send_status({:status => JOB_STATES[:completed]}, true, *messages)
  end

  def failed(*messages)
    send_status({:status => JOB_STATES[:failed]}, true, *messages)
  end
  
  def send_data(data, end_request = false)
    if end_request
      @requester.close(data)
    else
      @requester.message(data)
    end
  end

  private
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

    send_data(status, end_request)
  end
end