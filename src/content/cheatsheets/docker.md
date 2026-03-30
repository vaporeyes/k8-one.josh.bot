---
title: "Docker"
description: "Quick reference for building images, running containers, and managing Docker resources."
updatedDate: 2026-03-30
---

## Images

```bash
# Build image
docker build -t myapp:latest .
docker build -t myapp:latest -f Dockerfile.prod .

# Build with build args
docker build --build-arg ENV=prod -t myapp:latest .

# Multi-platform build
docker buildx build --platform linux/amd64,linux/arm64 -t myapp:latest .

# List images
docker images
docker images --format '{{.Repository}}:{{.Tag}} {{.Size}}'

# Remove image
docker rmi myapp:latest

# Remove dangling images
docker image prune

# Remove all unused images
docker image prune -a

# Tag image
docker tag myapp:latest registry.example.com/myapp:v1.0

# Push image
docker push registry.example.com/myapp:v1.0

# Pull image
docker pull nginx:alpine

# Inspect image layers
docker history myapp:latest
docker inspect myapp:latest
```

## Containers

```bash
# Run container
docker run nginx
docker run -d nginx                     # detached
docker run -d --name web nginx          # named
docker run -d -p 8080:80 nginx          # port mapping
docker run -d -p 127.0.0.1:8080:80 nginx  # bind to localhost only

# Environment variables
docker run -e MY_VAR=value nginx
docker run --env-file .env nginx

# Volumes
docker run -v /host/path:/container/path nginx
docker run -v myvolume:/data nginx      # named volume
docker run --mount type=bind,source=/host,target=/container nginx

# Resource limits
docker run --memory=512m --cpus=1.5 nginx

# Auto-remove on exit
docker run --rm nginx echo "hello"

# Interactive shell
docker run -it ubuntu /bin/bash
docker run -it --rm alpine /bin/sh

# List containers
docker ps                               # running
docker ps -a                            # all
docker ps -q                            # IDs only
docker ps --format '{{.Names}} {{.Status}}'

# Stop / start / restart
docker stop web
docker start web
docker restart web

# Remove container
docker rm web
docker rm -f web                        # force (running)

# Remove all stopped containers
docker container prune
```

## Exec and Logs

```bash
# Exec into running container
docker exec -it web /bin/sh
docker exec -it web /bin/bash

# Run command in container
docker exec web cat /etc/nginx/nginx.conf

# Logs
docker logs web
docker logs -f web                      # follow
docker logs --tail 100 web              # last 100 lines
docker logs --since 30m web             # last 30 minutes

# Inspect container
docker inspect web
docker inspect web --format '{{.NetworkSettings.IPAddress}}'

# Stats
docker stats
docker stats web
```

## Volumes

```bash
# Create volume
docker volume create mydata

# List volumes
docker volume ls

# Inspect
docker volume inspect mydata

# Remove
docker volume rm mydata

# Remove unused volumes
docker volume prune

# Backup volume
docker run --rm -v mydata:/source -v $(pwd):/backup alpine \
  tar czf /backup/mydata.tar.gz -C /source .

# Restore volume
docker run --rm -v mydata:/target -v $(pwd):/backup alpine \
  tar xzf /backup/mydata.tar.gz -C /target
```

## Networks

```bash
# List networks
docker network ls

# Create network
docker network create mynet

# Run container on network
docker run -d --network mynet --name web nginx

# Connect running container
docker network connect mynet web

# Disconnect
docker network disconnect mynet web

# Inspect
docker network inspect mynet

# Remove
docker network rm mynet
```

## Docker Compose

```bash
# Start services
docker compose up
docker compose up -d                    # detached
docker compose up --build               # rebuild images

# Stop services
docker compose down
docker compose down -v                  # remove volumes too
docker compose down --rmi all           # remove images too

# View logs
docker compose logs
docker compose logs -f web              # follow specific service

# Scale service
docker compose up -d --scale worker=3

# Exec into service
docker compose exec web /bin/sh

# List services
docker compose ps

# Rebuild single service
docker compose build web
docker compose up -d web
```

## Dockerfile Patterns

```dockerfile
# Multi-stage build
FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /app/server .

FROM alpine:3.19
COPY --from=builder /app/server /usr/local/bin/server
EXPOSE 8080
CMD ["server"]
```

```dockerfile
# Python with uv
FROM python:3.12-slim
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv
WORKDIR /app
COPY pyproject.toml uv.lock ./
RUN uv sync --locked --no-dev
COPY . .
CMD ["uv", "run", "python", "-m", "myapp"]
```

## System Cleanup

```bash
# Remove all stopped containers, unused networks, dangling images, build cache
docker system prune

# Include unused images and volumes
docker system prune -a --volumes

# Disk usage
docker system df
docker system df -v                     # verbose
```

## Useful Patterns

```bash
# Copy file from container
docker cp web:/etc/nginx/nginx.conf ./nginx.conf

# Copy file to container
docker cp ./config.yaml web:/app/config.yaml

# Export container filesystem
docker export web > web.tar

# Save/load image (offline transfer)
docker save myapp:latest > myapp.tar
docker load < myapp.tar

# Run with host network (linux)
docker run --network host nginx

# Healthcheck
docker run -d --health-cmd="curl -f http://localhost/ || exit 1" \
  --health-interval=30s --health-retries=3 nginx

# View container processes
docker top web

# Wait for container to exit
docker wait web
echo $?                                 # exit code
```
