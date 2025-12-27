# Multi-stage build for a11yhood backend
FROM python:3.14-slim AS base

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    gcc \
    g++ \
    make \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user for runtime
RUN useradd -m -u 1000 appuser

# Install uv for fast dependency management
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# Copy dependency files
COPY pyproject.toml uv.lock* ./

# Development stage
FROM base AS development

# Install dependencies only (skip building package)
RUN uv pip install --system aiosqlite annotated-doc beautifulsoup4 bleach \
    fastapi httpx lxml pydantic pydantic-settings python-dotenv python-multipart \
    requests requests-oauthlib slowapi sqlalchemy supabase 'uvicorn[standard]' \
    pytest pytest-asyncio

# Copy application code
COPY . .

# Copy entrypoint script
COPY entrypoint-dev.sh /app/

# Ensure ownership and drop privileges
RUN chown -R appuser:appuser /app && chmod +x /app/entrypoint-dev.sh
USER appuser

# Set environment to not create venv
ENV UV_PYTHON_INSTALL_DIR=/usr/local/bin
ENV UV_NO_VIRTUALENV=1

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Run with hot reload for development (seed database first)
CMD ["bash", "/app/entrypoint-dev.sh"]

# Production stage
FROM base AS production

# Install only production dependencies
RUN uv pip install --system aiosqlite annotated-doc beautifulsoup4 bleach \
    fastapi httpx lxml pydantic pydantic-settings python-dotenv python-multipart \
    requests requests-oauthlib slowapi supabase 'uvicorn[standard]'

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

# Run production server
CMD ["uv", "run", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "4"]
