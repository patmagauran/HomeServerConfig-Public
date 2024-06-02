# Part 3 - Core Services

In this part I will go through the core compose file, section by section, directing the creation of folders, files, and third party services as needed. As a preface, the compose file is in YAML(Yet Another Markup Language) which has a simple syntax: indent for a nested structure, colon to separate a key and a value. You should be able to follow as we go through.

Also note this file will be titled `docker-compose-core.yml`

# Section 0: Environment variables
Throughout the compose files you will see environment variable used so that long paths are not repeatedly typed out and so that configurations can easily be changed with consistency. An environment variable takes the form of `$VARIABLENAME` and is substituted in for the value upon compose startup. Env vars can be loaded from the shell environment, prepended on the compose command, or set in a `.env` file. We will use the last method to make life easiest. 

In the example file below I will fill in the domain name using example.com as the root and portal.example.com for the host-specific fields.

```
DOCKERDIR=/var/dockers/HomeServerConfigs
APPDATA=$DOCKERDIR/appdata/nonsecret
SECRETDIR=$DOCKERDIR/appdata/secret
NONGITDIR=$DOCKERDIR/appdata/nongit
APPSDIR=$DOCKERDIR/apps
DOMAINNAME0=example.com
DOMAINNAME=example.com
HOSTTAG=-portal
DOMAINNAMEHOST=portal.example.com
TRAEFIKFORWARDARCHTAG=
DOMAINNAMEROOT=example.com
TZ=America/New_York
HOSTID=portal
DOCKERRUNNER=999
DOCKERFILES=998
```

So whenever a filepath is referenced below and you need to create or edit the file, use the directories specified in the env file you created.

Additionally, make sure to update every field to your setup, especially the domains and dockerrunner/files ids.

# Section 0.5: Custom Docker Repos
For a few of the docker images below you will see they are pointing to my github container registry. That is because the original versions were not being regularily updated. I am not adding any features or fixing things in the software themselves. However, I do have nightly rebuilds setup that utilize the latest base images so that way only the software itself may get outdated and not the entire image. You are welcome to keep them or you can revert to the original repositories. The only exception is whats-up-docker as that tracks my copy with the git trigger changes.

# Section 1: Version and Networks
```
version: "3.9"
```
This sets the compose specification version to use. This really shouldn't need to be adjusted often unless you want to utilize new features(although 3.9 is the latest as of writing)
```
########################### NETWORKS
# There is no need to create any networks outside this docker-compose file.
# You may customize the network subnets (192.168.90.0/24 and 91.0/24) below as you please.
# Docker Compose version 3.5 or higher required to define networks this way.

networks:
  net-t2-proxy:
    name: net-t2-proxy
    driver: bridge
    ipam:
      config:
        - subnet: 172.16.0.0/24
  default:
    driver: bridge
  net-socket-proxy:
    name: net-socket-proxy
    driver: bridge
    ipam:
      config:
        - subnet: 172.16.1.0/24
```
Here we create 3 neworks: net-t2-proxy to connect the containers running behind our traefik proxy, the default network that allows for external network access, and net-socket-proxy for containers that require access to our docker socket proxy(More on that later)

# Section 2: Secrets(Shh... Don't tell)

```
########################### SECRETS
secrets:
  htpasswd:
    file: $SECRETDIR/htpasswd
  cloudflare_email:
    file: $SECRETDIR/cloudflare_email
  cloudflare_api_key:
    file: $SECRETDIR/cloudflare_api_key
  google_oauth_config:
    file: $SECRETDIR/google_oauth_config
  sendgridApiKey:
    file: $SECRETDIR/sendgridApiKey
```
Here we define a docker feature known as secrets. How this works is we define our list of secrets here. Each key(ex. htpasswd) will be used in our container definition later to give them access to the value stored in the file we specify. These secrets will be created as needed as we go through.

# Section 3: Traefik

