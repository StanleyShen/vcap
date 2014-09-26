require 'rubygems'

require 'jobs/job'

module Jobs
  class JobStatus < Job
  end
end

class ::Jobs::JobStatus
  def initialize(options)
    @instance_id = options['instance']
    @job_type = options['type']
  end

  def run
    return send_data(@admin_instance.job_instance_status(@instance_id), true) if @instance_id
    send_data(@admin_instance.job_status(@job_type), true)
  end
end