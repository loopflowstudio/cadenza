# Apple Sign-In Token Verification

Implement proper cryptographic verification of Apple identity tokens.

## Problem

Current implementation decodes Apple tokens without verifying the signature:

```python
# auth.py:25-41
payload = jwt.decode(id_token, options={"verify_signature": False})
```

This means anyone can craft a fake JWT with any `sub` (Apple user ID) and email, and the server will accept it as valid. Complete authentication bypass.

## Background

Apple Sign-In flow:
1. iOS app authenticates user with Apple
2. Apple returns an `identityToken` (JWT signed by Apple)
3. App sends token to our server
4. Server must verify:
   - Token signature (using Apple's public keys)
   - `iss` claim is `https://appleid.apple.com`
   - `aud` claim matches our app's bundle ID
   - Token is not expired (`exp` claim)

Apple publishes public keys at: `https://appleid.apple.com/auth/keys`

## Solution

### 1. Fetch and cache Apple's public keys

```python
# auth.py
import httpx
from functools import lru_cache
from datetime import datetime, timedelta

APPLE_KEYS_URL = "https://appleid.apple.com/auth/keys"
APPLE_ISSUER = "https://appleid.apple.com"

# Cache keys for 24 hours
_apple_keys_cache: dict | None = None
_apple_keys_fetched_at: datetime | None = None

def get_apple_public_keys() -> dict:
    global _apple_keys_cache, _apple_keys_fetched_at

    now = datetime.utcnow()
    if _apple_keys_cache and _apple_keys_fetched_at:
        if now - _apple_keys_fetched_at < timedelta(hours=24):
            return _apple_keys_cache

    response = httpx.get(APPLE_KEYS_URL, timeout=10)
    response.raise_for_status()
    _apple_keys_cache = response.json()
    _apple_keys_fetched_at = now
    return _apple_keys_cache
```

### 2. Verify token signature

```python
# auth.py
from jwt import PyJWKClient, decode, InvalidTokenError

def decode_apple_identity_token(id_token: str, bundle_id: str) -> dict:
    """
    Decode and verify an Apple identity token.

    Args:
        id_token: The JWT from Apple Sign-In
        bundle_id: Our app's bundle ID (audience claim)

    Returns:
        Decoded token payload

    Raises:
        InvalidTokenError: If token is invalid or verification fails
    """
    # Get the key ID from token header
    unverified_header = jwt.get_unverified_header(id_token)
    kid = unverified_header.get("kid")

    if not kid:
        raise InvalidTokenError("Token missing key ID")

    # Fetch Apple's public keys
    apple_keys = get_apple_public_keys()

    # Find the matching key
    public_key = None
    for key in apple_keys.get("keys", []):
        if key.get("kid") == kid:
            public_key = jwt.algorithms.RSAAlgorithm.from_jwk(key)
            break

    if not public_key:
        raise InvalidTokenError(f"No matching Apple public key for kid: {kid}")

    # Verify and decode
    payload = jwt.decode(
        id_token,
        public_key,
        algorithms=["RS256"],
        audience=bundle_id,
        issuer=APPLE_ISSUER,
    )

    return payload
```

### 3. Add bundle ID to config

```python
# config.py
class Settings(BaseSettings):
    apple_bundle_id: str = "com.loopflow.cadenza"
```

### 4. Update auth endpoint

```python
# main.py
@app.post("/auth/apple")
def apple_auth(request: AppleAuthRequest, db: Session = Depends(get_db)):
    try:
        payload = decode_apple_identity_token(
            request.identity_token,
            settings.apple_bundle_id
        )
    except InvalidTokenError as e:
        raise HTTPException(status_code=401, detail="Invalid Apple token")

    apple_user_id = payload.get("sub")
    email = payload.get("email")
    # ... rest of auth logic
```

## Files to Change

- `server/app/config.py` - Add apple_bundle_id setting
- `server/app/auth.py` - Implement proper token verification
- `server/app/main.py` - Update apple_auth endpoint error handling

## Tests

Testing Apple Sign-In is tricky because we can't generate valid Apple-signed tokens. Options:

1. **Mock the verification in tests**:
```python
@pytest.fixture
def mock_apple_auth(monkeypatch):
    def fake_decode(token, bundle_id):
        if token == "valid_test_token":
            return {"sub": "test_apple_id", "email": "test@example.com"}
        raise InvalidTokenError("Invalid token")
    monkeypatch.setattr(auth, "decode_apple_identity_token", fake_decode)
```

2. **Integration test with real Apple token** (manual, not CI):
   - Sign in on iOS simulator
   - Capture the token
   - Test against staging server

Test cases:
- [ ] Valid token returns user data
- [ ] Expired token rejected
- [ ] Wrong audience rejected
- [ ] Wrong issuer rejected
- [ ] Tampered signature rejected
- [ ] Missing claims rejected
- [ ] Apple key fetch failure handled gracefully (use cached keys)

## Edge Cases

1. **Apple rotates keys**: We cache for 24 hours. If Apple rotates within that window, some tokens might fail. Solution: On verification failure, try refetching keys once.

2. **Apple API down**: If we can't fetch keys, fall back to cached keys. If no cache, return 503.

3. **Token replay**: Apple tokens have ~10 minute expiry. We don't need additional replay protection since we issue our own JWT after verification.

## Security Considerations

- Never log the full token (contains user email)
- Use constant-time comparison for any string checks
- Set reasonable timeout on Apple API requests
- Don't expose internal errors to clients

## Definition of Done

- [ ] Apple tokens cryptographically verified
- [ ] Invalid tokens rejected with 401
- [ ] Apple key caching works
- [ ] Tests cover happy path and error cases
- [ ] No regression in iOS app authentication flow
