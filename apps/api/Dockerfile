# syntax=docker/dockerfile:1.6
# ─────────────────────────────────────────────────────────────────────────────
# Multi-stage build:
#   builder      → installs prod deps into an isolated venv (never deployed)
#   builder-dev  → extends builder with dev/test deps (never deployed)
#   dev          → hot-reload runtime for local docker compose
#   prod         → Chainguard hardened image — zero-CVE attack surface
# ─────────────────────────────────────────────────────────────────────────────

# ── Stage 1: prod dependency builder ─────────────────────────────────────────
FROM python:3.13-slim AS builder
WORKDIR /build

# gcc required by some async drivers (asyncpg, aiokafka)
RUN apt-get update \
 && apt-get install -y --no-install-recommends gcc \
 && rm -rf /var/lib/apt/lists/*

# Isolated venv — portable: copy to any final base image safely
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY pyproject.toml .
RUN pip install --no-cache-dir --upgrade pip \
 && pip install --no-cache-dir -e "."

# ── Stage 2: dev+test dependency builder ─────────────────────────────────────
FROM python:3.13-slim AS builder-dev
WORKDIR /build

RUN apt-get update \
 && apt-get install -y --no-install-recommends gcc \
 && rm -rf /var/lib/apt/lists/*

# Inherit prod venv, then layer dev extras on top
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY pyproject.toml .
RUN pip install --no-cache-dir -e ".[dev]"

# ── Stage 3: dev runtime (local only — never pushed to registry) ──────────────
FROM python:3.13-slim AS dev
WORKDIR /app

RUN apt-get update \
 && apt-get install -y --no-install-recommends curl \
 && rm -rf /var/lib/apt/lists/*

RUN groupadd --gid 1000 appuser \
 && useradd --uid 1000 --gid 1000 --no-create-home appuser

COPY --from=builder-dev /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY . .
USER appuser

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8000/healthz || exit 1

EXPOSE 8000
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]

# ── Stage 4: prod (Chainguard — hardened, minimal, near-zero CVE) ─────────────
# Chainguard images are rebuilt daily against CVE databases.
# Runs as nonroot (uid 65532) by default — no shell, no package manager.
# https://images.chainguard.dev/directory/image/python/versions
FROM cgr.dev/chainguard/python:latest AS prod
WORKDIR /app

# Copy only the production venv — no build tools, no compilers, no shell utils
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy application source only
COPY src/ ./src/

EXPOSE 8000

# Kubernetes liveness/readiness probes handle health — no Docker HEALTHCHECK needed in prod
ENTRYPOINT ["/opt/venv/bin/python", "-m", "uvicorn", "src.main:app", \
            "--host", "0.0.0.0", "--port", "8000", "--workers", "2"]
