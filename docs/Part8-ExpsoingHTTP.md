# Part 8 - Exposing Web Services to the public


So you have your services all secure. You can use them and its all great. But now you want to share your recipes with your friend who isn't willing to install zerotier on their system. Don't worry, we can still expose this service securely using Cloudflare tunnels. 

A cloudflare tunnel is essentially a VPN between your system and cloudflare's network. Then you can setup specific access rules and authentication requirements on cloudflares side so they can handle any nefarious actors and only trusted connections make it to your system. Additionally, even those trusted systems never connect directly to your system. For those concerned about all the traffic passing through cloudflare, there are a few ways you can configure the HTTPS handling including ways in which cloudflare cannot read them. 

As a second layer of security, we will run the tunnel in a docker container and isolate it to its own network shared only with services we wish to expose. 


For the exposed service compose yaml:

```
version: "3.9"
########################### NETWORKS
networks:
  cloudflare-proxy:
    name: cloudflare-proxy
    driver: bridge
    ipam:
      config:
        - subnet: 172.16.2.0/24
  recipe_db:
########################### SECRETS

########################### SERVICES
services:
  httpEcho:
    container_name: http_echo
    image: mendhak/http-https-echo:33
    restart: always
    user: $DOCKERRUNNER:$DOCKERFILES
    read_only: true
    security_opt:
      - no-new-privileges:true
    environment:
        - HTTP_PORT=8888
    volumes:
      - /var/cache
      - /var/run
    labels: # traefik example labels
      - "traefik.enable=true"
      - "traefik.http.routers.http-echo.rule=Host(`echo.$DOMAINNAME0`, `www.echo.$DOMAINNAME0`)"
      - "traefik.http.routers.http-echo.entrypoints=https" # your https endpoint
      ## Middlewares
      - "traefik.http.routers.http-echo.middlewares=chain-oauth@file"
      ## HTTP Services
      - "traefik.http.routers.http-echo.service=http-echo-svc"
      - "traefik.http.services.http-echo-svc.loadbalancer.server.port=8888"
    networks:
      - net-t2-proxy
      - cloudflare-proxy
  cloudflared:
    container_name: cloudflared
    image: erisamoe/cloudflared
    restart: unless-stopped
    command: tunnel run
    env_file:
      - $SECRETDIR/cloudflared.env
    networks:
      - cloudflare-proxy

```

and then for the cloudflared.env file:

```
TUNNEL_TOKEN=
```

Since cloudflare may change the steps needed to setup the tunnel for our use, I will link a series of their tutorials to follow along with a few notes of my own.

1. https://developers.cloudflare.com/cloudflare-one/applications/configure-apps/self-hosted-apps/
    - This will guide you through setting up the access policies and should be fairly self explanatory.
    - As of writing, steps 4 and 5 deal with the tunnel setup and you should follow their instructions. I have also provided the tunnel setup instructions below as step 2.

2. https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/get-started/create-remote-tunnel/
    - This will guide you through the creation of a simple remote tunnel
    - When you select the public hostname, this is where you want it to be accessible from
    - The token that is provided will be what you need to fill into the environment variable for the cloudflared container. However, DO NOT start the container until the other access policies are setup in cloudflare
3. Enable access control on the tunnel: 
   1. Tunnel -> Edit
   2. Public Hostnames -> Edit
   3. Additional Settings -> Access -> Enable and select groups



[Previous Part - The NAS](./Part7-TheNAS.md) | [Next Part - Exposing Other Services](./Part9-ExposingOthers.md)
