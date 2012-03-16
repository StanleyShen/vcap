module CloudFoundryPostgres
  PSQL_RAW_RES_ARGS="-P format=unaligned -P footer=off -P tuples_only=on"  
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
    Chef::Log.warn "Issuing #{postgresql_ctl} #{cmd}"
    Chef::Log.warn `#{postgresql_ctl} #{cmd}`
    Chef::Log.warn "Returned from #{postgresql_ctl} #{cmd}"
  end
  
  def cf_pg_update_hba_conf(db, user, ip_and_mask=nil, pass_encrypt='md5', connection_type='host')
    ip_and_mask='0.0.0.0/0' if ip_and_mask.nil? || ip_and_mask.strip.empty?
    case node['platform']
    when "ubuntu"
      ruby_block "Update PostgreSQL config for db=#{db} user=#{user} ip_and_mask=#{ip_and_mask} pass_encrypt=#{pass_encrypt} connection_type=#{connection_type}" do
        block do
          pg_config_version=`pg_config --version`.strip
          raise "pg_config --version did not return a thing" unless pg_config_version
          / \d*.\d*/ =~ pg_config_version
          pg_major_version = $&.strip

          # Update pg_hba.conf
          pg_hba_conf_file = File.join("", "etc", "postgresql", pg_major_version, "main", "pg_hba.conf")
          Chef::Log.warn("About to execute. grep \"#{connection_type}\s*#{db}\s*#{user}\s*#{ip_and_mask}\s*#{pass_encrypt}\" #{pg_hba_conf_file}")
          `grep "#{connection_type}\s*#{db}\s*#{user}\s*#{ip_and_mask}\s*#{pass_encrypt}" #{pg_hba_conf_file}`
          if $?.exitstatus != 0
            #append a new rule
            Chef::Log.warn(" could not find it... adding it then")
            `echo "#{connection_type} #{db} #{user} #{ip_and_mask} #{pass_encrypt}" >> #{pg_hba_conf_file}`
          else # nothing to do.
            Chef::Log.warn(" ok it was already there")
            #replace the rule
            #`sed -i -e "s/^#{connection_type}[[:space:]]*#{db}[[:space:]]*#{user}[[:space:]].*$/#{connection_type} #{db} #{user} #{ip_and_mask} #{pass_encrypt}/g" #{pg_hba_conf_file}`
          end

          #no need to restart. reloading the conf is enough.
          Chef::Log.warn(" issuing the reload command")
          pg_server_command 'reload'
        end
      end
    else
      Chef::Log.error("PostgreSQL config update is not supported on this platform.")
    end
  end

  # Creates a new DB, new user that owns it
  # the user is granted other privileges.
  # @param privileges When nil or undefined, then 'NOSUPERUSER LOGIN INHERIT'
  # @param extra_privileges More privileges to add to the default ones
  def cf_pg_setup_db(db, user, passwd, privileges=nil, extra_privileges='', template='template1', extra_sql_statements=[])
    case node['platform']
    when "ubuntu"
      bash "Setup PostgreSQL database #{db} with user=#{user}" do
        user "postgres"
        privileges = 'NOSUPERUSER LOGIN INHERIT' if privileges.nil?
        extra_sql_statements_str = extra_sql_statements.collect do |statement|
          "echo \"About to execute "+statement+"\"\n psql -c '"+statement+"'"
        end.join("\n")
        #This bash script tolerates existings roles and databases,
        #does not remove extra privileges and try to apply the passed privileges.
        code <<-EOH
set +e
echo "About to execute select count(*) from pg_roles where rolname='#{user}'"
already=`psql #{PSQL_RAW_RES_ARGS} -c \"select count(*) from pg_roles where rolname='#{user}'\"`
if [ -z "$already" -o "0" = "$already" ]; then
  psql -c \"CREATE ROLE #{user} WITH LOGIN NOSUPERUSER\"
fi
if [ -z "$dont_alter_existing_role"  ]; then
  psql -c \"ALTER ROLE #{user} WITH ENCRYPTED PASSWORD '#{passwd}'\"
  psql -c \"ALTER ROLE #{user} WITH #{privileges} #{extra_privileges}\"
fi
echo "About to execute select count(*) from pg_database where datname='#{db}'"
psql #{PSQL_RAW_RES_ARGS} -c \"select count(*) from pg_database where datname='#{db}'\"
already_db=`psql #{PSQL_RAW_RES_ARGS} -c \"select count(*) from pg_database where datname='#{db}'\"`
echo "already_db $already_db"
if [ "$already_db" = "1" ]; then
  psql -c \"ALTER DATABASE #{db} OWNER TO #{user}\"
else
  psql -c \"CREATE DATABASE #{db} OWNER=#{user} TEMPLATE=#{template}\"
