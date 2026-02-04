# Secure Development Authentication

Make dev authentication features safe for all environments.

## Problem

The server has dev conveniences that are currently production vulnerabilities:

1. **Dev token pattern** (`auth.py:54-72`): `dev_token_user_X` grants access without JWT verification—works in production and can impersonate any user by guessing their integer ID
2. **Dev-login endpoint** (`main.py:37-66`): Creates/logs in users by email alone—no authentication required, works in production
3. **Hardcoded secrets** (`config.py:11,14`): Default JWT secret and database URL work if environment variables aren't set—server starts successfully with insecure defaults

These aren't theoretical. Someone who discovers the API could:
- Use `dev_token_user_1` to impersonate the first user
- POST to `/auth/dev-login` with a teacher's email to gain their account
- Exploit the hardcoded JWT secret to forge tokens

## Approach

Gate dev features behind environment check. Fail fast in production if secrets aren't set.

**Keep dev tokens working in dev.** The dev token pattern is useful for local development and testing. Instead of removing it, make it safe:
- Only works when `ENVIRONMENT=dev`
- Only works for users created via dev-login (apple_user_id starts with `dev_`)

**Keep dev-login endpoint in dev.** Same pattern—useful locally, dangerous in production. Return 404 in non-dev environments.

**Require secrets in production.** Server must refuse to start if `ENVIRONMENT` is `staging` or `prod` and secrets aren't set. No fallback defaults.

## Alternatives considered

| Approach | Tradeoff | Why not |
|----------|----------|---------|
| Remove dev features entirely | Cleanest production code | Breaks local development workflow; need to set up Apple Sign-In for every test |
| Feature flags in code | Could toggle per-deployment | Adds complexity; environment variable is simpler and can't be accidentally left on |
| Separate dev/prod codepaths | Complete isolation | Maintenance burden; easy to diverge and miss bugs |
| Compile-time removal | Can't accidentally deploy | Python doesn't have compile-time; environment check is the equivalent |

## Key decisions

1. **Dev tokens restricted by user type, not just environment.** Even in dev, you can't use `dev_token_user_X` to impersonate a real Apple Sign-In user. Only works for users whose `apple_user_id` starts with `dev_`. This prevents testing from accidentally crossing into real user data.

2. **404 not 403 for dev-login in production.** Returning 403 ("Forbidden") confirms the endpoint exists. 404 ("Not found") reveals nothing—looks like the endpoint was never built.

3. **Fail at startup, not at request time.** If secrets are missing, the server won't start. This catches misconfiguration immediately rather than failing the first auth request.

4. **Use `is_dev` property, not string comparison.** Single source of truth for environment checks. Avoids typos like `environment == "Dev"`.

5. **Keep dev defaults for dev environment.** In dev mode, the defaults continue to work. Only non-dev environments require explicit configuration. This preserves the zero-config local dev experience.

## Scope

**In scope:**
- Add `is_dev` property to Settings
- Gate dev-login endpoint behind `is_dev` check
- Gate dev token path behind `is_dev` AND `apple_user_id.startswith("dev_")` check
- Add pydantic validator to require `DATABASE_URL` and `JWT_SECRET_KEY` in non-dev
- Reject default JWT secret in non-dev environments
- Update tests to verify gating works

**Out of scope:**
- Apple Sign-In token verification (separate item: 03-apple-signin-verification)
- CORS restrictions (separate item: 02-cors-and-rate-limiting)
- Rate limiting (separate item: 02-cors-and-rate-limiting)
- Error message sanitization

## Implementation

### 1. Add environment property and validation to config

```python
# config.py
from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import model_validator


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    environment: str = "dev"
    database_url: str = "postgresql://cadenza:cadenza_dev@localhost:5432/cadenza"
    jwt_secret_key: str = "dev_secret_key_change_in_production"
    jwt_algorithm: str = "HS256"
    jwt_expiration_hours: int = 24 * 7
    s3_bucket: str = "loopflow"
    aws_region: str = "us-west-2"

    @property
    def is_dev(self) -> bool:
        return self.environment == "dev"

    @property
    def is_production(self) -> bool:
        return self.environment == "prod"

    @model_validator(mode="after")
    def validate_production_settings(self) -> "Settings":
        if self.environment != "dev":
            # In staging/prod, database_url must be explicitly set (not the dev default)
            if self.database_url == "postgresql://cadenza:cadenza_dev@localhost:5432/cadenza":
                raise ValueError("DATABASE_URL must be set in non-dev environments")
            # JWT secret must be explicitly set (not the dev default)
            if self.jwt_secret_key == "dev_secret_key_change_in_production":
                raise ValueError("JWT_SECRET_KEY must be set in non-dev environments")
        return self


settings = Settings()
```

### 2. Gate dev-login endpoint

```python
# main.py
@app.post("/auth/dev-login", response_model=schemas.AuthResponse)
def dev_login(email: str, db: Annotated[Session, Depends(get_db)]):
    if not settings.is_dev:
        raise HTTPException(status_code=404, detail="Not found")
    # ... existing logic unchanged
```

