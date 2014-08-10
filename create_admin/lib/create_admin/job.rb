module CreateAdmin
  class Job
  end
end

class CreateAdmin::Job
  attr_accessor :logger

  def initialize(paras = nil)
    @paras = paras
  end
  
  def run(requester)
    raise 'Subclass needs to implement this run method.'
  end
end