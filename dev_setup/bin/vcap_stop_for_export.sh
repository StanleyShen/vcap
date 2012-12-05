#!/bin/bash
# reset the password of the ubuntu user to ubuntu:
echo "Reset the ubuntu's user's password to 'ubuntu' ? (default yes)"
read response
if [ -z "$response" ]; then
   sudo sh -c 'echo ubuntu:ubuntu | chpasswd'
fi
# Make sure that the deployed apps are STAGED AND STARTED and that each of the staged droplet does exist in the file system
PSQL_RAW_RES_ARGS="-P format=unaligned -P footer=off -P tuples_only=on"
not_staged_count=`sudo -u postgres psql $PSQL_RAW_RES_ARGS -d cloud_controller -c "select count(*) from apps where package_state!='STAGED'"`
echo "Number of apps not staged: $not_staged_count"
if [ "0" != "$not_staged_count" ]; then
  echo "All apps must be 'STAGED' before the VM is exported"
  exit 1
fi
not_started_count=`sudo -u postgres psql $PSQL_RAW_RES_ARGS -d cloud_controller -c "select count(*) from apps where state!='STARTED'"`
if [ "0" != "$not_started_count" ]; then
  echo "All apps must be 'STARTED' before the VM is exported"
  exit 1
fi

if [ -f "/etc/chef/client.pem" ]; then
  echo "Delete the chef permission client.pem; required if the IP will change? (default yes)"
  read response
  if [ -z "$response" ]; then
    sudo rm /etc/chef/client.pem
  fi
fi
if [ -d "/etc/chef/validation.pem" ]; then
 echo "Delete the chef permission validation.pem; required if this will be distributed outside of intalio (default yes)?"
  read response
  if [ -z "$response" ]; then
    sudo rm -rf /etc/chef
  fi
fi
if [ -f "/etc/ssh/ssh_host_rsa_key" ]; then
  echo "Delete the /etc/ssh/ssh_host_* keys ? (default yes)"
  read response
  if [ -z "$response" ]; then
    sudo rm /etc/ssh/ssh_host_*
  fi
fi

# Make sure the recipe is clean:
if [ -d /home/ubuntu/intalio/registration_app/start_register_app.rb ]; then
  echo "Reset the vmc_knife recipe to the default (default yes)"
  read response
  if [ -z "$response" ]; then
    /home/ubuntu/intalio/registration_app/start_register_app.rb reset_manifest
  fi
fi
# Make more room:
if [ -d /home/ubuntu/intalio/boot_data ]; then
  rm -rf /home/ubuntu/intalio/boot_data
  mkdir /home/ubuntu/intalio/boot_data
fi
echo "Drop mongo's collections io_change_log Client and AccessToken ? (default yes)"
read response
if [ -z "$response" ]; then
  # drop the collections that we don't need to make some room
  vmc_knife data-drop mg_intalio Client
  vmc_knife data-drop mg_intalio AccessToken
#  vmc_knife data-drop mg_intalio localhost_index
  vmc_knife data-drop mg_intalio io_change_log
fi

sudo /etc/init.d/monit stop

cf_deployment_folder=`readlink -f $CLOUD_FOUNDRY_CONFIG_PATH/../`
$cf_deployment_folder/vcap stop

echo "Shrink mongodb's files ? (default yes)"
read response
if [ -z "$response" ]; then
  # shrink mongodb (once the mongod servers are off-line)
  vmc_knife data-shrink mg_intalio
fi

echo "Shrink vcap droplets' files ? (default yes)"
read response
if [ -z "$response" ]; then
## cleaning up the droplets
# clean-up the apps archive; assume we only care for the
# staged apps (so far experience shows that it is the case.
#
# delete the files that are not the staged files.
# we don't need them once the app has been staged.
script_dir=`dirname $0`;
if [ -f "$script_dir/../lib/clean_droplets.rb" ]; then
  # this version of clean droplets also remove the obsolete
  # staged droplets
  ruby "$script_dir/../lib/clean_droplets.rb"
