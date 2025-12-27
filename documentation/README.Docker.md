# Docker Setup for a11yhood Backend

This document describes how to run the a11yhood backend in Docker containers.

## Prerequisites

- Docker Engine 20.10+ or Docker Desktop
- Docker Compose 2.0+
- On macOS: Colima (recommended) or Docker Desktop

### macOS Setup with Colima

```bash
# Install Colima
brew install colima docker docker-compose

# Start Docker runtime
colima start
```

## Quick Start

### Using Shell Scripts (Recommended)

The easiest way to run the backend is using the provided shell scripts:

**Development Mode:**
```bash
./start-dev.sh              # Start development server
./start-dev.sh --reset-db   # Reset database and start
./stop-dev.sh               # Stop development server
```

**Production Mode:**
```bash
./start-prod.sh             # Start production server
./stop-prod.sh              # Stop production server
```

These scripts handle:
- Docker runtime validation
- Image building
- Container startup/shutdown
- Health checks
- Helpful output and error messages

### Using Docker Compose Directly

#### Development Mode

Run the backend in development mode with hot reload:

```bash
# Build and start the container
docker-compose up -d

# View logs
docker-compose logs -f backend

# Stop the container
docker-compose down
```

The API will be available at http://localhost:8000

#### Production Mode

Run the backend in production mode:

```bash
# Build and start production container
docker-compose --profile production up -d backend-prod

# View logs
docker-compose logs -f backend-prod

# Stop
docker-compose --profile production down
```

## Docker Commands

### Build Images

```bash
# Build development image
docker-compose build backend

# Build production image
docker-compose build backend-prod

# Force rebuild without cache
docker-compose build --no-cache backend
```

### Run Containers

```bash
# Start in detached mode
docker-compose up -d

# Start with logs
docker-compose up

# Start specific service
docker-compose up backend

# Start production service
docker-compose --profile production up backend-prod
```

### View Logs

```bash
# Follow logs
docker-compose logs -f

# View last 100 lines
docker-compose logs --tail=100

# View logs for specific service
docker-compose logs -f backend
```

### Execute Commands in Container

```bash
# Run shell in running container
docker-compose exec backend bash

# Run tests
docker-compose exec backend uv run pytest

# Run database migrations
docker-compose exec backend uv run python migrations/migrate.py

# Create admin user
docker-compose exec backend uv run python make_admin.py <username>
```

### Stop and Clean Up

```bash
# Stop containers
docker-compose stop

# Stop and remove containers
docker-compose down

# Remove containers, networks, and volumes
docker-compose down -v

# Remove containers and images
docker-compose down --rmi all
```

## Environment Configuration

### Development (.env.test)

The default development setup uses `.env.test` with SQLite database.

```bash
# Start with default test environment
docker-compose up -d
```

### Production (.env)

For production, create a `.env` file with your Supabase credentials:

```bash
# Copy example
cp .env.example .env

# Edit with your production values
nano .env

# Start production container
docker-compose --profile production up -d backend-prod
```

### Custom Environment

Use a different environment file:

```bash
# Set environment file
export ENV_FILE=.env.custom

# Start container
docker-compose up -d
```

## Volume Mounts

Development mode mounts your local code into the container for hot reload:

- Source code: `./` → `/app`
- Virtual env excluded: `/app/.venv`
- Cache excluded: `/app/__pycache__`

Production mode doesn't mount local code - it's copied into the image at build time.

## Health Checks

Both containers include health checks that verify the `/health` endpoint:

- **Interval**: 30 seconds
- **Timeout**: 3 seconds
- **Retries**: 3
- **Start period**: 5s (dev), 10s (prod)

Check health status:

```bash
docker-compose ps
```

## Networking

All services run on the `a11yhood-network` bridge network. This allows:

- Backend to communicate with future frontend container
- Backend to communicate with local Supabase
- Isolation from other Docker networks

## Troubleshooting

### Container won't start

```bash
# Check logs
docker-compose logs backend

# Check if port 8000 is already in use
lsof -i :8000

# Rebuild without cache
docker-compose build --no-cache backend
```

### Permission errors

```bash
# Fix ownership (if needed in development)
sudo chown -R $USER:$USER .

# Production uses non-root user automatically
```

### Database connection issues

```bash
# Check environment variables
docker-compose exec backend env | grep -E 'DATABASE|SUPABASE'

# Test database connection
docker-compose exec backend uv run python -c "from services.database import get_db; print('DB OK')"
```

### Hot reload not working

```bash
# Ensure volumes are mounted correctly
docker-compose config

# Restart container
docker-compose restart backend
```

## Building for Different Platforms

### Multi-platform builds

```bash
# Build for AMD64 and ARM64
docker buildx build --platform linux/amd64,linux/arm64 -t a11yhood-backend:latest .
```

## Best Practices

1. **Development**: Use `docker-compose up` to see logs in real-time
2. **Production**: Use `docker-compose up -d` to run in background
3. **Testing**: Run tests before building production images
4. **Secrets**: Never commit `.env` files with real credentials
5. **Updates**: Rebuild images after dependency changes: `docker-compose build`
6. **Cleanup**: Regularly clean up with `docker system prune`

## Integration with CI/CD

Example GitHub Actions workflow:

```yaml
- name: Build Docker image
  run: docker build -t a11yhood-backend:${{ github.sha }} .

- name: Run tests in container
  run: |
    docker run --env-file .env.test a11yhood-backend:${{ github.sha }} \
      uv run pytest
```

## Next Steps

- Add frontend service to docker-compose.yml
- Set up Nginx reverse proxy
- Configure SSL certificates
- Add monitoring (Prometheus, Grafana)
- Set up container orchestration (Kubernetes)
