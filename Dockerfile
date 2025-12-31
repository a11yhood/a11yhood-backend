# a11yhood backend Dockerfile
# Works in GitHub Actions CI/CD
# NOTE: Currently CANNOT be deployed to slicomex.cs.washington.edu due to
# fuse-overlayfs storage driver incompatibility. See documentation/DEPLOYMENT_CURRENT.md

FROM python:3.12-slim

RUN echo "=== BUILD DEBUG: Starting build from python:3.12-slim ==="
RUN echo "=== Python version:" && python --version
RUN echo "=== OS info:" && cat /etc/os-release | head -5

# Set working directory
WORKDIR /app
RUN echo "=== Working directory set to /app ==="

# Copy requirements first for layer caching
COPY requirements.txt .
RUN echo "=== Requirements file copied, contents:" && head -10 requirements.txt

# Install Python dependencies
RUN echo "=== Installing Python dependencies ===" && \
    pip install --no-cache-dir -r requirements.txt && \
    echo "=== Dependency installation complete ===" && \
    pip list | head -20

# Copy application code
COPY . .
RUN echo "=== Application code copied ===" && \
    echo "=== File count:" && ls -la | wc -l && \
    echo "=== Main files:" && ls -la *.py 2>/dev/null || echo "No .py files in root"

# Create non-root user and set ownership
RUN groupadd -g 1000 appuser \
    && useradd -m -u 1000 -g appuser appuser \
    && chown -R appuser:appuser /app

USER appuser

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

RUN echo "=== BUILD COMPLETE - ready to start uvicorn ==="

# Default command (overridden in development by start-dev.sh)
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "4"]