else
  dir=/var/vcap/shared/droplets
  for file in `ls $dir`; do
    mime=`file -i $file`
    is_gzip=`echo $mime | grep gzip`
    if [ -z "$is_gzip" ]; then
      is_zip=`echo $mime | grep zip`
      if [ -n "$is_zip" ]; then
        echo "deleting $dir/$file because it is a zip"
        rm $dir/$file
      fi
    fi
  done
fi
## end of cleaning up the droplets.
fi

# Make sure we find the staged droplet for each staged package hash
dir=/var/vcap/shared/droplets
staged_package_hashes=`sudo -u postgres psql $PSQL_RAW_RES_ARGS -d cloud_controller -c "select staged_package_hash from apps"`
for staged_package_hash in $staged_package_hashes; do
  echo "packaged hash $staged_package_hash"
  if [ ! -f $dir/$staged_package_hash ]; then
    echo "can't find the staged package hash $dir/$staged_package_hash"
    exit 2
  fi
done

set +e
vmc_knife data-apply-privileges pg_intalio
[ -e "/var/lib/postgresql/9.0" ] && pg_version="9.0" || pg_version="9.1"
echo "Size of the postgresql DB files:"
sudo du -ch /var/lib/postgresql/$pg_version | grep total
echo "Shrink postgresql files ? (default yes)"
read response
if [ -z "$response" ]; then
  # shrink postgresql
  postgres_folder=/var/lib/postgresql/$pg_version
  touch pg_backup
  chmod o+rw pg_backup
  sudo -u postgres pg_dumpall > pg_backup
  if [ -e "/etc/init.d/postgresql" ]; then
    sudo env DISABLE_POSTGRES_UPSTART=true /etc/init.d/postgresql stop
  else
    sudo initctl stop postgresql
  fi
  sudo mv $postgres_folder/main $postgres_folder/main.old
  sudo -u postgres mkdir $postgres_folder/main
  sudo -u postgres /usr/lib/postgresql/$pg_version/bin/initdb --encoding=UTF8 --local=en_US.UTF-8 -D $postgres_folder/main
  sudo ln -s /etc/ssl/private/ssl-cert-snakeoil.key /var/lib/postgresql/$pg_version/main/server.key
  sudo ln -s /etc/ssl/certs/ssl-cert-snakeoil.pem /var/lib/postgresql/$pg_version/main/server.crt
  sudo cp /var/lib/postgresql/$pg_version/main/postgresql.conf .
  sudo rm /var/lib/postgresql/$pg_version/main/postgresql.conf
## this does not work yet?
  # start postgresql without emitting the upstart daemon starting/started events which would make vcap start again.
  #sudo /usr/lib/postgresql/$pg_version/bin/postgres -D /var/lib/postgresql/$pg_version/main
if [ -e "/etc/init.d/postgresql" ]; then
  sudo env DISABLE_POSTGRES_UPSTART=true /etc/init.d/postgresql start
else
  sudo initctl start postgresql
