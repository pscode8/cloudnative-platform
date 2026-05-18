# syntax=docker/dockerfile:1
FROM python:3.11-slim AS base
WORKDIR /app
 
RUN apt-get update && apt-get install -y --no-install-recommends     curl     && rm -rf /var/lib/apt/lists/*
 
RUN groupadd --gid 1000 appuser     && useradd --uid 1000 --gid 1000 --no-create-home appuser
 
# ── deps stage ───────────────────────────────────
FROM base AS deps
COPY pyproject.toml .
RUN pip install --no-cache-dir --upgrade pip     && pip install --no-cache-dir -e "."
 
# ── dev stage (hot reload, all deps) ─────────────
FROM deps AS dev
RUN pip install --no-cache-dir -e ".[dev]"
COPY . .
USER appuser
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
 
# ── test stage (used by CI) ──────────────────────
FROM dev AS test
RUN pytest tests/ -v
 
# ── prod stage (minimal, non-root) ───────────────
FROM base AS prod
COPY --from=deps /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=deps /usr/local/bin /usr/local/bin
COPY --chown=appuser:appuser src/ ./src/
USER appuser
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3     CMD curl -f http://localhost:8000/healthz || exit 1
EXPOSE 8000
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "2"]
