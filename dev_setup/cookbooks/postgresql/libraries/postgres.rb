module CloudFoundryPostgres
  
  def pg_server_command(cmd)
    # Cant use service resource as service name needs to be statically defined
    # For pg_major_version >= 9.0 the version does not appear in the name
    if node[:postgresql][:version] == "9.0"
      `#{File.join("", "etc", "init.d", "postgresql-#{pg_major_version}")} #{cmd}`
    else
      `#{File.join("", "etc", "init.d", "postgresql")} #{cmd}`
    end
  end
  
  def cf_pg_update_hba_conf(db, user, ip_and_mask='0.0.0.0/0', pass_encrypt='md5')
    case node['platform']
    when "ubuntu"
      ruby_block "Update PostgreSQL config" do
        block do
          pg_major_version = get_pg_major_version

          # Update pg_hba.conf
          pg_hba_conf_file = File.join("", "etc", "postgresql", pg_major_version, "main", "pg_hba.conf")
          `grep "#{db}\s*#{user}" #{pg_hba_conf_file}`
          if $?.exitstatus != 0
            `echo "host #{db} #{user} #{ip_and_mask} #{pass_encrypt}" >> #{pg_hba_conf_file}`
          end
          
          #pg_server_command 'restart'
          if node[:postgresql][:version] == "9.0"
            `#{File.join("", "etc", "init.d", "postgresql-#{pg_major_version}")} #{cmd}`
          else
            `#{File.join("", "etc", "init.d", "postgresql")} #{cmd}`
          end

        end
      end
    else
      Chef::Log.error("PostgreSQL config update is not supported on this platform.")
    end
  end

  def cf_pg_setup_db(db, user, passwd)
    case node['platform']
    when "ubuntu"
      bash "Setup PostgreSQL database #{db}" do
        user "postgres"
        code <<-EOH
createdb #{db}
psql -d #{db} -c \"create role #{user} NOSUPERUSER LOGIN INHERIT CREATEDB\"
psql -d #{db} -c \"alter role #{user} with password '#{passwd}'\"
echo \"db #{db} user #{user} pass #{passwd}\" >> #{File.join("", "tmp", "cf_pg_setup_db")}
EOH
      end
    else
      Chef::Log.error("PostgreSQL database setup is not supported on this platform.")
    end
  end
  
  def cf_pg_setup_ltree()
    case node['platform']
    when "ubuntu"
      pg_major_version = get_pg_major_version
      bash "Setup PostgreSQL default database template with ltree" do
        user "postgres"
        if pg_major_version == '9.0'
        code <<-EOH
ltree_sql_path="/usr/share/postgresql/9.0/contrib/ltree.sql"
if [ -f "$ltree_sql_path" ]; then
  psql template1 -f $ltree_sql_path
  psql template1 -c \"select '1.1'::ltree;\"
  exit $?
else
  echo "Warning: unable to configure the ltree extension. ltree is not installed on this postgres db."
  exit 22
fi
EOH
        else
        #9.1 and more recent have a much nicer way of setting up ltree.
        #see http://www.depesz.com/index.php/2011/03/02/waiting-for-9-1-extensions/
        code <<-EOH
psql template1 -c \"CREATE EXTENSION IF NOT EXISTS ltree;\"
psql template1 -c \"select '1.1'::ltree;\"
exit $?
EOH
        end
      end
    else
      Chef::Log.error("PostgreSQL database setup is not supported on this platform.")
    end
  end
  
  def get_pg_major_version()
    case node['platform']
    when "ubuntu"
      ruby_block "Update PostgreSQL config" do
        block do
          / \d*.\d*/ =~ `pg_config --version`
          pg_major_version = $&.strip
          return pg_major_version
        end
      end
    else
      Chef::Log.error("PostgreSQL config update is not supported on this platform.")
    end
  end

end

class Chef::Recipe
  include CloudFoundryPostgres
end

class Chef::Resource
  include CloudFoundryPostgres
end