fi
echo "Let's make sure we can connect to postgres"
  set +e
  PSQL_RAW_RES_ARGS="-P format=unaligned -P footer=off -P tuples_only=on"
  COUNTER=0
  while [ $COUNTER -lt 20 ]; do
    sudo -u postgres psql -e -c "select 1" $PSQL_RAW_RES_ARGS
    psql_exit_status=$?
    res=`sudo -u postgres psql -c "select 1" $PSQL_RAW_RES_ARGS | tr -d '\n'`
    if [ "$psql_exit_status" = "0" -a "$res" = "1" ]; then
      [ $COUNTER != "0" ] && echo "Postgresql is available"
      COUNTER=40
    else
      [ "$psql_exit_status" = "0" ] && echo "ex st is 0" || echo "ex st is not 0 it is $psql_exit_status"
      [ "$res" = "1" ] && echo "res is 1 it is $res" || echo "res is not 1 it is $res"
      echo "[ $COUNTER ] Postgresql is not available yet: $psql_exit_status -  $res."
      COUNTER=`expr $COUNTER + 1`
      echo "new counter $COUNTER"
      sleep 5
    fi
  done

  sudo -u postgres psql -f pg_backup postgres
  # end of shrink postgresql
  sudo -u postgres psql -c "\l"
  echo "  New size of the postgresql DB files after the shrinking:"
  sudo du -ch /var/lib/postgresql/$pg_version/main | grep total
  echo "Everything looking good enough? Delete the postgres backup and old DB folders? (default yes)"
  read response
  if [ -z "$response" ]; then
    sudo rm -rf $postgres_folder/main.old
    sudo rm postgresql.conf
    sudo rm pg_backup
  else
    echo "pg_dump all is here "`pwd`"pg_backup"
    echo "old postgres DB folder is here $postgres_folder/main.old"
    echo "Good luck restoring everything."
    exit 1
  fi
fi

# the rest is fast and innocent let it happen without further questioning
if [ -e "/etc/init.d/postgresql" ]; then
  sudo env DISABLE_POSTGRES_UPSTART=true /etc/init.d/postgresql stop
else
  sudo initctl stop postgresql
fi
sudo /etc/init.d/nats_server stop
sudo /etc/init.d/redis-server stop

sudo apt-get autoremove -y --force-yes
sudo apt-get clean
sudo apt-get autoclean

rm -rf /home/ubuntu/cloudfoundry/backup
sudo rm -rf /var/www/nginx/logs/*
echo "delete the  .git folders of vcap sources (default yes) ?"
read response
if [ -z "$response" ]; then
  echo "Deleting the .git folders of vcap and its sub-modules"
  rm -rf ~/cloudfoundry/vcap/.git
  rm -rf ~/cloudfoundry/vcap/java/.git
  rm -rf ~/cloudfoundry/vcap/services/.git
fi

sudo -i which rvm > /dev/null
if [ $? -eq 0 ]; then
 echo "delete the rvm and ruby for root user (default yes) ?"
 read response
 if [ -z "$response" ]; then
   sudo -i rvm remove default
   echo "yes" | sudo -i rvm implode
   sudo rm /etc/rvmrc /root/.rvmrc
 fi 
fi

rm -rf ~/cloudfoundry/vcap/tests
rm ~/cloudfoundry/log/*
rm -rf ~/.cache
rm -rf ~/.bash_history
rm -rf ~/.nano_history
rm -rf ~/vmc_knife_downloads
sudo rm -rf /var/vcap.local/dea/apps/*
sudo rm -rf /var/vcap.local/staging/*
rm -rf /var/vcap/services/mongodb/logs/
rm -rf /var/vcap/services/mongodb/instances/*/data/journal/
rm -rf /var/vcap/shared/resources/*
sudo rm /var/log/*.[0-9].gz
sudo rm /var/log/*.[0-9]
sudo rm /var/cache/apt/srcpkgcache.bin
sudo rm /var/cache/apt/pkgcache.bin
sudo rm -rf /var/lib/apt/lists/*
sudo rm -rf /var/chef/cache/*
sudo rm -rf /var/log/apache2/*
swp_file=/tmp/simple_swap.swap
if [ -e $swp_file ]; then
	sudo swapoff $swp_file
  sudo rm $swp_file
fi
sudo rm -f /etc/udev/rules.d/70-persistent-net.rules
df -h
echo "Secure delete (required before we can export the VM image) default yes?"
read response
if [ -z "$response" ]; then
sudo sfill -v -f -z -l  /
  echo "All ready to export from the hypervisor. Shutdown now?"
  read response
  if [ -z "$response" ]; then
    sudo poweroff
  fi
fi


