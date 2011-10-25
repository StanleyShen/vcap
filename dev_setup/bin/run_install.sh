#!/bin/bash
# one script to install the whole CF with chef-solo.
# copy this script on your VM and make a runtime profile file.
# Then run it once or more until it is all installed.
# For example:
# wget -N https://raw.github.com/hmalphettes/vcap/tweaks/dev_setup/bin/run_install.sh
# chmod +x run_install.sh
# ./run_install.sh

[ -z "$runtime_profile" ] && runtime_profile=micro_intalio_cf.yml
if [ ! -f "$runtime_profile" ]; then
  echo "The deployment profile file $runtime_profile must exist"
fi
[ -z "$repo" ] && repo=https://github.com/hmalphettes/vcap
[ -z "$branch" ] && branch=tweaks

#if vmc is not set also set a few more packages.
which vmc > /dev/null
if [ $? == 0 ]; then
  sudo apt-get install wget curl
  sudo apt-get install nano
  sudo apt-get install ruby rubygems

  #smooth things out for vmc to install on the first try:
  sudo gem install mime-types
  sudo gem install rubyzip2
  sudo gem install terminal-table
  sudo gem install json_pure --version "1.5.1"
  sudo gem install vmc --version "0.3.13.beta.4" #or later (or the stable one)
fi
which vmc > /dev/null
if [ $? == 0 ]; then
  echo "the vmc gem was not installed correctly. Please try again or explicitly install the dependent gems missing"
  exit 2
fi
which rake > /dev/null
[ $? == 0 ] && sudo gem install rake

wget -N https://raw.github.com/hmalphettes/vcap/tweaks/dev_setup/bin/vcap_dev_setup
chmod +x vcap_dev_setup

if [ -d vcap ]; then
  cd vcap
  git pull origin $branch
  cd ..
fi
./vcap_dev_setup -c $runtime_profile -r $repo -b $branch
rm vcap_dev_setup

