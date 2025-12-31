# Simplified a11yhood backend Dockerfile
# Single-stage build for production
# Development mode enabled via volume mounts in scripts/start-dev.sh

# Use Debian bullseye which works better with fuse-overlayfs
FROM python:3.11-slim-bullseye

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    gcc \
    g++ \
    make \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir uv && uv pip install --system -r requirements.txt

# Copy application code
COPY . .

# Create non-root user and set ownership after all files are copied
RUN groupadd -g 1000 appuser \
    && useradd -m -u 1000 -g appuser appuser \
    && chown -R appuser:appuser /app

USER appuser

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Default command (overridden in development by start-dev.sh)
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "4"]
