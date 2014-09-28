require 'rubygems'

require 'jobs/job'

module Jobs
  class JobStatus < Job
  end
end

class ::Jobs::JobStatus
  def initialize(options)
    @job_instance = options['instance']
    @job_type = options['type']
    if @job_instance.nil? && @job_type.nil?
      raise 'To query job status, must provide instance or type.'
    end
  end

  def run
    return send_data(@admin_instance.job_instance_status(@job_instance), true) if @job_instance
    send_data(@admin_instance.job_status(@job_type), true)
  end
end