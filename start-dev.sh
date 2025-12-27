#!/bin/bash
# Start backend development server for a11yhood using Docker
# This script starts the backend API server on port 8000 in a Docker container
# 
# Usage:
#   ./start-dev.sh              # Normal start
#   ./start-dev.sh --reset-db   # Reset database before starting
#   ./start-dev.sh --help       # Show help

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Timing helper
SECONDS=0
ts() {
  # Prints elapsed seconds since script start
  echo "${SECONDS}s"
}

# Parse arguments
RESET_DB=false
HELP=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --reset-db)
      RESET_DB=true
      shift
      ;;
    --help)
      HELP=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      HELP=true
      shift
      ;;
  esac
done

if [ "$HELP" = true ]; then
  echo "Usage: ./start-dev.sh [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --reset-db   Reset database before starting (removes test.db volume) (removes test.db volume)"
  echo "  --help       Show this help message"
  exit 0
fi

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
  echo -e "${RED}✗ Docker is not running${NC}"
  echo "  Please start Docker (or Colima) first:"
  echo "    colima start"
  exit 1
fi

echo -e "${BLUE}🚀 Starting a11yhood backend development server (Docker)...${NC} (t=0s)"
echo ""

# Reset database if requested
if [ "$RESET_DB" = true ]; then
  echo -e "${YELLOW}🗑️  Resetting database volume...${NC}"
  docker-compose down -v
  echo -e "${GREEN}✓ Database volume removed${NC}"
  echo ""
fi

# Build if needed
echo -e "${YELLOW}🔨 Building Docker image...${NC} (t=$(ts))"
if docker-compose build backend 2>&1 | grep -q "Successfully built\|Image.*Built"; then
  echo -e "${GREEN}✓ Image ready${NC}"
else
  echo -e "${YELLOW}⚠️  Build completed with warnings (check output if needed)${NC}"
fi
echo ""

# Start container
echo -e "${GREEN}🚀 Starting backend container...${NC} (t=$(ts))"
echo "   Server will be available at: http://localhost:8000"
echo "   API documentation at: http://localhost:8000/docs"
echo "   (Development uses port 8000, production uses port 8001)"
echo ""

docker-compose up -d backend

if [ $? -ne 0 ]; then
  echo -e "${RED}✗ Failed to start container${NC}"
  exit 1
fi

# Wait for server to be ready
echo -e "${YELLOW}⏳ Waiting for server to start...${NC}"
for i in {1..30}; do
  if curl -s http://localhost:8000/health >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Backend is ready!${NC} (t=$(ts))"
    break
  fi
  
  # Check if container is still running
  if ! docker-compose ps backend | grep -q "Up"; then
    echo -e "${RED}✗ Container is not running${NC}"
    echo "  Check logs with: docker-compose logs backend"
    exit 1
  fi
  
  sleep 1
  
  # Show progress
  if [ $i -eq 10 ]; then
    echo "  Still waiting..."
  fi
  if [ $i -eq 20 ]; then
    echo "  Taking longer than usual..."
  fi
done

# Final check
if ! curl -s http://localhost:8000/health >/dev/null 2>&1; then
  echo -e "${RED}✗ Server failed to start within 30 seconds${NC}"
  echo "  Check logs with: docker-compose logs backend"
  docker-compose logs --tail=50 backend
  exit 1
fi

echo ""
echo -e "${GREEN}✅ Development environment is running!${NC} (t=$(ts))"
echo ""
echo -e "${BLUE}📡 Backend API:${NC}"
echo "   http://localhost:8000"
echo ""
echo -e "${BLUE}📚 API Documentation:${NC}"
echo "   http://localhost:8000/docs"
echo ""
echo -e "${BLUE}💡 To monitor logs:${NC}"
echo "   docker-compose logs -f backend"
echo ""
echo -e "${BLUE}🛑 To stop the server:${NC}"
echo "   ./stop-dev.sh"
echo ""
