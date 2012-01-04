module VCAP
  module DNS_PUBLISHER
    class DnsPublisher
      class << self
        
        attr_reader   :log
        attr_accessor :shutting_down
        alias :shutting_down? :shutting_down
        
        def version
          return VCAP::DNS_PUBLISHER::VERSION
        end

        def config(config)
          @dns_url_filter=(Regexp.new(config['dns_url_filter']) if config['dns_url_filter']) || /\.local$/
          @droplets = {}
          @published_urls = {}
          VCAP::Logging.setup_from_config(config['logging'] || {})
          @log = VCAP::Logging.logger('dns_publisher')
          #@log = Logger.new
          @publishers = {}
          config['publishers'].each do |name,conf|
            enable=conf['enable']
            if enable
              require_str=conf['require']
              impl=conf['impl']
              raise "The publisher #{name} does not have an 'impl' attribute" unless impl
              # there must be a more elegant way to do this...
              begin
                eval("require \"#{require_str}\"") if require_str
                #publisher=eval("#{impl}.config(conf)")
                klass = impl.split("::").inject(Object) { |k,n| k.const_get(n) }
                publisher=klass.config(conf)
                @publishers[name]=publisher
                log.info "Added the publisher #{name}"
              rescue => e
                log.fatal "The publisher #{name} could not be instantiated: require #{require_str}; impl #{impl}: #{e.message}"
                log.fatal e.backtrace
                raise "The publisher #{name} could not be instantiated: require #{require_str}; impl #{impl}"
              end
            end
          end
        end
        
        def setup_listeners
          NATS.subscribe('router.register') do |msg|
            msg_hash = Yajl::Parser.parse(msg, :symbolize_keys => true)
            return unless uris = msg_hash[:uris]
            uris.each do |uri|
              register_droplet(uri, msg_hash[:host], msg_hash[:port], msg_hash[:tags])
            end
          end
          NATS.subscribe('router.unregister') do |msg|
            msg_hash = Yajl::Parser.parse(msg, :symbolize_keys => true)
            return unless uris = msg_hash[:uris]
            uris.each do |uri|
              unregister_droplet(uri, msg_hash[:host], msg_hash[:port])
            end
          end
          @publishers.each do |name,publisher|
            begin
              publisher.setup_listeners
            rescue => e
              log.warn "Error setup_listeners on publisher #{name}: #{e.message}"
              log.warn e.backtrace
            end
          end
        end
        
        def setup_sweepers
          EM.add_periodic_timer(CHECK_SWEEPER) do
            check_registered_urls
          end
          @publishers.each do |name,publisher|
            begin
              publisher.setup_sweepers
            rescue => e
              log.warn "Error setup_sweepers on publisher #{name}: #{e.message}"
              log.warn e.backtrace.join("\n")
            end
          end
        end

        def check_registered_urls
          start = Time.now

          # If NATS is reconnecting, let's be optimistic and assume
          # the apps are there instead of actively pruning.
          if NATS.client.reconnecting?
            log.info "Suppressing checks on registered URLS while reconnecting to mbus."
            @droplets.each_pair do |url, instances|
              instances.each { |droplet| droplet[:timestamp] = start }
            end
            return
          end

          to_drop = []
          @droplets.each_pair do |url, instances|
            instances.each do |droplet|
              to_drop << droplet if ((start - droplet[:timestamp]) > MAX_AGE_STALE)
            end
          end
          log.debug "Checked all registered URLS in #{Time.now - start} secs."
          to_drop.each { |droplet| unregister_droplet(droplet[:url], droplet[:host], droplet[:port]) }
        end

        def register_droplet(url, host, port, tags)
          log.debug "register #{url}"
          return unless host && port
          url.downcase!
          droplets = @droplets[url] || []
          # Skip the ones we already know about..
          droplets.each { |droplet|
            # If we already now about them just update the timestamp..
            if(droplet[:host] == host && droplet[:port] == port)
              droplet[:timestamp] = Time.now
              return
            end
          }
          droplet = {
            :host => host,
            :port => port,
            :url => url,
            :timestamp => Time.now
          }
          droplets << droplet
          @droplets[url] = droplets
          log.info "Registering #{url} at #{host}:#{port}"
          publish(url)
          log.info "#{droplets.size} servers available for #{url}"
        end

        def unregister_droplet(url, host, port)
          url.downcase!
          droplets = @droplets[url] || []
          dsize = droplets.size
          droplets.delete_if { |d| d[:host] == host && d[:port] == port}
          if droplets.empty?
            @droplets.delete(url)
            unpublish(url)
          end
          log.info "#{droplets.size} servers available for #{url}"
        end
        
        def publish(url)
          @publishers.each do |name,publisher|
            begin
              publisher.publish url.strip
            rescue => e
              log.warn "#{url} error publishing #{url} on #{name}: #{e.message}"
              log.warn e.backtrace
            end
          end
        end
        def unpublish(url)
          @publishers.each do |name,publisher|
            begin
              publisher.unpublish url.strip
            rescue => e
              log.warn "#{url} error un-publishing #{url} on #{name}: #{e.message}"
              log.warn e.backtrace
            end
          end
        end
        
      end # end of class self

    end # end of DnsPublisher
  end # end of DNS_PUBLISHER
end

