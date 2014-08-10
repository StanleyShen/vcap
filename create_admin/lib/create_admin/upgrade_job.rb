require 'rubygems'
require 'logging'

require "create_admin/job"

module CreateAdmin
  class UpgradeJob < Job
  end
end

class ::CreateAdmin::UpgradeJob
  def initialize(paras = nil)
    @logger = Logging.logger['create.admin.upgrade.job']
    @paras = paras
  end
  
  def run(requester)
  end
end