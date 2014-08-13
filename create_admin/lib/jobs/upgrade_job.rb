require 'rubygems'

require "jobs/job"

module Jobs
  class UpgradeJob < Job
  end
end

class ::Jobs::UpgradeJob
  def initialize(paras = nil)
    @paras = paras
  end
  
  def run()
  end
end