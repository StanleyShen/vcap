require "create_admin/log"

module DataService
  module PostgresSvc

    def get_postgres_db(pg_cred = nil)
      if pg_cred.nil?
        require 'rubygems'
        require 'vmc_knife/data_services'

        pg_cred = VMC::KNIFE.get_credentials("pg_intalio")
      end
      require 'pg'
      if pg_cred.nil? || pg_cred.empty?
        CreateAdmin::Log.warn("can't get credential, pg_intalio service mayn't be ready.")
        return nil
      end
      PGconn.connect(pg_cred["hostname"], pg_cred["port"], '', '', pg_cred["name"], pg_cred["username"], pg_cred["password"])
    end

    def query(sql, pg_cred = nil)
      begin
        conn = get_postgres_db(pg_cred)
        raise 'failed to get the pg connetion with cred#{pg_cred}' if conn.nil?

        conn.exec(sql) {|result|
          yield(result)
        }
      rescue Exception => e        
        CreateAdmin::Log.error("Failed to query sql: #{sql}\nerror message: #{e.message}")
        CreateAdmin::Log.error(e.backtrace)
      ensure
        conn.close if conn
      end
    end
    
    def query_paras(sql, paras, pg_cred = nil)
      begin
        conn = get_postgres_db(pg_cred)
        raise 'failed to get the pg connetion with cred#{pg_cred}' if conn.nil?
        
        conn.exec_params(sql, paras) {|result|
          yield(result)
        }
      rescue Exception => e  
        CreateAdmin::Log.error("Failed to query sql: #{sql}, with paras: #{paras}\nerror message: #{e.message}")
        CreateAdmin::Log.error(e.backtrace)
      ensure
        conn.close if conn
      end
    end
  end
end