fi
#{extra_sql_statements_str}
EOH
Chef::Log.warn("Code to exec for the user+his-db #{code}")
      end
    else
      Chef::Log.error("PostgreSQL database setup is not supported on this platform.")
    end
  end
  
  # Create or Re-create a template with the proper encoding; 
  # Experience shows we can't trust always the default encoding and locale.
  def cf_pg_setup_template(template_db_name='template1', encoding='UTF8', locale=nil)
    locale||=ENV["$LANG"]
    locale||='en_US.UTF-8' # we might be in trouble if we are here. postgres will let us know.
    raise "The locale #{locale} does not use UTF." unless /UTF/ =~ locale
        
    #CREATE DATABASE template1 with TEMPLATE template0 ENCODING 'UTF8' LC_COLLATE 'en_US.UTF-8' LC_CTYPE 'en_US.UTF-8';
    case node['platform']
    when "ubuntu"
      bash "Create a template #{template_db_name} database with the proper encoding #{encoding} and locale #{locale}." do
        user "postgres"
        code <<-EOH
set +e
# see if the encoding is already correct (the following could be improved)
already=`psql -c "\\l"  | grep #{template_db_name} | grep #{encoding}`
if [ -n "$already" ]; then
  echo "The template #{template_db_name} is already set with the proper encoding. No need to re-create it."
  exit 0
fi

psql -c \"UPDATE pg_database SET datistemplate = FALSE WHERE datname = '#{template_db_name}'\"
psql -c \"DROP DATABASE IF EXISTS #{template_db_name}\"
psql -c \"CREATE DATABASE #{template_db_name} TEMPLATE=template0 ENCODING '#{encoding}' LC_COLLATE '#{locale}' LC_CTYPE '#{locale}'\"
if [ $? != 0 ]; then
  echo "Unable to create the template database with the command CREATE DATABASE #{template_db_name} TEMPLATE=template0 ENCODING '#{encoding}' LC_COLLATE '#{locale}' LC_CTYPE '#{locale}'"
  exit 1
fi
psql -c \"UPDATE pg_database SET datistemplate = TRUE WHERE datname = '#{template_db_name}'\"
echo "done"
EOH
Chef::Log.warn("Code to create the template #{template_db_name} #{code}")
# The mysterious 'SET datistemplate' allow anyone to copy the database. and also allows us to drop ther database.
# See http://stackoverflow.com/questions/418935/trashed-postgres-template1
#     and http://blog.endpoint.com/2010/05/postgresql-template-databases-to.html
# No need for those: that is already part of template0.
#9.0: #psql #{template_db_name} -c \"CREATE OR REPLACE PROCEDURAL LANGUAGE plpgsql;\"
#9.1: #psql #{template_db_name} -c \"CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;\"
      end
    else
      Chef::Log.error("PostgreSQL database setup is not supported on this platform.")
    end
  end
  
  # extension_name: uuid-ossp, ltree
  def cf_pg_setup_extension(extension_name,db_template_name='template1')
    case node['platform']
    when "ubuntu"
      bash "Setup PostgreSQL database template #{db_template_name} with the extension #{extension_name}" do
        user "postgres"
        / \d*.\d*/ =~ `pg_config --version`
        pg_major_version = $&.strip
        if pg_major_version == '9.0'
        code <<-EOH
extension_sql_path="/usr/share/postgresql/9.0/contrib/#{extension_name}.sql"
if [ -f "$extension_sql_path" ]; then
  #tolerate already installed.
  set +e
  psql #{db_template_name} -f $extension_sql_path
  if [ "ltree" = "#{extension_name}" ]; then
    psql #{db_template_name} -c \"select '1.1'::ltree;\"
    exit $?
  elif [ "uuid-ossp" = "#{extension_name}" ]; then
    psql #{db_template_name} -c \"select uuid_generate_v4();\"
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
set +e
extension_already_installed_exit_code=11
if [ 'ltree' = #{extension_name} ]; then
  psql #{db_template_name} -c \"select '1.1'::ltree;\"
  extension_already_installed_exit_code=$?
elif [ 'uuid-ossp' = #{extension_name} ]; then
  psql #{db_template_name} -c \"select uuid_generate_v4();\"
  extension_already_installed_exit_code=$?
fi
if [ "$extension_already_installed_exit_code" = 0 ]; then
  echo "The extension #{extension_name} is already installed"
  exit 0
fi
echo "The extension #{extension_name} is not already installed $extension_already_installed_exit_code"
psql template1 -c \"CREATE EXTENSION IF NOT EXISTS \\\"#{extension_name}\\\";\"
psql template1 -c \"GRANT ALL ON ALL FUNCTIONS IN SCHEMA PUBLIC TO PUBLIC\"
if [ 'ltree' = #{extension_name} ]; then
  psql #{db_template_name} -c \"select '1.1'::ltree;\"
elif [ 'uuid-ossp' = #{extension_name} ]; then
  psql #{db_template_name} -c \"select uuid_generate_v4();\"
fi
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