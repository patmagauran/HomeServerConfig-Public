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
    echo "Directory $HOMESERVERDIR does not exist, please create it and then run this script again"
    exit
fi

DOCKERUSER=$(id -u dockeruser)
DOCKERRUNNER=$(id -u dockerrunner)
DOCKERFILES=$(getent group dockerfiles | cut -d: -f3)
DOCKERRUNNERGRP=$(getent group dockerrunner | cut -d: -f3)

DBDIR=/mnt/data/db

chown -R $DOCKERUSER:$DOCKERFILES $DBDIR

chmod -R u=rwX,g=rX,o=X $DBDIR
chmod -R g+X $DBDIR
chmod -R o+X $DBDIR
chmod -R u+X $DBDIR

chown -R $DOCKERRUNNER:$DOCKERFILES $HOMESERVERDIR
chmod -R u=rwX,g=rwX,o=X $HOMESERVERDIR
chmod -R g+X $HOMESERVERDIR
chmod -R o+X $HOMESERVERDIR
chmod -R u+X $HOMESERVERDIR

chown -R $DOCKERUSER:$DOCKERFILES /backups/
chmod -R u=rwX,g=rwX,o=X /backups/
chown -R $DOCKERUSER:$DOCKERFILES /mnt/data/backups/
chmod -R u=rwX,g=rwX,o=X /mnt/data/backups/

# chown -R DOCKERRUNNER:dockerfiles /mnt/data/db
# chmod -R 640 /mnt/data/db

chown -R $DOCKERUSER:$DOCKERFILES $HOMESERVERDIR/appdata/secret/
chmod -R u=rwX,g=rwX,o= $HOMESERVERDIR/appdata/secret/

chown $DOCKERUSER:$DOCKERFILES $HOMESERVERDIR/appdata/secret/traefik2/acme/acme.json
chmod 600 $HOMESERVERDIR/appdata/secret/traefik2/acme/acme.json

chown 1000:$DOCKERFILES $HOMESERVERDIR/appdata/secret/id_rsa
chown 1000:$DOCKERFILES $HOMESERVERDIR/appdata/secret/id_rsa.pub
cp $HOMESERVERDIR/appdata/secret/id_rsa $HOMESERVERDIR/appdata/secret/id_rsa-dep
cp $HOMESERVERDIR/appdata/secret/id_rsa $HOMESERVERDIR/appdata/secret/id_rsa-dep.pub
chown $DOCKERRUNNER:$DOCKERRUNNERGRP $HOMESERVERDIR/appdata/secret/id_rsa-dep
chown $DOCKERRUNNER:$DOCKERRUNNERGRP $HOMESERVERDIR/appdata/secret/id_rsa-dep.pub
chown 1000:$DOCKERFILES $HOMESERVERDIR/appdata/secret/id_rsa.pub
chmod u=rwX,g=,o= $HOMESERVERDIR/appdata/secret/id_rsa
chmod u=rwX,g=,o= $HOMESERVERDIR/appdata/secret/id_rsa-dep

chown -R $DOCKERUSER:$DOCKERFILES $HOMESERVERDIR/appdata/nongit/recipes
chmod -R u=rwX,g=rwX,o=X $HOMESERVERDIR/appdata/nongit/recipes

chown -R www-data:www-data $HOMESERVERDIR/appdata/nongit/nextcloud

chmod -R o+rwX $HOMESERVERDIR/appdata/nongit/nextcloud
chown -R 1000:$DOCKERFILES $HOMESERVERDIR/appdata/nongit/wud


chmod -R o+rX $HOMESERVERDIR/appdata/nonsecret/
#chmod -R o+r $HOMESERVERDIR/appdata/secret/google_oauth_config

chown -R $DOCKERRUNNER:$DOCKERRUNNERGRP $HOMESERVERDIR/compose
chmod -R u=rwX,g=rX,o=X $HOMESERVERDIR/compose
chmod -R u=rwX,g=rwX,o= $HOMESERVERDIR/compose/scripts

chown -R $DOCKERRUNNER:$DOCKERRUNNERGRP $HOMESERVERDIR/apps
chmod -R u=rwX,g=rX,o=X $HOMESERVERDIR/apps

chown -R $DOCKERRUNNER:$DOCKERRUNNERGRP $HOMESERVERDIR/deployment
chmod -R u=rwX,g=rX,o=X $HOMESERVERDIR/deployment

chmod -R g+X $HOMESERVERDIR
chmod -R u+X $HOMESERVERDIR


chown $DOCKERUSER:root /run/wolServer/WakeOnLanPipe
