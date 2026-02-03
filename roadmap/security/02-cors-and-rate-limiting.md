# CORS Restrictions and Rate Limiting

Lock down cross-origin access and prevent brute force attacks.

## Problem

### CORS is wide open

```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],          # Any website can call our API
    allow_credentials=True,        # With cookies/auth headers
    allow_methods=["*"],
    allow_headers=["*"],
)
```

This enables CSRF attacks - a malicious website can make authenticated requests on behalf of logged-in users.

### No rate limiting

Authentication endpoints can be brute-forced. File uploads can be abused for DoS.

## Solution

### 1. Restrict CORS to known origins

```python
# config.py
class Settings(BaseSettings):
    # Comma-separated list of allowed origins
    cors_origins: str = "http://localhost:3000"

    @property
    def cors_origins_list(self) -> list[str]:
        if self.environment == "dev":
            return ["*"]  # Allow all in dev for convenience
        return [origin.strip() for origin in self.cors_origins.split(",")]
```

```python
# main.py
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE"],
    allow_headers=["Authorization", "Content-Type"],
)
```

For iOS app: CORS doesn't apply to native apps (only browser Same-Origin Policy). The iOS app makes direct requests, so this only affects web clients.

### 2. Add rate limiting with slowapi

```bash
uv add slowapi
```

```python
# main.py
from slowapi import Limiter
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware

limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter
app.add_middleware(SlowAPIMiddleware)

@app.exception_handler(RateLimitExceeded)
async def rate_limit_handler(request, exc):
    return JSONResponse(
        status_code=429,
        content={"detail": "Rate limit exceeded. Try again later."}
    )

# Auth endpoints: strict limits
@app.post("/auth/apple")
@limiter.limit("10/minute")
def apple_auth(...): ...

@app.post("/auth/dev-login")
@limiter.limit("5/minute")
def dev_login(...): ...

# General endpoints: reasonable limits
@app.post("/pieces")
@limiter.limit("30/minute")
def create_piece(...): ...

# Read endpoints: higher limits
@app.get("/pieces")
@limiter.limit("100/minute")
def get_pieces(...): ...
```

### 3. Rate limit configuration

```python
# config.py
class Settings(BaseSettings):
    rate_limit_auth: str = "10/minute"
    rate_limit_write: str = "30/minute"
    rate_limit_read: str = "100/minute"
```

## Files to Change

- `server/pyproject.toml` - Add slowapi dependency
- `server/app/config.py` - Add CORS and rate limit settings
- `server/app/main.py` - Configure CORS properly, add rate limiting

## Tests

- [ ] CORS allows configured origins in staging/prod
- [ ] CORS blocks unconfigured origins in staging/prod
- [ ] CORS allows all origins in dev (for convenience)
- [ ] Rate limit returns 429 after threshold exceeded
- [ ] Rate limit resets after time window
- [ ] Auth endpoints have stricter limits than read endpoints

## Deployment Notes

Set in Railway environment:
```
CORS_ORIGINS=https://cadenza.loopflow.studio,https://staging.cadenza.loopflow.studio
```

## iOS Impact

None. CORS is a browser security feature. Native iOS apps are not subject to Same-Origin Policy.

## Definition of Done

- [ ] CORS restricted to explicit origins in non-dev
- [ ] Rate limiting active on all endpoints
- [ ] 429 responses for exceeded limits
- [ ] Tests verify CORS and rate limit behavior