```
########################### SERVICES
services:
  ############################# FRONTENDS
  traefik:
    container_name: traefik
    image: traefik:2.11.0
    restart: unless-stopped
    command: # CLI arguments
      - --configFile=/traefik.yml
    networks:
      net-t2-proxy:
        ipv4_address: 172.16.0.250 # You can specify a static IP
      net-socket-proxy:
```
First we define that we are starting the 'services' section of our compose file. We then start our first service: traefik. Each line should be fairly self explanatory. The most important to note is the image. As new versions get released it is important to update this value and repull the images(More on that in a future part).
```
    user: $DOCKERRUNNER:$DOCKERFILES
    read_only: true
    security_opt:
      - no-new-privileges:true
    healthcheck:
      test: ['CMD', 'traefik', 'healthcheck', '--ping']
      interval: 10s
      timeout: 30s
      retries: 10
      start_period: 30s
```
Next we handle a few security and maintenance features. We set the user and group the service runs as as well as ensuring the volume it runs on is read_only. The healthcheck tells the docker daemon to periodically check to make sure the service is up. If it isn't it will restart it. This is useful in case it hangs for some reason.

```
    depends_on:
      - socket-proxy
    ports:
      - target: 80
        published: 80
        protocol: tcp
        mode: host
      - target: 443
        published: 443
        protocol: tcp
        mode: host
      - target: 8080
        published: 8080
        protocol: tcp
        mode: host
```
Next we declare a dependency. We don't want this container starting until the socket-proxy container starts. Finally, we map our ports so we can access the proxy from our network
```
    volumes:
      - $APPDATA/traefik2/rules:/rules # file provider directory
      - $SECRETDIR/traefik2/acme/acme.json:/acme.json # cert location - you must touch this file and change permissions to 600
      - $NONGITDIR/traefik2/traefik.log:/traefik.log # for fail2ban - make sure to touch file before starting container
      - $APPDATA/traefik2/traefik$HOSTTAG.yml:/traefik.yml
    environment:
      - CF_API_EMAIL_FILE=/run/secrets/cloudflare_email
      - CF_API_KEY_FILE=/run/secrets/cloudflare_api_key
      - HTPASSWD_FILE=/run/secrets/htpasswd # HTPASSWD_FILE can be whatever as it is not used/called anywhere.
    secrets:
      - cloudflare_email
      - cloudflare_api_key
      - htpasswd
```
Here we setup our volumes, environment variables, and secrets. The volumes map a file or directory on the host system to be mounted inside the container at the space you sepcify. The environment variables get passed into the container as specified. Here we are setting some file locations to load some values from. Finally we tell docker to expose some of those secrets we specified earlier to the container. They will get exposed via a file in the container on the path `/run/secrets/{key}`.

```
    labels:
      #- "autoheal=true"
      - "traefik.enable=true"
      # HTTP-to-HTTPS Redirect
      - "traefik.http.routers.http-catchall.entrypoints=http"
      - "traefik.http.routers.http-catchall.rule=HostRegexp(`{host:.+}`)"
      - "traefik.http.routers.http-catchall.middlewares=redirect-to-https"
      - "traefik.http.middlewares.redirect-to-https.redirectscheme.scheme=https"
      # HTTP Routers
      - "traefik.http.routers.traefik-rtr.entrypoints=https"
      - "traefik.http.routers.traefik-rtr.rule=Host(`traefik.$DOMAINNAMEHOST`)"
      ## Services - API
      - "traefik.http.routers.traefik-rtr.service=api@internal"
      ## Middlewares
      - "traefik.http.routers.traefik-rtr.middlewares=chain-oauth@file"
      ##For Metrics Endpoint
      - "traefik.http.routers.metrics-rtr.entrypoints=https"
      - "traefik.http.routers.metrics-rtr.rule=Host(`metrics.$DOMAINNAMEHOST`)"
      ## Services - API
      - "traefik.http.routers.metrics-rtr.service=prometheus@internal"
      ## Middlewares
      - "traefik.http.routers.metrics-rtr.middlewares=chain-oauth@file"
      - wud.tag.include=^\d+\.\d+\.\d+$$
      - wud.link.template=https://newreleases.io/github/traefik/traefik?version=v$${major}.$${minor}.$${patch}
```
This is a complicated looking section but is the meat of what makes traefik so great. Labels allow for custom details to be specified on a docker container. Then anyone with access to the docker socket can read these labels and use the data as needed. In this case, we are setting a bunch of traefik configuration options. This essentially sets up rule chains, service exposure, domain mappings, and authentication so that we can securely access our traefik portal. The final two labels are to monitor for updates to traefik using WUD(Whats up Docker).

