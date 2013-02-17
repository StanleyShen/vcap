#!/bin/bash

echo "update aptitude and install chinese font"
sudo aptitude update
sudo apt-get install fonts-arphic-uming -y

echo "remove useless packages for release"
sudo apt-get purge autoconf automake autotools-dev binutils build-essential cmap-adobe-japan1 comerr-dev consolekit cpp cpp-4.6 cryptsetup-bin dbus-x11 dconf-gsettings-backend dconf-service dpkg-dev fakeroot fontconfig g++ g++-4.6 gcc gcc-4.6 gconf-service gconf-service-backend gconf2 gconf2-common ghostscript gs-cjk-resource gsfonts gvfs gvfs-common gvfs-daemons gvfs-libs hicolor-icon-theme icedtea-7-jre-jamvm iftop imagemagick-common krb5-multidev libalgorithm-diff-perl libalgorithm-diff-xs-perl libalgorithm-merge-perl libasound2 libasyncns0 libatasmart4 libatk-wrapper-java libatk-wrapper-java-jni libatk1.0-0 libatk1.0-data libavahi-glib1 libbonobo2-0 libbonobo2-common libc-dev-bin libc6-dev libcairo-gobject2 libcairo2 libcanberra0 libck-connector0 libcryptsetup4 libcupsimage2 libcurl4-openssl-dev libdatrie1 libdconf0 libdevmapper-event1.02.1 libdpkg-perl libffi-dev libflac8 libfontenc1 libgconf-2-4 libgconf2-4 libgcrypt11-dev libgdk-pixbuf2.0-0 libgdk-pixbuf2.0-common libgdu0 libgif4 libgl1-mesa-dri libgl1-mesa-glx libglapi-mesa libgnome-keyring-common libgnome-keyring0 libgnome2-0 libgnome2-bin libgnome2-common libgnomevfs2-0 libgnomevfs2-common libgnutls-dev libgnutls-openssl27 libgnutlsxx27 libgomp1 libgpg-error-dev libgs9 libgs9-common libgssrpc4 libgtk-3-0 libgtk-3-bin libgtk-3-common libgtk2.0-0 libgtk2.0-bin libgtk2.0-common libice-dev libice6 libidl-common libidl0 libidn11-dev libijs-0.35 libjasper1 libjbig2dec0 libjson0 libkadm5clnt-mit8 libkadm5srv-mit8 libkdb5-6 libkrb5-dev liblcms1 libldap2-dev libllvm3.0 liblqr-1-0 libltdl-dev libltdl7 liblvm2app2.2 libmagickcore4 libmpc2 libmpfr4 libncurses5-dev libnss-mdns libogg0 liborbit2 libp11-kit-dev libpam-ck-connector libpango1.0-0 libpaper-utils libpaper1 libpixman-1-0 libpolkit-agent-1-0 libpolkit-backend-1-0 libpq-dev libpthread-stubs0 libpthread-stubs0-dev libpulse0 libquadmath0 libreadline6-dev librmagick-ruby librtmp-dev libsgutils2-2 libsm-dev libsm6 libsndfile1 libsqlite3-dev libssl-dev libssl-doc libstdc++6-4.6-dev libtasn1-3-dev libtdb1 libthai-data libthai0 libtiff4 libtinfo-dev libtool libvorbis0a libvorbisenc2 libvorbisfile3 libx11-dev libx11-doc libx11-xcb1 libxau-dev libxaw7 libxcb-glx0 libxcb-render0 libxcb-shape0 libxcb-shm0 libxcb1-dev libxcomposite1 libxcursor1 libxdamage1 libxdmcp-dev libxfixes3 libxft2 libxi6 libxinerama1 libxml2-dev libxmu6 libxpm4 libxrandr2 libxrender1 libxslt1-dev libxt-dev libxt6 libxtst6 libxv1 libxxf86dga1 libxxf86vm1 libyaml-dev linux-libc-dev make manpages-dev mtools openjdk-7-jdk openjdk-7-jre pkg-config policykit-1 policykit-1-gnome postgresql-server-dev-9.1 python-avahi ruby ruby-dev ruby-rmagick ruby1.8-dev shared-mime-info sound-theme-freedesktop ttf-dejavu-extra udisks x11-common x11-utils x11proto-core-dev x11proto-input-dev x11proto-kb-dev xorg-sgml-doctools xtrans-dev zlib1g-dev vim vim-runtime geoip-database

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

echo "delete all soft-deleted record and update object count"
# delete all soft-delete records and update object count
vmc_knife data-shell pg_intalio -c "select io_function_find_deleted_records(TRUE);"
vmc_knife data-shell pg_intalio -c "select io_function_update_object_record();"

