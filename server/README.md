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

## Secure Deployment

The server relies on infrastructure-level security for production deployments.

### HTTPS

The server expects HTTPS termination at a load balancer or reverse proxy. It does not handle TLS directly. In non-dev environments, the server:
- Redirects HTTP to HTTPS (based on `X-Forwarded-Proto` header)
- Sets secure response headers (HSTS, X-Content-Type-Options, etc.)

Ensure your load balancer sets `X-Forwarded-Proto: https` for HTTPS requests.

### Database

Use a managed PostgreSQL instance with:
- Encryption at rest enabled
- TLS for connections
- Network isolation (private subnet, no public IP)

The server validates that `DATABASE_URL` is not the default value in non-dev environments.

### File Storage

If using S3 or compatible storage:
- Enable default encryption (SSE-S3 or SSE-KMS)
- Block public access
- Use IAM roles for access (not long-lived keys)

### Environment Variables

Required for production:

| Variable | Description |
|----------|-------------|
| `ENVIRONMENT` | Set to `staging` or `production` |
| `DATABASE_URL` | PostgreSQL connection string (must not be default) |
| `JWT_SECRET_KEY` | Secret for signing JWTs (must not be default) |
| `APPLE_CLIENT_ID` | iOS app bundle ID for Apple Sign-In verification |
| `CORS_ORIGINS` | Comma-separated allowed origins |

### Rate Limiting

The server applies rate limits per IP address:
- Auth endpoints: 10/minute
- Write endpoints: 30/minute
- Read endpoints: 100/minute

For multi-instance deployments, rate limit state is per-instance (in-memory). Consider a shared Redis backend for consistent enforcement across instances.