If you want to better understand what each of those labels mean, I recommend the following documentation: https://doc.traefik.io/traefik/routing/providers/docker/

Now lets go through the files traefik needs and that we specified in our volumes section:

## Rules
The first volume is a directory mapping that will contain the rules traefik will use for routing. This will contain 4 files: middlewares.yml, middlewares-nextcloud.yml, middlewares-chains.yml, and tls-opts.yml. I am not going to go through these files in their entirety, but I will point out a few things. 

Trafeik allows us to specify "middlewares" which are intermediate processing steps packets must go through to be successfully routed. This includes in our case, rate limiting, secure header enforcement, oauth, and https redirection. We can combine these into chains which define groupings of middlewares for easier reference. For example, we have the chain-oauth chain which activates rate limits, https redirection, secure headers, and oauth. We have a no auth chain that doesn't include oauth.

### Nextcloud
Nextcloud has special rules so that we don't have issues with the nextcloud client application being blocked by our authentication. Similarily, you could setup special middlewares for services that require it.

## acme.json
This file is created in the deployment scripts we used in the last part. It holds the information needed to generate our lets encrypt ssl certificates. It is a secret item and should be placed accordingly as it could allow someone to impersonate your website or whatever you host.

## traefik.log
Simply a log file.

## traefik.yml
The main config. You will notice I have this specific to the host. This is because this file specifies the domains that lets encrypt should generate against. Therefore, I need them to be specific to support the subdomain associated with each host.

The section you need to change looks like this(Domains filled in for example.com):
```
        http:
            tls:   # Add dns-cloudflare as default certresolver for all services. Also enables TLS and no need to specify on individual services
                options: tls-opts@file
                certResolver: dns-cloudflare
                domains:
                    - main: example.com
                      sans: "*.example.com"
                    - main: portal.example.com
                      sans: "*.portal.example.com"

```

## Cloudflare Email and API Key
You will need to get a cloudflare email and API key and place them in the appropriate files in the secret dir.

