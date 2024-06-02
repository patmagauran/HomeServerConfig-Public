#!/bin/bash



# if [ "$1" == "server" ]; then
#     directory="/var/dockers/HomeServerConfigs/compose/"
#     filesArgs="-f docker-compose-core-nas.yml -f docker-compose-apps-nas.yml -f docker-compose-management-nas.yml -f docker-compose-db-nas.yml"
# else
directory="/var/dockers/HomeServerConfigs/compose"
filesArgs="-f docker-compose-core-nas.yml -f docker-compose-apps-nas.yml -f docker-compose-management-nas.yml -f docker-compose-db-nas.yml"
# fi
cd $directory



# Then pull and start docker compose
#docker-compose $filesArgs pull

docker compose $filesArgs $@

# Send healthcheck to healthchecks.io
