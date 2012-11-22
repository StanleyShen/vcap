#!/bin/bash
# Run a few more things we have not [yet] put into the chef recipes.

# Install vcap_common then vcap_staging.
if [ -z "$CLOUD_FOUNDRY_CONFIG_PATH" ]; then
#  echo "sourcing the cloudfoundry deployment profile and local" | tee -a $_vcap_log
  source $HOME/.cloudfoundry_deployment_local
  source $HOME/.cloudfoundry_deployment_profile
fi

cdir=`dirname $0`/../../

cd $cdir
cd vcap/common
gem build vcap_common.gemspec
gem install vcap_common

cd $cdir
cd vcap/staging
gem build vcap_staging.gemspec
gem install vcap_staging

# End of vcap staging and others.

# ccdb init:
cd $cdir
vcap/dev_setup/bin/vcap_ccdb_rake_migrate

# vmc-knife:
git clone https://github.com/intalio/vmc-knife.git
cd vmc-knife
gem build vmc_knife.gemspec
gem install vmc_knife

# register the new user.
vcap start router
vcap start cloud_controller
vmc target api.intalio.priv:9022
vmc register system@intalio.com --password gold
