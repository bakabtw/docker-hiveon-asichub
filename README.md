# Purpose
This is Dockerfile for dockerizing [Hiveon ASIC Hub](https://hiveon.com/asichub/).

Since all my services run in docker environment, I wanted to avoid running any services on bare metal.

The solution with `install.sh` is ugly, but it works.

# Prerequisites
You need to install docker buildx (https://docs.docker.com/build/building/multi-platform/) to build multiarch images.

# Building
Run the following command:

```
docker buildx build --platform=linux/amd64 -t asic-hub --output type=docker .
```

Supported platforms:
- linux/amd64
- linux/arm/v7
- linux/arm64

# Running
Starting a docker container:

```
docker run --name asic-hub -p 8800:8800 asic-hub
```

After that, open 
```
http://locahost:8800
```

# Docker-compose
Here's a sample `docker-compose.yml` file.

```
version: '3'

services:
  asic-hub:
    image: bakabtw/hiveon-asic-hub:latest
    container_name: asic-hub
    restart: unless-stopped
    volumes:
      - asichub-conf:/etc/asic-hub
      - asichub-lib:/var/lib/asic-hub
    ports:
      - "8800:8800"

volumes:
  asichub-conf:
  asichub-lib:
```

# TODO
- Update `install.sh`
