#!/bin/bash
set -e

# Exit if not dockerrunner
if [[ $(whoami) != "dockerrunner" ]]; then
    exit 1
fi


directory="/var/dockers/HomeServerConfigs/"


cd $directory
if [[ "$2" != "no-pull" ]]; then

    GIT_SSH_COMMAND="ssh -i $directory/appdata/secret/id_rsa-dep -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no" git pull
    
fi

if [ "$1" == "server" ]; then
   $directory/compose/scripts/compose-nas.sh pull --ignore-buildable
   $directory/compose/scripts/compose-nas.sh up -d
   curl -fsS --retry 3 <YOUR HEALTHCHECK URL> > /dev/null

else
   $directory/compose/scripts/compose-portal.sh pull --ignore-buildable 
   $directory/compose/scripts/compose-portal.sh up -d
   curl -fsS --retry 3 <YOUR HEALTHCHECK URL> > /dev/null

fi

# Send healthcheck to healthchecks.io
curl -fsS --retry 3 https://health.example.com/ping/cdf1a2c0-a7ba-4f79-ae80-819d44edb59f > /dev/null
