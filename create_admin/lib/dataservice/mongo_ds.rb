require 'mongo'
module DataService

  # can't use Mongo! namespace collision
  module MongoSvc

    @mongo_conn = nil
    @mongo_db = nil

    def get_mongo_db()
      return @mongo_db unless @mongo_conn.nil? || @mongo_conn.connected?
      if(ENV['VCAP_SERVICES'])
        vcap_services = JSON.parse(ENV['VCAP_SERVICES'])
        detected_mongos = vcap_services.detect { |k,v| k =~ /mongod/ }
        if detected_mongos.nil?
          STDERR.puts "Could not find a mongodb in VCAP_SERVICES: #{ENV['VCAP_SERVICES']}"
          raise "Incorrect CF setup: no mongodb data-service was bound to the application."
        end
        mongo_vcap = detected_mongos.last.first
        mongo_cred = mongo_vcap["credentials"]
      else
        mongo_cred = { "hostname" => "localhost", "port" => "27017", "db" => "intalio"}
      end
      conn = Mongo::Connection.new(mongo_cred["hostname"], mongo_cred["port"])
      conn.add_auth(mongo_cred["db"], mongo_cred["username"], mongo_cred["password"]) unless mongo_cred["password"].nil?
      @mongo_db = conn.db(mongo_cred["db"])
    end
  end
end
