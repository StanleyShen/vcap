# Copyright (c) 2009-2011 VMware, Inc.
# Identicals to router/utils.rb
def create_pid_file(pidfile)
  # Make sure dirs exist.
  begin
    FileUtils.mkdir_p(File.dirname(pidfile))
  rescue => e
     VCAP::DNS_PUBLISHER::DnsPublisher.log.fatal "Can't create pid directory, exiting: #{e}"
  end
  File.open(pidfile, 'w') { |f| f.puts "#{Process.pid}" }
end

def stop(pidfile)
  # Double ctrl-c just terminates
  exit if VCAP::DNS_PUBLISHER::DnsPublisher.shutting_down?
  VCAP::DNS_PUBLISHER::DnsPublisher.shutting_down = true
  VCAP::DNS_PUBLISHER::DnsPublisher.log.info 'Signal caught, shutting down..'
  VCAP::DNS_PUBLISHER::DnsPublisher.log.info 'waiting for pending requests to complete.'
#  if Router.outstanding_request_count <= 0
    exit_router(pidfile)
#  else
#    EM.add_periodic_timer(0.25) { exit_router(pidfile) if (Router.outstanding_request_count <= 0) }
#    EM.add_timer(10) { exit_router(pidfile) } # Wait at most 10 secs
#  end

end

def exit_router(pidfile)
  NATS.stop { EM.stop }
  VCAP::DNS_PUBLISHER::DnsPublisher.log.info "Bye"
  FileUtils.rm_f(pidfile)
  exit
end

