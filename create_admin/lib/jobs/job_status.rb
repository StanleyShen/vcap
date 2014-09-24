require 'rubygems'

require 'jobs/job'

module Jobs
  class JobStatus < Job
  end
end

class ::Jobs::JobStatus
  def initialize(options)
    @instance_id = options['instance']
  end

  def run
    send_data(@admin_instance.job_status(@instance_id), true)
  end
end