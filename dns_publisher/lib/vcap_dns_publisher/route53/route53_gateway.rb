require 'builder'
require 'route53'
require 'json'

#TODO: turn this into a dns publisher for vcap.
module Route53
  module Gateway
  
    class Example
    
    
      def self.example(params)
        ip = params['ip']
        vm_token = params['vm_token']
        vm_password = params['vm_password']
        dns_prefix = params['dns_prefix']
        
        raise "Missing ip parameter" unless ip
        raise "Missing vm_token parameter" unless vm_token
        raise "Missing vm_password parameter" unless vm_password
        raise "Missing dns_prefix parameter" unless dns_prefix
        
        access_key = "123"
        secret_key = "4567"
        
        conn = Route53::Connection.new(access_key,secret_key,'2011-05-05','https://route53.amazonaws.com/',true) #opens connection with verbose logging
        ##conn = Route53::Connection.new(access_key,secret_key) #opens connection
        puts "Now to publish the current IP #{ip} on test.intalio.io, test.admin.intalio.io, test.oauth.intalio.io"
        zones=Route53::Gateway::IndexedZones.new(conn,["intalio.io","oauth.intalio.io","admin.intalio.io"])
        zones.publish(dns_prefix,ip)
        return "done"
      end
    
    end    
    FORCE_CREATE=false #for testing. should remain false otherwise
    FORCE_UPDATE=false #for testing. should remain false otherwise
    
    class IndexedZone
      # zone The DNS zone
      def initialize(zone)
        #puts "zone #{zone} #{zone.inspect}"
        raise "Expecting a Route53::Zone object" unless zone.kind_of? Route53::Zone
        @zone = zone
      end
      
      # Gets the records for this zone.
      # Filters them to read the 'A' records only.
      # Indexes them according to their 'prefix'.
      def index()
        escaped_zone_name = Regexp.escape(@zone.name)
        @records_indexed_by_prefix=Hash.new
        a_records=@zone.get_records("A")
        puts "A records in #{@zone} are #{a_records.to_json}"
        a_records.each do |record|
          if /^(.*)\.#{escaped_zone_name}$/ =~ record.name
            raise "Unexpected sub-domain: #{$1} in the record name #{record.name}" unless $1
            @records_indexed_by_prefix[$1]=record
          else
            raise "Unexpected record name #{record.name}; expecting it to start with #{@zone.name}"
          end
        end if a_records
      end
      
      # @return The Route53::DNSRecord for the given prefix.
      # The prefix can be 'psq'; it must not end with a '.'
      def get_record(prefix)
        raise "The prefix must not end with a '.'" if prefix.end_with?(".")
        index() unless @records_indexed_by_prefix
        @records_indexed_by_prefix[prefix]
      end
      
      # Update or create the DNS record of type 'A' for the current zone with the ip passed here.
      def publish(prefix,ip,ttl="300")
        record=get_record(prefix)
        if record && !FORCE_CREATE
          __update_record(record,prefix,ip,ttl)
        else
          begin
            puts "Creating the record #{prefix}.#{@zone.name}" if @zone.conn.verbose
            record = Route53::DNSRecord.new("#{prefix}.#{@zone.name}","A",ttl,[ip],@zone)
            resp = record.create
            if resp.error?
              #see if we need to index again the records in the zone 
              # if we find that we tried to create something that exists already.
              error_message = resp.error_message
              if /InvalidChangeBatch.*already.*exists/ =~ error_message
                puts "The record exists already: index the zone #{@zone} again and try to read it."
                index()
                record=get_record(prefix)
                raise "Unable to find the record #{prefix}.#{@zone.name} after an index." unless record
                __update_record(record,prefix,ip,ttl)
              else
                puts "Unexpected error message: #{error_message}"
              end
            else
              puts "Created the record #{prefix}.#{@zone.name}: #{resp}" if @zone.conn.verbose
            end
          rescue Exception => e
            puts "Exception #{e.class}"
            puts e.backtrace
            #index()
          end
        end
      end
      
      def __update_record(record,prefix,ip,ttl="300")
        # Let's see if there is indeed an IP change:
        record_values=record.values
        record_values.each do |val|
          if val == ip && !FORCE_UPDATE
            puts "Nothing to update for #{prefix}.#{@zone.name}; it is already mapped to the IP #{ip}" 
          else
            puts "Updating the record #{prefix}.#{@zone.name} with the IP #{ip}" if @zone.conn.verbose
            resp = record.update(record.name, record.type, ttl, [ip])
            puts "Updated the record #{prefix}.#{@zone.name}: #{resp}" if @zone.conn.verbose
          end
        end
      end
      
    end
    
    # A collection of indexed zones.
    class IndexedZones
      
      def initialize(conn,zones_in)
        @conn = conn
        @indexed_zones = zones(zones_in)
      end
      
      # Returns a list of the zones on which we publish the prefix
      # zones_in The zones 
      def zones(zones_in=nil)
        return @indexed_zones if zones_in.nil?
        if zones_in.kind_of? String
          zones_in = zones_in.split(%r{,\s*})
        else
          raise "Unexpected type of zones_in argument #{zones_in}" unless zones_in.kind_of? Array
        end
        @indexed_zones=Array.new
        zones_in.each do |zone_in|
          dns_zone = @conn.get_zones(zone_in)
          @indexed_zones << IndexedZone.new(dns_zone.first)
        end
        @indexed_zones
      end
      
      def publish(prefix,ip)
        puts "publish all #{ip} -> #{prefix}"
        zones().each do |zone|
          zone.publish(prefix,ip)
        end
      end
      
    end
        
  end
end