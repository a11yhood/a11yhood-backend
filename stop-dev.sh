#!/bin/bash
# Stop backend development server for a11yhood
#
# Usage:
#   ./stop-dev.sh              # Stop backend server
#   ./stop-dev.sh --help       # Show help

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
HELP=false

while [[ $# -gt 0 ]]; do
  case $1 in
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
  echo "Usage: ./stop-dev.sh [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --help       Show this help message"
  exit 0
fi

echo -e "${BLUE}🛑 Stopping a11yhood backend development server (Docker)...${NC}"
echo ""

# Stop container
echo -e "${YELLOW}Stopping backend container...${NC}"
if docker-compose ps backend 2>/dev/null | grep -q "Up"; then
  docker-compose stop backend
  echo -e "${GREEN}✓ Backend container stopped${NC}"
else
  echo "  (Backend was not running)"
fi

echo ""
echo -e "${GREEN}✅ Backend development server stopped${NC}"
echo ""
echo -e "${BLUE}💡 To remove the container and volumes:${NC}"
echo "   docker-compose down -v"
echo ""
