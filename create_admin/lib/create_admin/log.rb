require 'rubygems'
require 'vcap/logging'

module CreateAdmin
  module Log
    @@logger = VCAP::Logging.logger('create_admin')

    levels = [:fatal, :error, :info, :warn, :debug]
    levels.each { | level |
      define_method(level) do | msg |
        @@logger.send(level, msg)
      end
    }
    
    class << self
      levels = [:fatal, :error, :info, :warn, :debug]
      levels.each { | level |
        define_method(level) do | msg |
          @@logger.send(level, msg)
        end
      }    
      
    end
    
    # Change the default logger
    def self.logger=(logger)
      @@logger = logger
    end
  end
end