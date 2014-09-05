require 'rubygems'

require 'dataservice/postgres_ds'
require 'jobs/job'

module Jobs
  class UserProfile < Job
  end
end

class ::Jobs::UserProfile
  include DataService::PostgresSvc

  def initialize(options)
    @username = options['username']
    raise "No username provided" if (@username.nil? || @username.empty?)
  end

  def run
    sql = "select l.io_iso6391 as def_lang from io_user_parameter up join io_user u on u.io_user_parameters=up.io_uuid join io_language l on l.io_uuid=up.io_default_language and u.io_username=$1 and l.io_supported='t' and l.io_active='t';";
    user_lang = query_paras(sql, [@username]){|res|
      res.getvalue(0, 0)
    }
    return send_json({'lang' => user_lang}) if user_lang.nil?
    
    sql = "select l.io_iso6391 from io_system_setting ss join io_language l on ss.io_default_language=l.io_uuid where ss.io_active='t' and l.io_supported='t';"
    sys_lang = query(sql){|res|
      res.getvalue(0, 0)
    }
    send_json({'lang' => sys_lang}, true)
  end
end
