#!/bin/bash
# one script to install the whole CF with chef-solo.
# copy this script on your VM and make a runtime profile file.
# Then run it once or more until it is all installed.
# For example:
# wget -N https://raw.github.com/hmalphettes/vcap/tweaks/dev_setup/bin/run_install.sh
# chmod +x run_install.sh
# ./run_install.sh

[ -z "$runtime_profile" ] && runtime_profile=intalio.yml
if [ ! -f "$runtime_profile" ]; then
  echo "The deployment profile file $runtime_profile must exist"
fi
[ -z "$repo" ] && repo=https://github.com/hmalphettes/vcap
[ -z "$branch" ] && branch=java_start

which wget > /dev/null
[ $? != 0 ] && sudo apt-get install wget
which curl > /dev/null
[ $? != 0 ] && sudo apt-get install curl
which nano > /dev/null
[ $? != 0 ] && sudo apt-get install nano

wget -N https://raw.github.com/hmalphettes/vcap/java_start/dev_setup/bin/vcap_dev_setup
chmod +x vcap_dev_setup

if [ -d vcap ]; then
  cd vcap
  git pull origin $branch
  cd ..
fi
./vcap_dev_setup -c $runtime_profile -r $repo -b $branch
rm vcap_dev_setup

