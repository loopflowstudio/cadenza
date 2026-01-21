# Cadenza Server

FastAPI backend for Cadenza music practice app.

## Quick Start

### Using Docker (Recommended)

```bash
docker-compose up
```

The API will be available at `http://localhost:8000`

### Local Development

1. Install dependencies with uv:
```bash
uv pip install -r requirements.txt
```

2. Start PostgreSQL (or use Docker for just the DB):
```bash
docker-compose up db
```

3. Run the server:
```bash
uv run uvicorn app.main:app --reload
```

## Testing

```bash
uv run pytest tests/
```

## API Endpoints

- `POST /auth/apple` - Authenticate with Apple ID token
- `GET /auth/me` - Get current user info (requires JWT)
