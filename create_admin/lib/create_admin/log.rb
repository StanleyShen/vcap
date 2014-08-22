require 'rubygems'
require 'vcap/logging'

module CreateAdmin
  module Log
    @@logger = nil
    levels = [:fatal, :error, :info, :warn, :debug]

    levels.each { | level |
      define_method(level) do | msg |
        if @@logger
          @@logger.send(level, msg)
        else
          puts msg
        end
      end
    }
    
    class << self
      levels = [:fatal, :error, :info, :warn, :debug]
      levels.each { | level |
        define_method(level) do | msg |
          if @@logger
            @@logger.send(level, msg)
          else
            puts msg
          end
        end
      }
    end
    
    # Change the default logger
    def self.logger=(logger)
      @@logger = logger
    end
  end
end