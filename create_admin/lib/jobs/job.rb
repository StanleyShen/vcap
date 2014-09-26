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
  attr_accessor :requester, :admin_instance, :instance_id

  def self.job_name
    name
  end

  def self.accept?(my_type, job_type)
    exclusive_jobs = CreateAdmin::EXCLUSIVE_JOBS[my_type]
    return false if exclusive_jobs && exclusive_jobs.include?(job_type)
    true
  end

  def initialize(options = nil)
  end
  
  def run()
    raise 'Subclass needs to implement this run method.'
  end

  # it is to update the execution result directly
  def update_execution_result(res)
    return if @instance_id.nil?
    @admin_instance.update_instance_execution_result(@instance_id, res)
  end
  
  def at(num, total, messages)
    send_status({'_status' => CreateAdmin::JOB_STATES['working'], 'num' => num, 'total' => total}, false, messages)
  end

  def completed(messages = nil, end_request = true)
    send_status({'_status' => CreateAdmin::JOB_STATES['success']}, end_request, messages)
  end

  def failed(messages = nil, end_request = true)
    send_status({'_status' => CreateAdmin::JOB_STATES['failed']}, end_request, messages)
  end
  
  def send_data(data, end_request = false)
    # update the execution result
    if end_request
      @requester.close(data)
    else
      @requester.message(data)
    end
  end

  def send_status(status, end_request, message = nil)
    if message
      if message.is_a?(String)
        status['message'] = message
      elsif message.is_a?(Hash)
        status = message.merge(status)
      end
    end

    if end_request && @instance_id
      @admin_instance.update_instance_execution_result(@instance_id, data)
    end

    send_data(status, end_request)
  end
end