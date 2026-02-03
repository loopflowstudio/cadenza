# Security Hardening

## Problem

Cadenza handles sensitive data between minors (students) and adults (teachers). The current implementation has development-time shortcuts that are dangerous in production:

1. **Apple ID token verification is disabled** - any valid-looking JWT is accepted
2. **Hardcoded secrets** - JWT signing key is a dev default
3. **CORS allows all origins** - browser security bypassed
4. **No rate limiting** - vulnerable to brute force and enumeration
5. **Dev login endpoint exists in prod path** - backdoor with DEBUG check only

The app cannot ship without fixing these. A breach exposes children's practice data and teacher-student relationships.

## Approach

Fix the critical authentication issues first. Then add defense-in-depth layers. Defer compliance features (COPPA, audit logging) to a later wave.

**Phase 1: Authentication hardening**
- Enable Apple ID token signature verification using Apple's public keys
- Move JWT secret to environment variable with no default
- Remove dev-login endpoint from production builds entirely

**Phase 2: API hardening**
- Restrict CORS to specific allowed origins
- Add rate limiting to auth endpoints (10 req/min per IP)
- Sanitize error messages to prevent enumeration

**Phase 3: Transport security**
- Enforce HTTPS only (redirect HTTP)
- Add security headers (HSTS, CSP, X-Frame-Options)

## Alternatives considered

| Approach | Tradeoff | Why not |
|----------|----------|---------|
| Add auth provider (Auth0, Firebase) | Simpler to implement, more features | Adds external dependency and cost; Apple Sign In is already implemented |
| Certificate pinning on iOS | Stronger protection against MITM | Complicates certificate rotation; standard TLS is sufficient for this threat model |
| End-to-end encryption of practice data | Maximum privacy | Over-engineered for practice logs; adds complexity without proportional benefit |
| COPPA compliance in this wave | Required eventually for users under 13 | Larger scope; needs product decisions about age verification; defer to dedicated wave |

## Key decisions

1. **Keep Apple Sign In as sole auth mechanism.** Adding username/password creates new attack surface. Apple handles 2FA, account recovery, and credential management. Teachers and students both use Apple devices.

2. **Environment-based configuration only.** No fallback defaults for secrets. The app must fail to start without proper configuration. This prevents accidental production deployment with dev settings.

3. **Rate limiting at application layer, not infrastructure.** Using `slowapi` in FastAPI rather than nginx/cloudflare. Simpler to test, stays with the code, sufficient for launch scale. Can add infrastructure-level protection later.

4. **Defer audit logging.** Important for compliance, but not a launch blocker. The current risk is unauthorized access, not forensics.

## Scope

**In scope:**
- Apple ID token signature verification against Apple's JWKS endpoint
- JWT secret from environment (fail if missing)
- Remove dev-login endpoint from production
- CORS origin allowlist
- Rate limiting on `/auth/*` endpoints
- Error message sanitization in auth flows
- Security headers middleware
- HTTPS enforcement

**Out of scope:**
- COPPA compliance (age verification, parental consent)
- Audit logging
- Database encryption at rest (use managed DB with encryption)
- Certificate pinning
- Jailbreak detection
- S3 object encryption (use S3 default encryption)
- Email verification for teacher invitations

## Implementation

### 1. Apple ID token verification

```python
# server/app/apple_auth.py
import httpx
from jose import jwt, jwk
from cachetools import TTLCache

APPLE_JWKS_URL = "https://appleid.apple.com/auth/keys"
_jwks_cache: TTLCache = TTLCache(maxsize=1, ttl=3600)

async def get_apple_public_keys() -> dict:
    if "keys" not in _jwks_cache:
        async with httpx.AsyncClient() as client:
            resp = await client.get(APPLE_JWKS_URL)
            resp.raise_for_status()
            _jwks_cache["keys"] = resp.json()["keys"]
    return _jwks_cache["keys"]

async def verify_apple_id_token(id_token: str, client_id: str) -> dict:
    keys = await get_apple_public_keys()
    header = jwt.get_unverified_header(id_token)

    key = next((k for k in keys if k["kid"] == header["kid"]), None)
    if not key:
        raise ValueError("Unknown key ID")

    public_key = jwk.construct(key)
    return jwt.decode(
        id_token,
        public_key,
        algorithms=["RS256"],
        audience=client_id,
        issuer="https://appleid.apple.com",
    )
```

### 2. Configuration hardening

```python
# server/app/config.py
import os

def get_required_env(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        raise RuntimeError(f"Required environment variable {name} not set")
    return value

class Settings:
    jwt_secret: str = get_required_env("JWT_SECRET")
    apple_client_id: str = get_required_env("APPLE_CLIENT_ID")
    allowed_origins: list[str] = os.environ.get("ALLOWED_ORIGINS", "").split(",")
    debug: bool = os.environ.get("DEBUG", "").lower() == "true"
```

### 3. Rate limiting

```python
# server/app/rate_limit.py
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)

# In main.py
@app.post("/auth/apple")
@limiter.limit("10/minute")
async def apple_auth(...):
    ...
```

### 4. Security headers

```python
# server/app/middleware.py
from starlette.middleware.base import BaseHTTPMiddleware

class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        response = await call_next(request)
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["X-XSS-Protection"] = "1; mode=block"
        return response
```

### 5. Error sanitization

Replace specific auth errors with generic messages:

```python
# Before
raise HTTPException(status_code=401, detail="Invalid Apple ID token")
raise HTTPException(status_code=404, detail=f"User not found for id {user_id}")

# After
raise HTTPException(status_code=401, detail="Authentication failed")
```

### 6. Dev endpoint removal

Delete the `/auth/dev-login` endpoint entirely. Use proper test fixtures instead.

## Done when

All of these pass:

```bash
# 1. Server fails to start without required env vars
JWT_SECRET= python -c "from app.config import Settings; Settings()"
# Expected: RuntimeError

# 2. Apple token verification rejects unsigned tokens
curl -X POST localhost:8000/auth/apple \
  -H "Content-Type: application/json" \
  -d '{"id_token": "eyJ...fake..."}'
# Expected: 401

# 3. Rate limiting blocks excessive requests
for i in {1..15}; do curl -X POST localhost:8000/auth/apple -d '{}'; done
# Expected: 429 after 10 requests

# 4. CORS rejects unknown origins
curl -H "Origin: https://evil.com" -I localhost:8000/health
# Expected: No Access-Control-Allow-Origin header

# 5. Dev login endpoint does not exist
curl -X POST localhost:8000/auth/dev-login
# Expected: 404

# 6. Security headers present
curl -I localhost:8000/health | grep -E "(Strict-Transport|X-Frame-Options)"
# Expected: Both headers present

# 7. All existing tests pass
python dev.py test --server
```

## Files to modify

- `server/app/config.py` - Required env vars, fail-fast
- `server/app/auth.py` - Apple token verification, error sanitization
- `server/app/main.py` - Remove dev-login, add rate limiting, CORS config
- `server/app/middleware.py` (new) - Security headers
- `server/app/apple_auth.py` (new) - Apple JWKS verification
- `server/app/rate_limit.py` (new) - Rate limiter setup
- `server/tests/test_auth.py` - Update tests for new behavior
- `server/pyproject.toml` - Add slowapi, httpx, cachetools, python-jose dependencies
