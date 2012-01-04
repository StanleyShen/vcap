require 'optparse'
require 'fileutils'
require 'yaml'
require 'nats/client'
require 'openssl'
require 'vcap/common'
require 'vcap/logging'

ROOT_REL = File.expand_path(File.dirname(__FILE__))
require "#{ROOT_REL}/vcap_dns_publisher/version"
require "#{ROOT_REL}/vcap_dns_publisher/const"
require "#{ROOT_REL}/vcap_dns_publisher/utils"
require "#{ROOT_REL}/vcap_dns_publisher/dns_publisher"



config_path = ENV["CLOUD_FOUNDRY_CONFIG_PATH"] || File.join(File.dirname(__FILE__), '../config')
config_file = File.join(config_path, 'dns_publisher.yml')

options = OptionParser.new do |opts|
  opts.banner = 'Usage: vcap-mdns-publisher [OPTIONS]'
  opts.on("-c", "--config [ARG]", "Configuration File") do |opt|
    config_file = opt
  end
  opts.on("-h", "--help", "Help") do
    puts opts
    exit
  end
end
options.parse!(ARGV.dup)

begin
  config = File.open(config_file) do |f|
    YAML.load(f)
  end
rescue => e
  puts "Could not read configuration file:  #{e}"
  exit
end

# Placeholder for Component reporting
config['config_file'] = File.expand_path(config_file)

EM.epoll

EM.run do

  trap("TERM") { stop(config['pid']) }
  trap("INT")  { stop(config['pid']) }

  VCAP::DNS_PUBLISHER::DnsPublisher.config(config)

  create_pid_file(config['pid'])

  NATS.on_error do |e|
    if e.kind_of? NATS::ConnectError
      puts("EXITING! NATS connection failed: #{e}")
      puts "#{e.backtrace.join("\n")}"
      exit!
    else
      puts("NATS problem, #{e}")
    end
  end

  EM.error_handler do |e|
    puts "Eventmachine problem, #{e}"
    puts "#{e.backtrace.join("\n")}"
  end

  # Override reconnect attempts in NATS until the proper option
  # is available inside NATS itself.
  begin
    sv, $-v = $-v, nil
    NATS::MAX_RECONNECT_ATTEMPTS = 150 # 5 minutes total
    NATS::RECONNECT_TIME_WAIT    = 2   # 2 secs
    $-v = sv
  end

  NATS.start(:uri => config['mbus'])

  # Create the register/unregister listeners.
  VCAP::DNS_PUBLISHER::DnsPublisher.setup_listeners
  
  # Register ourselves with the system
  unless config['vcap_component'] == false
    require 'vcap/component'
    status_config = config['status'] || {}
    VCAP::Component.register(:type => 'DNS_Publisher',
                             :host => VCAP.local_ip(config['local_route']),
                             :index => config['index'],
                             :config => config,
                             :port => status_config['port'],
                             :user => status_config['user'],
                             :password => status_config['password'])
  end
  
  @publisher_id = File.open('/dev/urandom') do |x| x.read(16).unpack('H*')[0] end
  @hello_message = { :id => @publisher_id, :version => VCAP::DNS_PUBLISHER::VERSION }.to_json.freeze

  # This will check on the state of the registered urls, do maintenance, etc..
  VCAP::DNS_PUBLISHER::DnsPublisher.setup_sweepers
  
  # Setup a start sweeper to make sure we have a consistent view of the world.
  EM.next_tick do
    # Announce our existence
    NATS.publish('dns_publisher.start', @hello_message)

    # Don't let the messages pile up if we are in a reconnecting state
    EM.add_periodic_timer(START_SWEEPER) do
      unless NATS.client.reconnecting?
        NATS.publish('dns_publisher.start', @hello_message)
      end
    end
  end
  
end
