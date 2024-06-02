# Part 7 - The NAS


One of the biggest advantages of self hosting is not needing to pay to store all of your files on a cloud(but you do have to deal with the risk of data loss). For my "NAS" software, I use nextcloud. Its fairly straightforward to use and works very similar to OneDrive in terms of client experience. However, setting it up in docker is a bit finnicky.


# Docker file 1: The Databases
```
version: "3.9"
########################### NETWORKS
networks:
  db_net:
    name: db_net
    driver: bridge
    ipam:
      config:
        - subnet: 172.16.2.0/24
########################### SECRETS
secrets:
  redisconf:
    file: $SECRETDIR/redisconf
  mysql_root_password:
    file: $SECRETDIR/mysql_root_password
########################### SERVICES
services:
 ############################# DATABASE

  # MariaDB - MySQL Database
  # After starting container for first time dexec and mysqladmin -u root password <password>
  mariadb:
    container_name: mariadb
    image: linuxserver/mariadb:latest
    restart: always
    # profiles:
    # - core
    #read_only: true
    security_opt:
      - no-new-privileges:true
    networks:
      - db_net
    volumes:
      - /mnt/data/db/mariadb:/config
      - /run
    environment:
      - PUID=$DOCKERRUNNER
      - PGID=$DOCKERFILES
      - TZ=$TZ
      - FILE__MYSQL_ROOT_PASSWORD=/run/secrets/mysql_root_password # Note FILE__ (double underscore) - Issue #127
    secrets:
      - mysql_root_password
    labels:
      - wud.tag.include=^\d+\.\d+\.\d+$$
      - wud.link.template=https://newreleases.io/linuxserver/docker-mariadb
      - wud.watch.digest=true
  # Redis - Key-value Store
  redis:
    container_name: redis
    image: redis:7.2.4
    restart: always
    secrets:
      - redisconf
    # profiles:
    # - core
    entrypoint: redis-server /run/secrets/redisconf
    networks:
      - db_net
    user: $DOCKERRUNNER:$DOCKERFILES
    read_only: true
    security_opt:
      - no-new-privileges:true
    volumes:
      - /mnt/data/db/redis/data:/data
      # - /etc/timezone:/etc/timezone:ro
      # - /etc/localtime:/etc/localtime:ro
    labels:
      - wud.link.template=https://newreleases.io/dockerhub/redis
      - wud.watch.digest=true
      - wud.tag.include=^\d+\.\d+\.\d+$$
```
Again not much to say about these containers. We setup a postgres and redis database using reasonable and secure settings.

# Docker File 2: The nextcloud
```
version: "3.9"
########################### SECRETS
secrets:
  mysql_root_password:
    file: $SECRETDIR/mysql_root_password
########################### SERVICES
services:
  # Dashboard - Frontend
  

  nextcloud:
    container_name: nextcloud
    image: nextcloud:28-apache
    restart: always
  ##  user: $DOCKERRUNNER:$DOCKERFILES
    healthcheck:
      test: curl -sSf 'http://localhost/status.php' | grep '"installed":true' || exit 1
      interval: 10s
      timeout: 30s
      retries: 10
    depends_on:
      - traefik
    #read_only: true
    security_opt:
      - no-new-privileges:true
    networks:
      - net-t2-proxy
      - db_net
#    ports:
#      - "443:443"
    volumes:
      - $NONGITDIR/nextcloud:/var/www/html
      - /mnt/data/nextcloudData:/data
      - /mnt/data/media:/media_data
    environment:
      - TZ=$TZ
      - NEXTCLOUD_TRUSTED_DOMAIN=nextcloud.$DOMAINNAME
      - NEXTCLOUD_DATA_DIR=/data
      ### Add local network as a trusted proxy - It's better to set the actual Traefik IP.
      ###   We will give it the range listed in the accompanying Traefik guide
      - TRUSTED_PROXIES=172.16.0.250
      - OVERWRITEPROTOCOL=https
      - REDIS_HOST=redis
  #    - REDIS_HOST_PASSWORD=1234
    labels:
      - "traefik.enable=true"
      ## HTTP Routers
      - "traefik.http.routers.nextcloud.entrypoints=https"
      - "traefik.http.routers.nextcloud.rule=Host(`nextcloud.$DOMAINNAME`)"
      - "traefik.http.routers.nextcloud.tls=true"
      ## Middlewares
      - "traefik.http.routers.nextcloud.middlewares=chain-nextcloud@file"
      ## HTTP Services
      - "traefik.http.routers.nextcloud.service=nextcloud"
      - "traefik.http.services.nextcloud.loadbalancer.server.port=80"
      - wud.tag.include=^\d+\.\d+\.\d+-apache$$
      - wud.watch.digest=true
      - wud.link.template=https://newreleases.io/github/nextcloud/server?version=v$${major}.$${minor}.$${patch}
  nextcloud-cron:
    container_name: nextcloud-cron
    image: nextcloud:28-apache
    restart: always
    entrypoint: /cron.sh
  ##  user: $DOCKERRUNNER:$DOCKERFILES
    depends_on:
      - traefik
    #read_only: true
    security_opt:
      - no-new-privileges:true
    networks:
      - net-t2-proxy
      - db_net
#    ports:
#      - "443:443"
    volumes:
      - $NONGITDIR/nextcloud:/var/www/html
      - /mnt/data/nextcloudData:/data
      - /mnt/data/media:/media_data
    environment:
      - TZ=$TZ
      - NEXTCLOUD_TRUSTED_DOMAIN=nextcloud.$DOMAINNAME
      - NEXTCLOUD_DATA_DIR=/data
      - OVERWRITEPROTOCOL=https
      ### Add local network as a trusted proxy - It's better to set the actual Traefik IP.
      ###   We will give it the range listed in the accompanying Traefik guide
      - TRUSTED_PROXIES=172.16.0.250
      - REDIS_HOST=redis
  #    - REDIS_HOST_PASSWORD=1234
  ```

  Here we setup the nextcloud docker files, Not a huge amount to say. Just know what the directories are. nextcloudData is the data that users upload. You can also utilize the nextcloud external storage plugin to allow for a folder structure on disk to be accessible inside nextcloud. I use this to sync my photo collection which I have organized into a folder structure and don't want to be maniuplated by nextcloud.

  The cron service helps to ensure that maintanance tasks are performed on a regular interval for nextcloud(such as database indexing,etc)
  

  As a side note, I have listed a lot of these apps as separate files. However, there is no need to do that. You can instead combine them into one file, or into files grouped by segment, etc.


[Previous Part - Your Apps!](./Part6-Software.md) | [Next Part - Exposing HTTP Services](./Part8-ExpsoingHTTP.md)