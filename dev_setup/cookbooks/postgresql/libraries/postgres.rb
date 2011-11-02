module CloudFoundryPostgres
  
  def cf_pg_server_command(cmd='restart')
    case node['platform']
    when "ubuntu"
      ruby_block "Update PostgreSQL config" do
        block do
          pg_server_command cmd
        end
      end
    end
  end
  def pg_server_command(cmd='restart')
    / \d*.\d*/ =~ `pg_config --version`
    pg_major_version = $&.strip
    # Cant use service resource as service name needs to be statically defined
    # For pg_major_version >= 9.0 the version does not appear in the name
    postgresql_ctl = File.join("", "etc", "init.d", "postgresql-#{pg_major_version}")
    #In my experience on 10.04 postgres even for 9.0 does not have the version number in its filename
    postgresql_ctl = File.join("", "etc", "init.d", "postgresql") unless File.exists? postgresql_ctl
    `#{postgresql_ctl} #{cmd}`
  end
  
  def cf_pg_update_hba_conf(db, user, ip_and_mask='0.0.0.0/0', pass_encrypt='md5', connection_type='host')
    case node['platform']
    when "ubuntu"
      ruby_block "Update PostgreSQL config for db=#{db} user=#{user} ip_and_mask=#{ip_and_mask} pass_encrypt=#{pass_encrypt} connection_type=#{connection_type}" do
        block do
          / \d*.\d*/ =~ `pg_config --version`
          pg_major_version = $&.strip

          # Update pg_hba.conf
          pg_hba_conf_file = File.join("", "etc", "postgresql", pg_major_version, "main", "pg_hba.conf")
          `grep "#{connection_type}\s*#{db}\s*#{user}" #{pg_hba_conf_file}`
          if $?.exitstatus != 0
            #append a new rule
            `echo "#{connection_type} #{db} #{user} #{ip_and_mask} #{pass_encrypt}" >> #{pg_hba_conf_file}`
          else
            #replace the rule
            
          end
          
          #no need to restart. reloading the conf is enough.
          pg_server_command 'reload'
        end
      end
    else
      Chef::Log.error("PostgreSQL config update is not supported on this platform.")
    end
  end

  def cf_pg_setup_db(db, user, passwd, privileges='NOSUPERUSER LOGIN INHERIT CREATEDB', extra_privileges='')
    case node['platform']
    when "ubuntu"
      bash "Setup PostgreSQL database #{db} with user=#{user}" do
        user "postgres"
        code <<-EOH
psql -d #{db} -c \"DROP ROLE IF EXISTS #{user}\"
psql -d #{db} -c \"CREATE ROLE #{user} WITH #{privileges} #{extra_privileges}\"
psql -d #{db} -c \"ALTER ROLE #{user} WITH ENCRYPTED PASSWORD '#{passwd}'\"
createdb #{db} --owner=#{user} --encoding=UTF8
echo \"db #{db} user #{user} pass #{passwd}\" >> #{File.join("", "tmp", "cf_pg_setup_db")}
EOH
Chef::Log.info("Code to exec for the user+his-db #{code}")
      end
    else
      Chef::Log.error("PostgreSQL database setup is not supported on this platform.")
    end
  end
  
  # extension_name: uuid-ossp, ltree
  def cf_pg_setup_extension(extension_name)
    case node['platform']
    when "ubuntu"
      bash "Setup PostgreSQL default database template with the extension #{extension_name}" do
        user "postgres"
        / \d*.\d*/ =~ `pg_config --version`
        pg_major_version = $&.strip
        if pg_major_version == '9.0'
        code <<-EOH
extension_sql_path="/usr/share/postgresql/9.0/contrib/#{extension_name}.sql"
if [ -f "$extension_sql_path" ]; then
  #tolerate already installed.
  set +e
  psql template1 -f $extension_sql_path
  if [ "ltree" = "#{extension_name}" ]; then
    psql template1 -c \"select '1.1'::ltree;\"
    exit $?
  elif [ "uuid-ossp" = "#{extension_name}" ]; then
    psql template1 -c \"select uuid_generate_v4();\"
    exit $?
  else
    exit 0
  fi
else
  echo "Warning: unable to configure the #{extension_name} extension. $extension_sql_path does not exist."
  exit 22
fi
EOH
        else
        #9.1 and more recent have a much nicer way of setting up ltree.
        #see http://www.depesz.com/index.php/2011/03/02/waiting-for-9-1-extensions/
        #see also http://crafted-software.blogspot.com/2011/10/extensions-in-postgres.html
        code <<-EOH
psql template1 -c \"CREATE EXTENSION IF NOT EXISTS \\\"#{extension_name}\\\";\"
[ 'ltree' = #{extension_name} ] && psql template1 -c \"select '1.1'::ltree;\"
[ 'uuid-ossp' = #{extension_name} ] && psql template1 -c \"select uuid_generate_v4();\"
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
      / \d*.\d*/ =~ `pg_config --version`
      pg_major_version = $&.strip
      return pg_major_version
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