FROM python:3.12-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Install uv for fast dependency management
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# Copy dependency files
COPY pyproject.toml uv.lock ./

# Install dependencies (no dev dependencies in prod)
RUN uv sync --frozen --no-dev

# Copy application code
COPY app/ app/

# Railway sets PORT; default to 8000 for local testing
ENV PORT=8000

CMD uv run uvicorn app.main:app --host 0.0.0.0 --port $PORT
