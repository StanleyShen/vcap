module DataService
  module PostgresSvc

    def self.get_postgres_db(pg_cred = nil)
      if pg_cred.nil?
        if(ENV['VCAP_SERVICES'])
          vcap_services = JSON.parse(ENV['VCAP_SERVICES'])
          detected_pg = vcap_services.detect { |k,v| k =~ /postgresql/ }
          if detected_pg.nil?
            STDERR.puts "Could not find a postgres in VCAP_SERVICES: #{ENV['VCAP_SERVICES']}"
            raise "Incorrect CF setup: no postgres data-service was bound to the application."
          end
          pg_vcap = detected_pg.last.first
          pg_cred = pg_vcap["credentials"]
        else
          require 'rubygems'
          require 'vmc_knife/data_services'

          pg_cred = VMC::KNIFE.get_credentials("pg_intalio")
        end
      end

      require 'pg'
      PGconn.connect(pg_cred["hostname"], pg_cred["port"], '', '', pg_cred["name"], pg_cred["username"], pg_cred["password"])
    end
  end
end