## Htpasswd
This is used to define the username password(Hashed) combinations that will be authenticated if you decide to use the basic-auth chain(Which you shouldn't without a good reason)

# Section 4: Socket Proxy
```
# Docker Socket Proxy - Security Enchanced Proxy for Docker Socket
  socket-proxy:
    container_name: socket-proxy
    image: tecnativa/docker-socket-proxy
    #restart: always
    restart: unless-stopped
    # profiles:
    # - core
    networks:
      net-socket-proxy:
        ipv4_address: 172.16.1.20 # You can specify a static IP
   # user: $DOCKERRUNNER:$DOCKERFILES
    read_only: true
    security_opt:
      - no-new-privileges:true
    healthcheck:
      test: wget --no-verbose --tries=1 --spider http://localhost:2375/_ping || exit 1
      interval: 10s
      timeout: 30s
      retries: 10
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock"
      - /var/lib/haproxy
      - /run/
    environment:
      - LOG_LEVEL=info # debug,info,notice,warning,err,crit,alert,emerg
      ## Variables match the URL prefix (i.e. AUTH blocks access to /auth/* parts of the API, etc.).
      # 0 to revoke access.
      # 1 to grant access.
      ## Granted by Default
      - EVENTS=1
      - PING=1
      - VERSION=1
      ## Revoked by Default
      # Security critical
      - AUTH=0
      - SECRETS=0
      - POST=1 # Ouroboros
      # Not always needed
      - BUILD=0
      - COMMIT=0
      - CONFIGS=0
      - CONTAINERS=1 # Traefik, portainer, etc.
      - DISTRIBUTION=0
      - EXEC=0
      - IMAGES=1 # Portainer
      - INFO=1 # Portainer
      - NETWORKS=1 # Portainer
      - NODES=0
      - PLUGINS=0
      - SERVICES=1 # Portainer
      - SESSION=0
      - SWARM=0
      - SYSTEM=0
      - TASKS=1 # Portaienr
      - VOLUMES=1 # Portainer
    labels:
      - wud.link.template=https://newreleases.io/github/tecnativa/docker-socket-proxy?version=$${raw}
```
We will have multiple containers that need access to the docker socket. However, access to the docker socket is essentially root access to the host machine, which is not ideal. Instead, we setup this proxy container that takes the socket access and exposes it over http with different access controls. This allows us to deny access to certain commands that aren't needed. Ideally we would create a different proxy for each container that needs access to avoid additional permissions being granted, however, I have not done that here. So any container on the socket-proxy network will have http access to our socket, which is slightly more secure. 

You will note in the volumes there are a few volumes specified with no colon. These are known as "Anonymous volumes" and allow for volumes to be created that are linked only to the container and will survive reboots but live in the host filesystem(although accessible by few users). We had to do this to create writable locations so our container could remain read-only. This is a common problem as generally the services expect certain locations to be writeable.

Additionally, we are not running as a specific user, instead letting it run as root. This is required to access the docker socket and there is no way around it.


# Section 5: Oauth
```

  # Google OAuth - Single Sign On using OAuth 2.0
  # https://www.smarthomebeginner.com/google-oauth-with-traefik-docker/
  oauth:
    container_name: oauth
    image: thomseddon/traefik-forward-auth:2.2.0
    # image: thomseddon/traefik-forward-auth:2.1-arm # Use this image with Raspberry Pi
    #restart: always
    restart: unless-stopped
    # profiles:
    # - core
    networks:
      - net-t2-proxy
    user: $DOCKERRUNNER:$DOCKERFILES
    read_only: true
    security_opt:
      - no-new-privileges:true
    environment:
      - CONFIG=/config
      - COOKIE_DOMAIN=$DOMAINNAMEROOT
      - INSECURE_COOKIE=false
      - AUTH_HOST=oauth.$DOMAINNAMEROOT
      - URL_PATH=/_oauth
      - LOG_LEVEL=warn
      - LOG_FORMAT=text
      - LIFETIME=86400 # 1 day
      - DEFAULT_ACTION=auth
      - DEFAULT_PROVIDER=google
    secrets: # had trouble getting secrets to work: https://github.com/thomseddon/traefik-forward-auth/issues/155#issuecomment-664630985
      - source: google_oauth_config
        target: /config
        uid: '$DOCKERRUNNER'
        gid: '$DOCKERFILES'
        mode: 0444
    labels:
      - "traefik.enable=true"
      ## HTTP Routers
      - "traefik.http.routers.oauth-rtr.tls=true"
      - "traefik.http.routers.oauth-rtr.entrypoints=https"
      - "traefik.http.routers.oauth-rtr.rule=Host(`oauth.$DOMAINNAMEROOT`)"
      ## Middlewares
      - "traefik.http.routers.oauth-rtr.middlewares=chain-oauth@file"
      ## HTTP Services
      - "traefik.http.routers.oauth-rtr.service=oauth-svc"
      - "traefik.http.services.oauth-svc.loadbalancer.server.port=4181"
      - wud.tag.include=^\d+\.\d+\.\d+-arm$$
      - wud.link.template=https://newreleases.io/github/thomseddon/traefik-forward-auth?version=v$${major}.$${minor}.$${patch}
```
This is another key piece of our puzzle. Google based oauth will be our authentication handler. This service sets up the needed http servicing required to complete that flow. It additionally serves as a middleware for traefik forcing traffic to first pass through it so we can ensure the user is properly authenticated. 

This requires some setup with google services: https://www.smarthomebeginner.com/traefik-forward-auth-google-oauth-2022/ You can follow that guide(Also note an older version was the major inspiration for the current state of this project.)

## google_oauth_config
Take the config you generate and copy it into the secrets folder so this container can access it


# Section 6: Whats up docker
```
  whatsupdocker:
    image: ghcr.io/patmagauran/whats-up-docker:latest
    container_name: wud
 #   user: $DOCKERRUNNER:$DOCKERFILES
    restart: unless-stopped
    read_only: true
    security_opt:
      - no-new-privileges:true
    env_file:
      - $SECRETDIR/wud.env
      - $APPDATA/wud.env
      - $APPDATA/wud-portal.env
    healthcheck:
      test: wget --no-verbose --tries=1 --no-check-certificate --spider http://localhost:3000
      interval: 10s
      timeout: 10s
      retries: 3
      start_period: 10s
    depends_on:
      - traefik
      - socket-proxy
    volumes:
      # - $DOCKERDIR/docker-compose-apps$HOSTTAG.yml:/wud/docker-compose-apps.yaml
      # - $DOCKERDIR/docker-compose-Core.yml:/wud/docker-compose-core.yaml
      # - $DOCKERDIR/docker-compose-management$HOSTTAG.yml:/wud/docker-compose-mgmt.yaml
      - /store
      - $SECRETDIR/id_rsa:/home/node/.ssh/id_rsa
      - $SECRETDIR/id_rsa.pub:/home/node/.ssh/id_rsa.pub
    networks:
      - net-t2-proxy
      - net-socket-proxy
    labels:
      - "traefik.enable=true"
      ## HTTP Routers
      - "traefik.http.routers.whatsupdocker-rtr.entrypoints=https"
      - "traefik.http.routers.whatsupdocker-rtr.rule=Host(`wud.$DOMAINNAME0`)"
      ## Middlewares
      - "traefik.http.routers.whatsupdocker-rtr.middlewares=chain-oauth@file"
      ## HTTP Services
      - "traefik.http.routers.whatsupdocker-rtr.service=whatsupdocker-svc"
      - "traefik.http.services.whatsupdocker-svc.loadbalancer.server.port=3000"
```
Whats up docker is a service that monitors our containers to see if there are any image updates available. It can notify you in many different ways. I have written extensions to automatically edit the compose file and push the changes to git; however, I have encountered a lot of issues with this feature I have not yet diagnosed.

## id_rsa
I mouunt two files to this: id_rsa and id_rsa.pub. These are SSH keys and they give the container permission to push changes to my git repository. You can choise whether to use these or not.

## Env Files
Some services don't take in a config file. They only work with environment variables. This is okay, but we run into issues when we have specific values for every host or we have secure data we need. In those cases, we'd prefer to have it load the values from files that we can implement our own security on. That is what we are doing. These files are simple key value pair files that define env vars to load into the system.

## Secret wud.env
```
WUD_TRIGGER_SMTP_MAIL_PASS={SENDGRID_API_KEY}

```
This just sets the Password to send emails via our sendgrid api notifying us of updates.

## Generic wud.env
```
WUD_WATCHER_docker_HOST=socket-proxy
WUD_TRIGGER_GIT_core_GITREPO={YOUR GIT REPO}
WUD_TRIGGER_SMTP_MAIL_HOST=smtp.sendgrid.net
WUD_TRIGGER_SMTP_MAIL_PORT=587
WUD_TRIGGER_SMTP_MAIL_TLS_ENABLED=true
WUD_TRIGGER_SMTP_MAIL_USER=apikey
WUD_TRIGGER_SMTP_MAIL_FROM={FROM EMAIL}
WUD_TRIGGER_SMTP_MAIL_TO={TO EMAIL}
WUD_TRIGGER_SMTP_MAIL_MODE=batch
```
Here we specify the setup for our "triggers" which act whenever there is an update available.

## Host specific wud.env
```
WUD_TRIGGER_GIT_core_FILE=compose/docker-compose-core-portal.yml, compose/docker-compose-apps-portal.yml, compose/docker-compose-management-portal.yml
```
This specified the files the git trigger should try to modify. It is specific to the host as the files that will be activated will be specific to the host.

# Section 7: Auto Restic and Rclone Backups
```
 backup:
    container_name: autorestic
    image: ghcr.io/patmagauran/autorestic-docker:main
    user: $DOCKERRUNNER:$DOCKERFILES
    read_only: true
    security_opt:
      - no-new-privileges:true
    restart: unless-stopped
    environment:
      BACKUP_ON_START: "true"
    env_file:
      - $SECRETDIR/autorestic.env
    volumes:
      - /var/dockers/HomeServerConfigs:/mnt/HomeServerConfigs:ro
      - $APPDATA/autorestic/autorestic-portal.yml:/app/autorestic.yml:ro
      - $NONGITDIR/autorestic/cache:/.cache/restic
      - /app/
      - /.cache
      - /tmp
      - /backups:/backups
  rclone:
    image: pfidr/rclone:1.63.0
    restart: unless-stopped
    volumes:
      - $APPDATA/rclone:/config
      - /backups/:/data
    env_file:
      - $SECRETDIR/rclone.env
    environment:
      # see more flags at https://hub.docker.com/r/pfidr/rclone/dockerfile
      - "UID=$DOCKERRUNNER"
      - "GID=$DOCKERFILES"
      - "TZ=$TZ"
      - "SYNC_SRC=/data"
      - "SYNC_DEST=b2:$B2_BUCKET"
      - "CHECK_URL="
      # visit https://crontab.guru/
      - "CRON=30 */6 * * *" 
      - "FORCE_SYNC=1"
      - "SYNC_OPTS=-v --b2-hard-delete"
```
I have a two stage backup system in place. First autorestic makes incremental snapshots of our config folder to capture all changes to any ephemeral app data folders. Then rclone periodically syncs these snapshots to B2. To use other services instead of B2, see the documentation here: https://rclone.org/commands/rclone_sync/

The volumes should be mostly self explanatory, mainly mounting spots to backup to and from.

## autorestic.yml
```
version: 2

locations:
  homeserverconfigs-portal:
    from: /mnt/HomeServerConfigs
    to:
      - local
    cron: '0 */6 * * *' # Every 6 hours
    options:
      backup:
        exclude:
          - appdata/secret/
          - compose/
          - deployment/
          - apps/
backends:
  local:
    type: local
    path: /backups
```
Here I have a simple config that runs a backup every 6 hours, excluding certain files.

## rclone/rclone.conf
```
[b2]
type = b2
```
Here we specify we backup to b2. The rest of the config is in the secret files

## rclone.env
```
RCLONE_B2_ACCOUNT=
RCLONE_B2_KEY=
```
These should be filled out with the account and key you get when creating your B2 bucket.

## autorestic.env
```
AUTORESTIC_LOCAL_RESTIC_PASSWORD="A SECURE AND RANDOM PASSWORD"
```
Autorestic encrypts the backups so we need to define a secure password(That you should also backup somewhere secure, even if on paper).

[Previous Part - Host Setup](./Part2-Core.md) | [Next Part - Mangement Services](./Part4-ComposeManagement.md)