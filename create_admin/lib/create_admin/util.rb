require 'rubygems'
require 'vmc_knife'

require "dataservice/postgres_ds"
require "create_admin/log"

module CreateAdmin
  extend ::DataService::PostgresSvc
  
  def self.normalize_file_path(path)
    # absolute path
    return path if (path.start_with?(File::SEPARATOR))
    File.join(ENV['HOME'], path)
  end

  def self.file_metadata(file_path)
    name = File.basename(file_path)
    size = File.size(file_path)
    last_modified = File.mtime(file_path).to_i
    {'name' => name, 'size' => size, 'last_modified' => last_modified}
  end

  def self.get_file(options, name_required = false)
    type = options['type']
    path = options['path']
    name = options['name']

    if (path.nil?)
      raise 'type must be specified.' if type.nil?
      raise 'name must be specified.' if name_required && name.nil?
      case type
        when 'backup'
          path = if name
            File.join("#{ENV['HOME']}/cloudfoundry/backup", name)
          else
            "#{ENV['HOME']}/cloudfoundry/backup"
          end
        when 'cdn'
          path = if name
            File.join("#{ENV['HOME']}/intalio/cdn/resources", name)
          else
            "#{ENV['HOME']}/intalio/cdn/resources"
          end
      end
      path = normalize_file_path(path)
    else
      path = normalize_file_path(path)
    end
    path
  end

  def self.get_repository_url
    sql = "select io_repository_url from io_system_setting where io_active='t';"
    begin
      url = nil
      query(sql) {|res|
        url = res.getvalue(0, 0)
      }
      return if url.nil?

      url = url + '/' unless url.end_with?('/')
      url
    rescue => e
      CreateAdmin::Log.warn('can not get the repository url, the active system setting may not available.')
      CreateAdmin::Log.warn(e)
    end
  end
  
  def self.get_build_number(include_patch_num = false)
    sql = "select io_build_number from io_system_setting where io_active='t';"
    begin
      build_num = nil
      query(sql) {|res|
        build_num = res.getvalue(0, 0)
      }
      return build_num if include_patch_num

      nums = build_num.split('.').concat([0, 0, 0])
      return "#{nums[0]}.#{nums[1]}.#{nums[2]}"
    rescue => e
      CreateAdmin::Log.warn('can not get the build number, the active system setting may not available.')
      CreateAdmin::Log.warn(e)
    end
    nil
  end
  
  def self.active_user_num(exclude_system_user = true)
    sql = "select count(*) as t_count from io_user where io_active = true and io_deleted = false";
    if (exclude_system_user)
      sql += " and io_uuid != '764f0869-8b2a-4e43-8f23-88f593863eff'";
    end
    
    num = query(sql) {|res|
      res.getvalue(0, 0)
    }
    num
  end
  
  # note: the caller must begin the transaction
  def self.create_large_object(data, conn)
    oid = conn.lo_creat(PG::Constants::INV_WRITE)
    lo_desc = conn.lo_open(oid, PG::Constants::INV_WRITE)
    conn.lo_write(lo_desc, data)

    [lo_desc, oid]
  end
  
  def self.create_record(table, data, conn = nil)
    now = Time.now.iso8601
    columns, vals = [], []
  
    data.each{|k, v|
      columns << k
      vals << v
    }

    if (data['io_created_on'].nil?)
      columns << 'io_created_on'
      vals << now
    end

    if (data['io_updated_on'].nil?)
      columns << 'io_updated_on'
      vals << now
    end

    if (data['io_created_by'].nil?)
      columns << 'io_created_by'
      vals << '764f0869-8b2a-4e43-8f23-88f593863eff' # system user
    end

    if (data['io_updated_by'].nil?)
      columns << 'io_updated_by'
      vals << '764f0869-8b2a-4e43-8f23-88f593863eff'
    end

    if (data['io_active'].nil?)
      columns << 'io_active'
      vals << true
    end

    if (data['io_deleted'].nil?)
      columns << 'io_deleted'
      vals << false
    end
    
    if (data['io_owner'].nil?)
      columns << 'io_owner'
      vals << '764f0869-8b2a-4e43-8f23-88f593863eff'
    end

    gen_id = data['io_uuid'].nil?
    columns << 'io_uuid' if gen_id
    
    sql = "INSERT INTO " + table + "(" + columns.join(',') + ") VALUES ("
    ps = []
    vals.each_with_index{|v, idx|
      ps.push("$#{idx+1}");
    }

    sql = sql + ps.join(",")
  
    sql = sql + ',uuid_generate_v4()' if gen_id
    sql = sql + ') RETURNING io_uuid'
    
    begin
      create_conn = conn.nil?
      conn = get_postgres_db if create_conn
      conn.set_error_verbosity(PG::PQERRORS_VERBOSE)

      conn.prepare('stmt', sql)
      res = conn.exec_prepared('stmt', vals)
      res.getvalue(0, 0)
    rescue => e
      CreateAdmin::Log.error("Failed to create record for table #{table} with data #{data}, message: #{e.message}")
      raise e
    ensure
      if create_conn && conn
        conn.close
      end
    end
  end

  def self.get_base_url(url)
    return if url.nil? || url.empty?
    return url if url.end_with?('/')
    url.sub(/([^\/]*$)/, '')
  end
 
  def self.get_local_ipv4
    ip = Socket.ip_address_list.detect{ |intf|
      intf.ipv4? or intf.ipv4_private? and !(intf.ipv4_loopback? or intf.ipv4_multicast?)
    }
    ip.ip_address
  end
  
  def self.uptime_string(delta)
    num_seconds = delta.to_i
    days = num_seconds / (60 * 60 * 24);
    num_seconds -= days * (60 * 60 * 24);
    hours = num_seconds / (60 * 60);
    num_seconds -= hours * (60 * 60);
    minutes = num_seconds / 60;
    num_seconds -= minutes * 60;
    "#{days}d:#{hours}h:#{minutes}m:#{num_seconds}s"
  end

  @@filesize_conv = {
    1024 => 'B',
    1024*1024 => 'KB',
    1024*1024*1024 => 'MB',
    1024*1024*1024*1024 => 'GB',
    1024*1024*1024*1024*1024 => 'TB',
    1024*1024*1024*1024*1024*1024 => 'PB',
    1024*1024*1024*1024*1024*1024*1024 => 'EB'
  }
  
  def self.pretty_size(size)
    size = size.to_f
    @@filesize_conv.keys.each { |mult|
      next if size >= mult
      suffix = @@filesize_conv[mult]
      return "%.2f %s" % [ size / (mult / 1024), suffix ]
    }
  end
end