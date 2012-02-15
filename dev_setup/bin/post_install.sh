#!/bin/bash
# Run a few more things we have not [yet] put into the chef recipes.

# Install vcap_common then vcap_staging.
if [ -z "$CLOUD_FOUNDRY_CONFIG_PATH" ]; then
#  echo "sourcing the cloudfoundry deployment profile and local" | tee -a $_vcap_log
  source $HOME/.cloudfoundry_deployment_local
  source $HOME/.cloudfoundry_deployment_profile
fi

cdir=`pwd`

cd $cdir
cd vcap/common
gem build vcap_common.gemspec
gem install vcap_common

cd $cdir
cd vcap/staging
gem build vcap_staging.gemspec
gem install vcap_staging

# End of vcap staging and others.

# vmc-knife:
git clone https://github.com/hmalphettes/vmc-knife.git
cd vmc-knife
gem build vmc_knife.gemspec
gem install vmc_knife

# register the new user.
vcap start router
vcap start cloud_controller
vmc register system@intalio.com --password gold
