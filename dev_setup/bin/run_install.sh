#!/bin/bash
# one script to install the whole CF with chef-solo.
# copy this script on your VM and make a runtime profile file.
# Then run it once or more until it is all installed.
# For example:
# wget -N https://raw.github.com/hmalphettes/vcap/tweaks/dev_setup/bin/run_install.sh
# chmod +x run_install.sh
# ./run_install.sh

# Update the mirror to use depending on our physical location:
UBUNTU_MIRROR=sg
[ 'us' != "$UBUNTU_MIRROR" ] && sudo sed -i -e "s/http:\/\/us\./http:\/\/$UBUNTU_MIRROR./g" /etc/apt/sources.list

[ -z "$runtime_profile" ] && runtime_profile=`pwd`/intalio.yml
if [ ! -f "$runtime_profile" ]; then
  echo "The deployment profile file $runtime_profile must exist"
fi
[ -z "$repo" ] && repo=https://github.com/hmalphettes/vcap
[ -z "$branch" ] && branch=java_start
[ -z "$services_branch" ] && services_branch=mongodb_more_params

which wget > /dev/null
[ $? != 0 ] && sudo apt-get install wget
which curl > /dev/null
[ $? != 0 ] && sudo apt-get install curl
which nano > /dev/null
[ $? != 0 ] && sudo apt-get install nano
which sfill > /dev/null
[ $? != 0 ] && sudo apt-get install secure-delete

# workaround bug for Fusion+bridged-network+wifi+Macos-Lion
# http://communities.vmware.com/message/1839059#1839059
sudo apt-get autoremove dhcp3-client
sudo apt-get install udhcpc


wget -N https://raw.github.com/hmalphettes/vcap/$branch/dev_setup/bin/vcap_dev_setup
chmod +x vcap_dev_setup

if [ -d vcap ]; then
  cd vcap
  git pull origin $branch
  cd services
  git pull origin $services_branch
  cd ..
  cd ..
fi
./vcap_dev_setup -c $runtime_profile -r $repo -b $branch -s $services_branch
rm vcap_dev_setup

echo "Once the installation has completed plase run post_install.sh"


