module DataService
  module PostgresSvc

    def self.get_postgres_db(pg_cred = nil)
      if pg_cred.nil?
        require 'rubygems'
        require 'vmc_knife/data_services'

        pg_cred = VMC::KNIFE.get_credentials("pg_intalio")
      end

      require 'pg'
      PGconn.connect(pg_cred["hostname"], pg_cred["port"], '', '', pg_cred["name"], pg_cred["username"], pg_cred["password"])
    end
  end
end
