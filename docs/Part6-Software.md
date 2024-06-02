# Part 6 - Your Apps!


Now to the whole reason we are doing this: Hosting our Apps! By this point, you should understand the basic premise to setup a new service, so I am only going to provide a single example here: a dashboard to get to all of your other services! In part 7, I will explain nextcloud. In part 8, we will add another app to be publically accessibly via HTTPS. In part 9, we will add a minecraft server to be publically accessible.

The Docker file for a simple dashboard:
```
version: "3.9"
########################### SECRETS

########################### SERVICES
services:
  # Dashboard - Frontend
  dashboard:
    container_name: dashboard
    image: phntxx/dashboard:latest
#    user: $DOCKERRUNNER:$DOCKERFILES
    read_only: true
    security_opt:
      - no-new-privileges:true
    restart: unless-stopped
    healthcheck:
      test: wget --no-verbose --tries=1 --spider http://localhost:8080 || exit 1
      interval: 10s
      timeout: 30s
      retries: 10
    depends_on:
      - traefik
    # profiles:
    # - apps
    networks:
      - net-t2-proxy

    # ports:
    #   - "$ORGANIZR_PORT:80"
    volumes:
      - $APPDATA/dashboard:/app/data
      - /var/cache
      - /tmp
    labels:
      - "traefik.enable=true"
      ## HTTP Routers
      - "traefik.http.routers.dashboard-rtr.entrypoints=https"
      - "traefik.http.routers.dashboard-rtr.rule=Host(`$DOMAINNAME0`) || Host(`www.$DOMAINNAME0`)"
      #- "traefik.http.routers.organizr-rtr.rule=Host(`organizr.$DOMAINNAME0`)"
      ## Middlewares
      - "traefik.http.routers.dashboard-rtr.middlewares=dashboard-redirect@docker,chain-oauth@file" # Redirect non-www to www middleware
      - "traefik.http.middlewares.dashboard-redirect.redirectregex.regex=^https?://$DOMAINNAME0/(.*)"
      - "traefik.http.middlewares.dashboard-redirect.redirectregex.replacement=https://www.$DOMAINNAME0/$${1}"
      - "traefik.http.middlewares.dashboard-redirect.redirectregex.permanent=true"
      ## HTTP Services
      - "traefik.http.routers.dashboard-rtr.service=dashboard-svc"
      - "traefik.http.services.dashboard-svc.loadbalancer.server.port=8080"

```
The config file will be very self explanatory.

## The Dashboard config file

```


```



[Previous Part - Updates and Monitoring](./Part5-UpdatesAndMonitoring.md) | [Next Part - The NAS](./Part7-TheNAS.md)