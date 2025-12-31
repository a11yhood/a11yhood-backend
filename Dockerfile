# Simplified a11yhood backend Dockerfile
# Single-stage build for production
# Development mode enabled via volume mounts in scripts/start-dev.sh

FROM python:3.12-alpine

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apk add --no-cache \
    curl \
    gcc \
    musl-dev \
    linux-headers \
    && addgroup -g 1000 appuser \
    && adduser -D -u 1000 -G appuser appuser

# Install uv
RUN pip install --no-cache-dir uv

# Copy requirements
COPY requirements.txt .

# Install dependencies
RUN uv pip install --system -r requirements.txt

# Copy application code
COPY . .

# Ensure ownership and drop privileges
RUN chown -R appuser:appuser /app
USER appuser

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Default command (overridden in development by start-dev.sh)
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "4"]
