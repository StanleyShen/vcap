module VCAP
  module DNS_PUBLISHER
    class AvahiPublisher
      class << self
        
        attr_reader   :log
        
        def config(conf)
          hostnames_filter=conf['hostnames_filter']
          if hostnames_filter
            hostnames_filter=hostnames_filter[1..-1] if hostnames_filter.start_with?('/') && hostnames_filter.end_with?('/')
            @dns_url_filter=Regexp.new(hostnames_filter)
          else
            @dns_url_filter=/\.local$/
          end
          @published_urls = {}
          @log = VCAP::DNS_PUBLISHER::DnsPublisher.log
          log.info "avahi-mdsn publisher in place for #{@dns_url_filter.inspect}"
          self
        end
        
        def setup_listeners
          #nothing to do.
        end
        
        def setup_sweepers
          #nothing to do.
        end

        def publish(url)
          if @dns_url_filter =~ url && @published_urls[url].nil?
            pid = Process.fork { exec "python #{File.dirname(__FILE__)}/avahi-publish-domain-alias.py #{url}" }
            @published_urls[url]=pid
            log.info "publishing #{url} on avahi mdns: pid #{pid}}"
          end
        end
        def unpublish(url)
          pid=@published_urls[url.strip]
          log.info "unpublishing #{url} on avahi mdns: pid #{pid}." if pid
          Process.kill("HUP", pid) if pid
        end
        
      end # end of class self

    end # end of AliasPublisher
  end # end of DNS_PUBLISHER
end

