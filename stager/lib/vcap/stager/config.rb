require 'vcap/config'
require 'vcap/json_schema'
require 'vcap/staging/plugin/common'

module VCAP
  module Stager
  end
end

# Config template for stager
class VCAP::Stager::Config < VCAP::Config
  DEFAULT_CONFIG_PATH = File.expand_path('../../../../config/dev.yml', __FILE__)

  define_schema do
    { :logging => {
        :level              => String,      # debug, info, etc.
        optional(:file)     => String,      # Log file to use
        optional(:syslog)   => String,      # Name to associate with syslog messages (should start with 'vcap.')
      },

      :nats_uri              => String,     # NATS uri of the form nats://<user>:<pass>@<host>:<port>
      :max_staging_duration  => Integer,    # Maximum number of seconds a staging can run
      :max_active_tasks      => Integer,    # Maximum number of tasks executing concurrently
      :queues                => [String],   # List of queues to pull tasks from
      :pid_filename          => String,     # Pid filename to use
      optional(:dirs) => {
        optional(:manifests) => String,     # Where all of the staging manifests live
        optional(:tmp)       => String,     # Default is /tmp
      },

      :secure                => VCAP::JsonSchema::BoolSchema.new,

      optional(:index)       => Integer,    # Component index (stager-0, stager-1, etc)
      optional(:ruby_path)   => String,     # Full path to the ruby executable that should execute the run plugin script
      optional(:local_route) => String,     # If set, use this to determine the IP address that is returned in discovery messages
      optional(:run_plugin_path) => String, # Full path to run plugin script
    }
  end

  def self.from_file(*args)
    config = super(*args)
    filename = args[0]
    config[:dirs] ||= {}
    unless config[:dirs][:manifests]
      # try the staging directory first to support a chef installation.
      possible_manifests_dir=File.join(File.dirname(filename),"staging")
      config[:dirs][:manifests] = File.expand_path(possible_manifests_dir) if File.exists?(possible_manifests_dir)
      # default to the staging directory in the code of the staging plugin.
      config[:dirs][:manifests] ||= StagingPlugin::DEFAULT_MANIFEST_ROOT
    end
    puts "Starting the stager with the manifests found in #{config[:dirs][:manifests]}"
    config[:run_plugin_path]  ||= File.expand_path('../../../../bin/run_plugin', __FILE__)
    config[:ruby_path]        ||= `which ruby`.chomp

    config
  end
end
