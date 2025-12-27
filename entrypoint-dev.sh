#!/bin/bash
# Development server entrypoint
# Deletes old database, seeds it, and then starts the uvicorn server with hot reload

set -e

echo "Cleaning up old database..."
rm -f /tmp/a11yhood-test.db

echo "Seeding database..."
python seed_all.py

echo "Database seeding complete. Starting server..."
exec uv run uvicorn main:app --host 0.0.0.0 --port 8000 --reload
