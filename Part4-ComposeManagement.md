# Part 4 - Mangement Services


In this section I will go over the management compose file. I only have one service running in this, but more could be added if it makes sense for your services.

# The File
Here we have only one service: Portainer, which is a Web UI for monitoring our docker containers. I find it easier for quick checks of things like logs, restarting a container, etc rather than needing to ssh to my host machine. With traefik, it is still protected in whatever way you desire.

```
version: "3.9"
########################### SECRETS
secrets:
  sendgridApiKey:
    file: $SECRETDIR/sendgridApiKey
########################### SERVICES
services:
  # Portainer - WebUI for Containers
  portainer:
    container_name: portainer
    image: portainer/portainer-ce:2.19.4-alpine
    restart: unless-stopped
    # profiles:
    # - apps
    # command: -H unix:///var/run/docker.sock # # Use Docker Socket Proxy instead for improved security
    command: -H tcp://socket-proxy:2375
    networks:
      - net-t2-proxy
      - net-socket-proxy
    user: $DOCKERRUNNER:$DOCKERFILES
    healthcheck:
      test: wget --no-verbose --tries=1 --spider http://localhost:9000/api/system/status || exit 1
      interval: 1m30s
      timeout: 30s
      retries: 5
      start_period: 30s
    depends_on:
      - traefik
      - socket-proxy
    read_only: true
    security_opt:
      - no-new-privileges:true
    volumes:
      # - /var/run/docker.sock:/var/run/docker.sock:ro # # Use Docker Socket Proxy instead for improved security
      - $NONGITDIR/portainer/data:/data # Change to local directory if you want to save/transfer config locally
    environment:
      - TZ=$TZ
    labels:
      - "traefik.enable=true"
      ## HTTP Routers
      - "traefik.http.routers.portainer-rtr.entrypoints=https"
      - "traefik.http.routers.portainer-rtr.rule=Host(`portainer.$DOMAINNAME0`)"
      ## Middlewares
      - "traefik.http.routers.portainer-rtr.middlewares=chain-oauth@file"
      ## HTTP Services
      - "traefik.http.routers.portainer-rtr.service=portainer-svc"
      - "traefik.http.services.portainer-svc.loadbalancer.server.port=9000"
      - wud.tag.include=^\d+\.\d+\.\d+-alpine$$
      - wud.link.template=https://newreleases.io/github/portainer/portainer?version=$${major}.$${minor}.$${patch}
```
Based on the previous article, everything here should be fairly self-explanatory as to what it does.


## For other hosts: the Portainer agent
We only host portainer on the main host. For other hosts, we can still allow them to be monitored using a portainer agent, which will communicate with the main portainer instance securely. Its setup is as follows:
```
version: "3.9"
########################### NETWORKS
########################### SECRETS

########################### SERVICES
services:

  portaineragent:
    image: portainer/agent:2.19.4
    container_name: portainer_agent
    restart: unless-stopped
    # healthcheck:
    #  #$ test: "wget --no-check-certificate --no-verbose --tries=3 --spider --header='Content-Type:application/json' http://127.0.0.1:9001/ping || exit 1"
    #   test: "/app/agent --health-check"
    #   interval: 1m30s
    #   timeout: 30s
    #   retries: 5
    #   start_period: 30s
    depends_on:
      - traefik
    # profiles:
    # - apps
    # command: -H unix:///var/run/docker.sock # # Use Docker Socket Proxy instead for improved security
    networks:
      - net-t2-proxy
   # user: $DOCKERRUNNER:$DOCKERFILES
    read_only: true
    security_opt:
      - no-new-privileges:true
    ports:
      - "9001:9001"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro # # Use Docker Socket Proxy instead for improved security
      - $APPDATA/portainer-agent$HOSTTAG/data:/data # Change to local directory if you want to save/transfer config locally
      - /app
    labels:
      - wud.tag.include=^\d+\.\d+\.\d+$$
      - wud.link.template=https://newreleases.io/github/portainer/portainer?version=$${major}.$${minor}.$${patch}

```


[Previous Part - Core Services](./Part3-ComposeCore.md) | [Next Part - Updates and Monitoring](./Part5-UpdatesAndMonitoring.md)