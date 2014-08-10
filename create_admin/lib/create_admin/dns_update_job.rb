require 'rubygems'
require 'logging'
require "create_admin/job"

module CreateAdmin
  class DNSUpdateJob < Job
  end
end

class ::CreateAdmin::DNSUpdateJob
  def initialize(paras = nil)
    @logger = Logging.logger['create.admin.dns.update.job']
    @paras = paras
  end
  
  def run(requester)
#    process(callback, 'dns update ran successfully!')
  end
end