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
      PGconn.connect(pg_cred["hostname"], pg_cred["port"], '', '', pg_cred["name"], pg_cred["username"], pg_cred["password"])
    end

    def query(sql, pg_cred = nil)
      conn = get_postgres_db(pg_cred)
      raise 'failed to get the pg connetion with cred#{pg_cred}' if conn.nil?

      begin
        conn.exec(sql) {|result|
          yield(result)
        }
      rescue Exception => e        
        CreateAdmin::Log.error("Failed to query sql: #{sql}\nerror message: #{e.message}")
        CreateAdmin::Log.error(e.backtrace)
      ensure
        conn.close
      end
    end
    
    def query_paras(sql, paras, pg_cred = nil)
      conn = get_postgres_db(pg_cred)
      raise 'failed to get the pg connetion with cred#{pg_cred}' if conn.nil?

      begin
        conn.exec_params(sql, paras) {|result|
          yield(result)
        }
      rescue Exception => e  
        CreateAdmin::Log.error("Failed to query sql: #{sql}, with paras: #{paras}\nerror message: #{e.message}")
        CreateAdmin::Log.error(e.backtrace)
      ensure
        conn.close
      end
    end
  end
end