echo "update last access application to null"
# set last access application to null 
vmc_knife data-shell pg_intalio -c "update io_user_parameter set io_last_accessed_application = null;"


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

# let go to remove some unused packages
echo "start to remvoe some unused packages"
sudo apt-get remove mysql-common -y
sudo apt-get remove subversion -y
sudo apt-get remove apt-xapian-index -y
sudo apt-get remove python-xapian -y

# disable grub menu
sudo sed -i  -e 's/#\(GRUB_HIDDEN_TIMEOUT=\)/\1/' -e 's/#\(GRUB_HIDDEN_TIMEOUT_QUIET=\)/\1/' /etc/default/grub
sudo update-grub2
# remove previous linux image
dpkg -l 'linux-*' | sed '/^ii/!d;/'"$(uname -r | sed "s/\(.*\)-\([^0-9]\+\)/\1/")"'/d;s/^[^ ]* [^ ]* \([^ ]*\).*/\1/;/[0-9]/!d' | xargs sudo apt-get -y purge

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
   sudo rm -rf /root/.gem
 fi 
fi

rm -rf ~/cloudfoundry/vcap/tests
rm ~/cloudfoundry/log/*
sudo rm ~/cloudfoundry/log/nginx/*
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
sudo rm -rf /var/cache/apt-xapian-index
sudo rm -rf /var/lib/apt/lists/*
sudo rm -rf /var/chef/cache/*
sudo rm -rf /var/log/apache2/*
swp_file=/tmp/simple_swap.swap
if [ -e $swp_file ]; then
	sudo swapoff $swp_file
  sudo rm $swp_file
fi
sudo rm -f /etc/udev/rules.d/70-persistent-net.rules

# change vm hostname to intalio-create
sudo -i echo "intalio-create" > /etc/hostname
sudo sed  -i  '/intalio-create/!s/^127.0.1.1 .*/& intalio-create/' /etc/hosts

#change log level to error
configdir=~/cloudfoundry/config
for file in $(ls $configdir/*.yml)
do
 sed -i 's/level: debug2/level: warn/g' $file
 sed -i 's/level: debug/level: warn/g' $file
 sed -i 's/level: info/level: warn/g' $file
done

cat $configdir/*.yml | grep level

# turn off vmc
sed -i 's/allow_registration: true/allow_registration: false/g' $configdir/cloud_controller.yml

postgres_conf=/etc/postgresql/9.1/main/postgresql.conf

echo "We need update postgresql for below changes"
echo "1. update shared_buffers to 64MB"
echo "2. update checkpoint_segments to 5"
echo "3. update log_min_duration_statement to 2000"
echo "4. update listen_address to *"
echo "5. update kernel.shmmax = 572121088"
echo "After script, the result are:"
# update shared buffer to 64MB
sudo sed -i '/shared_buffers/d' ${postgres_conf}
sudo sh -c "echo 'shared_buffers = 64MB     # min 128kB' >> ${postgres_conf}"
cat ${postgres_conf} | grep "shared_buffers"

# update checkpoint_segments to 5
sudo sed -i '/checkpoint_segments/d' ${postgres_conf}
sudo sh -c "echo 'checkpoint_segments = 5    # in logfile segments, min 1, 16MB each' >> ${postgres_conf}"
cat ${postgres_conf} | grep "checkpoint_segments"

# update log_min_duration_statement to 2000
sudo sed -i '/log_min_duration_statement/d' ${postgres_conf}
sudo sh -c "echo 'log_min_duration_statement = 2000    # -1 is disabled, 0 logs all statements ' >> ${postgres_conf}"
cat ${postgres_conf} | grep "log_min_duration_statement"

#update listen address to *
sudo sed -i '/listen_address/d' ${postgres_conf}
sudo sh -c "echo listen_addresses=\'*\' >> ${postgres_conf}"
cat ${postgres_conf} | grep "listen_address"

# update /etc/sysctl.conf to add  kernel.shmmax=572121088
sudo sed -i '/kernel.shmmax/d' /etc/sysctl.conf
sudo sh -c "echo 'kernel.shmmax=572121088' >> /etc/sysctl.conf"
cat /etc/sysctl.conf | grep "kernel.shmmax"


# delete some history file to make it clean
rm ~/.bashrc.swp
rm ~/.*_history

echo "update VM time"
sudo ntpdate pool.ntp.org


df -h
echo "Secure delete (required before we can export the VM image) default yes?"
read response
if [ -z "$response" ]; then
sudo sfill -v -f -z -l  /
  echo "All ready to export from the hypervisor. Shutdown now?"
  read response
  if [ -z "$response" ]; then
    history -c
    sudo poweroff
  fi
fi
