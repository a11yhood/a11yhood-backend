#!/bin/bash
# Convenient helper to run seed scripts
# Works with both running Docker containers and direct Python execution
#
# Usage:
#   ./scripts/seed.sh              # Run seeds (detects Docker or direct)
#   ./scripts/seed.sh --list       # List available seeds
#   ./scripts/seed.sh --help       # Show help
#   ./scripts/seed.sh --in-docker  # Force run inside Docker container

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON="${SCRIPT_DIR}/.venv/bin/python"
IN_DOCKER=false

# Check if we should run inside Docker
if [ "$1" = "--in-docker" ]; then
  IN_DOCKER=true
  shift
fi

# Auto-detect if container is running
if [ "$IN_DOCKER" = false ] && docker ps --filter "name=a11yhood-backend-dev" --format "{{.Names}}" | grep -q "a11yhood-backend-dev"; then
  echo "📦 Detected running Docker container 'a11yhood-backend-dev'"
  echo "   Running seeds inside container..."
  IN_DOCKER=true
fi

# Show help
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    cat << 'EOF'
Seed Script Runner - a11yhood Backend

Usage:
  ./scripts/seed.sh              Run all development seeds
  ./scripts/seed.sh --list       List available seeds
  ./scripts/seed.sh --help       Show this help message
  ./scripts/seed.sh --in-docker  Force running inside Docker container
  
Advanced usage:
  # Run with options (pass through to run_seeds.py)
  ./scripts/seed.sh --include supported_sources,oauth_configs
  ./scripts/seed.sh --exclude test_product,test_collections
  
Environment:
  ENV_FILE              Override default .env.test location
                        (e.g., ENV_FILE=.env ./scripts/seed.sh)

Examples:
  # Run all seeds for development
  ./scripts/seed.sh
  
  # Run only database setup, skip test data
  ./scripts/seed.sh --exclude test_product,test_collections
  
  # See what seeds are available
  ./scripts/seed.sh --list
  
  # Seed the running Docker dev container
  ./scripts/seed.sh --in-docker

EOF
    exit 0
fi

if [ "$IN_DOCKER" = true ]; then
  # Run inside Docker container
  echo "🌱 Running seed scripts inside Docker container..."
  docker exec -w /app a11yhood-backend-dev bash -c "export ENV_FILE=.env.test && /usr/local/bin/python3 seed_scripts/run_seeds.py $@"
else
  # Run locally with venv
  if [ ! -f "$PYTHON" ]; then
    echo "Error: Python virtual environment not found at $SCRIPT_DIR/.venv"
    echo "Please set up the virtual environment first"
    exit 1
  fi

  echo "🌱 Running seed scripts..."
  "$PYTHON" "$SCRIPT_DIR/seed_scripts/run_seeds.py" "$@"
fi

