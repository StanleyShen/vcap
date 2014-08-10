require 'rubygems'
require 'logging'

require 'vmc_knife'
require 'vmc_knife/commands/knife_cmds'


require "create_admin/job"

module CreateAdmin
  class BackupJob < Job
  end
end

class ::CreateAdmin::BackupJob
  include VMC::KNIFE::Cli

  def initialize(paras = nil)
    @paras = paras
  end

  def run(requester)
    @logger.info("env is ... #{ENV.inspect}")
    requester.message("I am runing...")
    sleep(1)
    requester.message("I am runing... 1 sec")
    sleep(2)
    requester.message("I am runing... 2 sec")

    requester.close("Done")
  end
end