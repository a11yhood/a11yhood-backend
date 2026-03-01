#!/usr/bin/env bash
set -euo pipefail

# Checkout the latest origin/production branch after a PR merge
# Usage: ./scripts/checkout-production.sh

git fetch origin
# Switch to local production (create it tracking origin/production if missing)
if git rev-parse --verify production >/dev/null 2>&1; then
  git checkout production
else
  git checkout -b production origin/production
fi
# Fast-forward to the latest remote state
git rebase origin/production

echo "✅ production branch is now at origin/production"
