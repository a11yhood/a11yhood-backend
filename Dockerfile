# Simplified a11yhood backend Dockerfile
# Single-stage build for production
# Development mode enabled via volume mounts in scripts/start-dev.sh

FROM python:3.14-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    gcc \
    g++ \
    make \
    && rm -rf /var/lib/apt/lists/*

# Install uv for fast dependency management (using pip to avoid COPY --from issues on macOS)
RUN pip install uv

# Create non-root user for runtime
RUN useradd -m -u 1000 appuser

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