### 3. Gate dev token authentication

```python
# auth.py
def get_current_user(
    credentials: Annotated[HTTPAuthorizationCredentials, Depends(security)],
    db: Annotated[Session, Depends(get_db)],
) -> User:
    token = credentials.credentials

    # Dev token shortcut - only in dev environment, only for dev-created users
    if token.startswith("dev_token_user_") and settings.is_dev:
        try:
            user_id = int(token.replace("dev_token_user_", ""))
            user = db.exec(select(User).where(User.id == user_id)).first()
            # Only allow for dev-created users (apple_user_id starts with "dev_")
            if user and user.apple_user_id and user.apple_user_id.startswith("dev_"):
                return user
            # Don't auto-create users anymore - must use dev-login first
        except (ValueError, TypeError):
            pass
        # Fall through to normal JWT validation (will fail, but gives consistent error)

    # Normal JWT validation (unchanged)
    ...
```

Note: We remove auto-creation of users via dev tokens. Users must be created via `/auth/dev-login` first, which sets the `dev_` prefix on `apple_user_id`.

## Files to change

- `server/app/config.py` - Add `is_dev` property, add pydantic validator
- `server/app/auth.py` - Add environment and user-type checks to dev token path, remove auto-creation
- `server/app/main.py` - Gate dev-login behind `is_dev` check
- `server/tests/test_auth.py` - Add tests for environment gating
- `server/tests/test_dev_auth.py` (new) - Tests specifically for dev auth behavior

## Tests

New test cases:

```python
# test_dev_auth.py - new file

def test_dev_login_works_in_dev_environment(client):
    """Dev login endpoint available in dev environment"""
    response = client.post("/auth/dev-login?email=test@example.com")
    assert response.status_code == 200
    assert "access_token" in response.json()

def test_dev_login_returns_404_in_staging(client, monkeypatch):
    """Dev login endpoint hidden in staging"""
    monkeypatch.setenv("ENVIRONMENT", "staging")
    # Need to reimport settings or mock it
    with patch("app.main.settings.is_dev", False):
        response = client.post("/auth/dev-login?email=test@example.com")
        assert response.status_code == 404

def test_dev_token_rejected_for_apple_signin_users(client, apple_token):
    """Dev tokens cannot impersonate Apple Sign-In users"""
    # Create a real Apple user
    id_token = apple_token(user_id="real_apple_user", email="real@example.com")
    response = client.post("/auth/apple", json={"id_token": id_token})
    user_id = response.json()["user"]["id"]

    # Try to use dev token for this user - should fail
    response = client.get(
        "/auth/me",
        headers={"Authorization": f"Bearer dev_token_user_{user_id}"}
    )
    assert response.status_code == 401

def test_dev_token_works_for_dev_login_users(client):
    """Dev tokens work for users created via dev-login"""
    # Create user via dev-login
    response = client.post("/auth/dev-login?email=devuser@example.com")
    assert response.status_code == 200
    user_id = response.json()["user"]["id"]

    # Dev token should work for this user
    response = client.get(
        "/auth/me",
        headers={"Authorization": f"Bearer dev_token_user_{user_id}"}
    )
    assert response.status_code == 200
    assert response.json()["email"] == "devuser@example.com"

def test_config_rejects_default_secrets_in_prod():
    """Server refuses to start with default secrets in production"""
    import os
    from unittest.mock import patch

    with patch.dict(os.environ, {"ENVIRONMENT": "prod"}, clear=False):
        with pytest.raises(ValueError, match="JWT_SECRET_KEY must be set"):
            from importlib import reload
            import app.config
            reload(app.config)
```

## Done when

```bash
# 1. Dev-login works in dev (default)
curl -X POST "localhost:8000/auth/dev-login?email=test@example.com"
# Expected: 200 with access_token

# 2. Server fails to start in staging with dev defaults
ENVIRONMENT=staging uv run python -c "from app.config import settings"
# Expected: ValueError about JWT_SECRET_KEY

# 3. Server starts in staging with proper secrets
ENVIRONMENT=staging DATABASE_URL=postgresql://x:y@z/db JWT_SECRET_KEY=secure123 \
  uv run python -c "from app.config import settings; print('ok')"
# Expected: ok

# 4. All tests pass
python dev.py test --server
```

## Risks

- **Test isolation**: Tests currently rely on `ENVIRONMENT=dev` implicitly. Since the test environment doesn't set `ENVIRONMENT`, it defaults to `dev`, which is correct. No changes needed.
- **Existing dev workflows**: Anyone using `dev_token_user_X` for Apple Sign-In users will need to switch to dev-login. The error message should make this clear.

## Migration

No database migration needed. This is purely runtime behavior changes.

For developers using dev tokens with real users:
1. Use `/auth/dev-login?email=xxx` to create a dev user
2. Use the returned `access_token` directly, OR
3. Use `dev_token_user_{id}` where `{id}` is the user ID from step 1
