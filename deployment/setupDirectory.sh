#!/bin/bash

#exit if not root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

DOCKERDIR="/var/dockers/"
HOMESERVERDIR="$DOCKERDIR/HomeServerConfigs"

# Ensure the directory exists, fail if not
if [ ! -d "$HOMESERVERDIR" ]; then
    echo "You need to manually clone the repo and then copy the file to /var/dockers/HomeServerConfigs"
    exit
fi

DOCKERRUNNER=$(id -u dockerrunner)
DOCKERFILES=$(getent group dockerfiles | cut -d: -f3)

# Append the DOCKERRUNNER, runner, and group to the env file
echo "DOCKERRUNNER=$DOCKERRUNNER" >> $HOMESERVERDIR/compose/.env
echo "DOCKERFILES=$DOCKERFILES" >> $HOMESERVERDIR/compose/.env
mkdir /backups/
mkdir -p $HOMESERVERDIR/appdata/nonsecret
mkdir -p $HOMESERVERDIR/appdata/secret
mkdir -p $HOMESERVERDIR/appdata/nongit
mkdir -p $HOMESERVERDIR/appdata/secret/traefik2/acme/
touch $HOMESERVERDIR/appdata/secret/traefik2/acme/acme.json

touch $HOMESERVERDIR/appdata/nongit/traefik2/traefik.log

mkdir -p /mnt/data/db/redis/data
echo "You should add the secrets and ssh deploy keys."
