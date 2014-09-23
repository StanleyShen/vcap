$:.unshift(File.join(File.dirname(__FILE__), 'lib'))
$:.unshift(File.dirname(__FILE__))

require 'rubygems'
require 'logging'

require 'optparse'
require 'yaml'
require 'create_admin/agent'
require 'create_admin/log'

cfg_path = ENV["CLOUD_FOUNDRY_CONFIG_PATH"] || File.join(File.dirname(__FILE__), '../config')
cfg_overrides = { 'config_file' => File.join(cfg_path, 'create_admin.yml') }

options = OptionParser.new do |opts|
  opts.banner = 'Usage: dea [OPTIONS]'
  opts.on("-c", "--config [ARG]", "Configuration File") do |opt|
    cfg_overrides['config_file'] = opt
  end
  opts.on("-h", "--help", "Help") do
    puts opts
    exit
  end
end
options.parse!(ARGV.dup)

begin
  config = File.open(cfg_overrides['config_file']) do |f|
    YAML.load(f)
  end
rescue => e
  puts "Could not read configuration file: #{e}"
  exit 1
end

config.update(cfg_overrides)

config['config_file'] = File.expand_path(config['config_file'])

# setup logger
VCAP::Logging.setup_from_config(config['logging'])
CreateAdmin::Log.logger = VCAP::Logging.logger('create_admin')

agent = ::CreateAdmin::Agent.new(config)