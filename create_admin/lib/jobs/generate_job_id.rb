require 'rubygems'

require 'jobs/job'

module Jobs
  class GenJobInstanceId < Job
  end
end

class ::Jobs::GenJobInstanceId
  def run
    send_data(@admin_instance.get_safe_instance_id, true)
  end
end