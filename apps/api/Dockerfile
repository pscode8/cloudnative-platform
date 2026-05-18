# syntax=docker/dockerfile:1

# ── base stage (sets up environment) ─────────────
FROM python:3.11-slim AS base
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH"

WORKDIR /app

# Create a virtual environment instead of installing system-wide
RUN python -m venv /opt/venv

# ── deps stage (installs production deps) ────────
FROM base AS deps
COPY pyproject.toml .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir e "."

# ── dev stage (hot reload, all deps) ─────────────
FROM deps AS dev
# Install dev dependencies
RUN pip install --no-cache-dir -e ".[dev]"

# Keep your local development user
RUN groupadd --gid 1000 appuser && \
    useradd --uid 1000 --gid 1000 --no-create-home appuser && \
    chown -R appuser:appuser /app

COPY . .
USER appuser
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]

# ── test stage (used by CI) ──────────────────────
FROM dev AS test
RUN pytest tests/ -v

# ── prod stage (minimal, distroless, 0 CVEs) ─────
FROM gcr.io/distroless/python3-debian12 AS prod
WORKDIR /app
ENV PYTHONPATH=/app \
    PATH="/opt/venv/bin:$PATH"

# 1. Copy the isolated virtual environment from your deps stage
COPY --from=deps /opt/venv /opt/venv

# 2. Copy the source code.
# Distroless uses a built-in non-root user called "nonroot" (UID 65532)
COPY --chown=65532:65532 src/ ./src/

USER 65532:65532

# 3. Maintain exact Healthcheck functionality using Python instead of curl.
# This prevents us from needing to install vulnerable networking tools.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD ["/opt/venv/bin/python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8000/healthz')"]

EXPOSE 8000

# 4. Run your exact production command
CMD ["/opt/venv/bin/uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "2"]
