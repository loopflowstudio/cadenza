# Secure Development Authentication

Make dev authentication features safe for all environments.

## Problem

The server has dev conveniences that need guardrails:

1. **Dev token pattern** (`auth.py:49-68`): `dev_token_user_X` grants access without JWT - useful for testing but currently works in production and can impersonate any user
2. **Dev-login endpoint** (`main.py:33-68`): Creates/logs in users by email alone - useful for local dev but dangerous in production
3. **Hardcoded secrets** (`config.py`): Default JWT secret and database URL work if environment variables aren't set

## Solution

### 1. Gate dev features behind environment check

```python
# config.py
class Settings(BaseSettings):
    environment: str = "dev"  # "dev", "staging", "prod"

    @property
    def is_dev(self) -> bool:
        return self.environment == "dev"
```

```python
# main.py
@app.post("/auth/dev-login")
def dev_login(...):
    if not settings.is_dev:
        raise HTTPException(status_code=404, detail="Not found")
    # ... existing logic
```

### 2. Restrict dev tokens to dev-created users only

Keep the dev token feature but make it safe:
- Only works when `ENVIRONMENT=dev`
- Only works for users created via dev-login (apple_user_id starts with `dev_`)

```python
# auth.py
def get_current_user(token: str, db: Session) -> User:
    # Dev token shortcut - only in dev environment, only for dev users
    if token.startswith("dev_token_user_") and settings.is_dev:
        try:
            user_id = int(token.replace("dev_token_user_", ""))
            user = db.exec(select(User).where(User.id == user_id)).first()
            # Only allow for dev-created users, not real Apple Sign-In users
            if user and user.apple_user_id.startswith("dev_"):
                return user
        except (ValueError, AttributeError):
            pass
        # Fall through to normal JWT validation

    # Normal JWT validation
    # ...
```

This way:
- **Production**: Dev tokens rejected (environment check fails)
- **Staging**: Dev tokens rejected (environment check fails)
- **Dev + real user**: Dev tokens rejected (apple_user_id check fails)
- **Dev + dev user**: Dev tokens work ✓

### 3. Require secrets in non-dev environments

```python
# config.py
class Settings(BaseSettings):
    environment: str = "dev"

    # No defaults - must be set
    database_url: str | None = None
    jwt_secret_key: str | None = None

    @model_validator(mode="after")
    def validate_production_settings(self) -> "Settings":
        if self.environment != "dev":
            if not self.database_url:
                raise ValueError("DATABASE_URL required in non-dev environments")
            if not self.jwt_secret_key:
                raise ValueError("JWT_SECRET_KEY required in non-dev environments")
            if self.jwt_secret_key == "dev_secret_key_change_in_production":
                raise ValueError("JWT_SECRET_KEY must be changed from default")
        return self

    # Dev defaults (only used when environment=dev)
    @property
    def effective_database_url(self) -> str:
        return self.database_url or "postgresql://cadenza:cadenza_dev@localhost:5432/cadenza"

    @property
    def effective_jwt_secret(self) -> str:
        return self.jwt_secret_key or "dev_secret_key_change_in_production"
```

## Files to Change

- `server/app/config.py` - Add is_dev property, add validation for prod secrets
- `server/app/auth.py` - Add environment and user-type checks to dev token path
- `server/app/main.py` - Gate dev-login behind is_dev check
- `server/app/database.py` - Use settings.effective_database_url

## Tests

- [ ] Dev-login works when ENVIRONMENT=dev
- [ ] Dev-login returns 404 when ENVIRONMENT=staging
- [ ] Dev-login returns 404 when ENVIRONMENT=prod
- [ ] Server fails to start if ENVIRONMENT=prod and DATABASE_URL not set
- [ ] Server fails to start if ENVIRONMENT=prod and JWT_SECRET_KEY not set
- [ ] Server fails to start if JWT_SECRET_KEY is the default in prod
- [ ] dev_token_user_X works for dev-created users when ENVIRONMENT=dev
- [ ] dev_token_user_X rejected for real Apple users even in dev
- [ ] dev_token_user_X rejected in staging/prod environments

## Risks

- Minimal - dev workflows preserved, just adding safety checks

## Definition of Done

- [ ] Dev tokens only work in dev environment for dev-created users
- [ ] Dev-login only available in dev environment
- [ ] Server refuses to start in staging/prod without proper secrets
- [ ] All tests pass
- [ ] Dev workflow unchanged locally
