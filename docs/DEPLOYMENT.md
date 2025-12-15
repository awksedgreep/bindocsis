# Deployment Guide

This guide covers deploying Bindocsis as a standalone web application using containers.

## Quick Start

The fastest way to run Bindocsis:

```bash
podman run -d -p 4555:4555 ghcr.io/awksedgreep/bindocsis:latest
```

Then open http://localhost:4555

## Container Images

Pre-built images are available on GitHub Container Registry:

- `ghcr.io/awksedgreep/bindocsis:latest` - Latest release
- `ghcr.io/awksedgreep/bindocsis:0.9.0` - Specific version

### Image Details

- **Base**: Debian Bullseye (slim)
- **Size**: ~126MB
- **Port**: 4555 (configurable)
- **Architecture**: Multi-platform (amd64, arm64)

## Running with Podman

### Basic Usage

```bash
# Run in foreground
podman run -p 4555:4555 ghcr.io/awksedgreep/bindocsis:latest

# Run in background (detached)
podman run -d -p 4555:4555 --name bindocsis ghcr.io/awksedgreep/bindocsis:latest

# View logs
podman logs bindocsis

# Stop and remove
podman stop bindocsis && podman rm bindocsis
```

### Custom Configuration

```bash
podman run -d -p 4555:4555 \
  -e PHX_HOST=myserver.example.com \
  -e PORT=4555 \
  --name bindocsis \
  ghcr.io/awksedgreep/bindocsis:latest
```

### With Persistent Storage

```bash
podman run -d -p 4555:4555 \
  -v bindocsis_data:/app/data \
  --name bindocsis \
  ghcr.io/awksedgreep/bindocsis:latest
```

## Running with Docker

Docker commands are identical to Podman:

```bash
docker run -d -p 4555:4555 --name bindocsis ghcr.io/awksedgreep/bindocsis:latest
```

## Using Podman Compose

Create a `podman-compose.yml` or use the one included in the repository:

```yaml
version: "3.8"

services:
  bindocsis:
    image: ghcr.io/awksedgreep/bindocsis:latest
    container_name: bindocsis
    restart: unless-stopped
    ports:
      - "4555:4555"
    environment:
      - PHX_SERVER=true
      - PHX_HOST=${PHX_HOST:-localhost}
      - PORT=4555
    volumes:
      - bindocsis_data:/app/data

volumes:
  bindocsis_data:
    driver: local
```

Then run:

```bash
podman-compose up -d
```

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `SECRET_KEY_BASE` | No | Auto-generated | 64+ byte secret for cookie signing |
| `PHX_HOST` | No | `localhost` | Hostname for URL generation |
| `PORT` | No | `4555` | HTTP port to listen on |
| `PHX_SERVER` | No | `true` | Enable web server |

**Note**: `SECRET_KEY_BASE` is automatically generated on container startup if not provided. For production deployments with multiple replicas, you should set this explicitly so all instances share the same secret.

## Building from Source

### Prerequisites

- Elixir 1.18+
- Podman or Docker

### Using Mix Tasks

```bash
# Build the container image (native architecture)
mix bindocsis.container.build

# Build for specific platform
mix bindocsis.container.build --platform amd64
mix bindocsis.container.build --platform arm64

# Push to ghcr.io (requires authentication)
mix bindocsis.container.push

# Build and push in one command
mix bindocsis.container.release

# Build with custom tag
mix bindocsis.container.build --tag 1.0.0

# Skip :latest tag
mix bindocsis.container.release --no-latest
```

**Note**: Cross-platform builds (e.g., building amd64 on ARM) require QEMU emulation which may not work reliably for Elixir/BEAM. For proper multi-arch images, use the GitHub Actions CI/CD workflow.

### CI/CD Multi-Arch Builds

The repository includes a GitHub Actions workflow (`.github/workflows/container.yml`) that automatically builds multi-arch images when you push a version tag:

```bash
# Tag a release (triggers CI build)
git tag v0.9.7
git push origin v0.9.7
```

This builds native `linux/amd64` and `linux/arm64` images and pushes a multi-arch manifest to ghcr.io. You can also trigger builds manually from the Actions tab.

### Manual Build

```bash
# Build
podman build -t bindocsis:latest .

# Tag for registry
podman tag bindocsis:latest ghcr.io/awksedgreep/bindocsis:latest

# Push (after logging in)
podman login ghcr.io
podman push ghcr.io/awksedgreep/bindocsis:latest
```

## Production Deployment

### Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bindocsis
spec:
  replicas: 1
  selector:
    matchLabels:
      app: bindocsis
  template:
    metadata:
      labels:
        app: bindocsis
    spec:
      containers:
      - name: bindocsis
        image: ghcr.io/awksedgreep/bindocsis:latest
        ports:
        - containerPort: 4555
        env:
        - name: SECRET_KEY_BASE
          valueFrom:
            secretKeyRef:
              name: bindocsis-secrets
              key: secret-key-base
        - name: PHX_HOST
          value: "bindocsis.example.com"
---
apiVersion: v1
kind: Service
metadata:
  name: bindocsis
spec:
  selector:
    app: bindocsis
  ports:
  - port: 80
    targetPort: 4555
  type: ClusterIP
```

### Behind a Reverse Proxy (nginx)

```nginx
server {
    listen 80;
    server_name bindocsis.example.com;

    location / {
        proxy_pass http://localhost:4555;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Systemd Service

```ini
[Unit]
Description=Bindocsis DOCSIS Config Manager
After=network.target

[Service]
Type=simple
User=bindocsis
ExecStart=/usr/bin/podman run --rm -p 4555:4555 --name bindocsis ghcr.io/awksedgreep/bindocsis:latest
ExecStop=/usr/bin/podman stop bindocsis
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

## Health Checks

The container exposes a health endpoint at `/`:

```bash
curl -f http://localhost:4555/ || echo "unhealthy"
```

## Troubleshooting

### Container won't start

Check logs:
```bash
podman logs bindocsis
```

### Port already in use

```bash
# Find what's using the port
lsof -i :4555

# Use a different port
podman run -d -p 8080:4555 ghcr.io/awksedgreep/bindocsis:latest
```

### Permission denied

If using rootless Podman, ensure the port is above 1024 or configure rootless port access.

## Security Considerations

- The container runs as a non-root user (`app`)
- `SECRET_KEY_BASE` is auto-generated but should be set explicitly for multi-replica deployments
- Consider using HTTPS via a reverse proxy for production
- The web UI has no authentication by default - use network-level access control or add a reverse proxy with auth
