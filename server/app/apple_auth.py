from __future__ import annotations

import json
from typing import Any

import httpx
import jwt
from cachetools import TTLCache
from jwt import InvalidTokenError

APPLE_JWKS_URL = "https://appleid.apple.com/auth/keys"
APPLE_ISSUER = "https://appleid.apple.com"

_jwks_cache: TTLCache[str, list[dict[str, Any]]] = TTLCache(maxsize=1, ttl=3600)


def _fetch_apple_public_keys() -> list[dict[str, Any]]:
    response = httpx.get(APPLE_JWKS_URL, timeout=10)
    response.raise_for_status()
    payload = response.json()
    return payload.get("keys", [])


def get_apple_public_keys(*, force_refresh: bool = False) -> list[dict[str, Any]]:
    if not force_refresh and "keys" in _jwks_cache:
        return _jwks_cache["keys"]

    try:
        keys = _fetch_apple_public_keys()
        _jwks_cache["keys"] = keys
        return keys
    except httpx.HTTPError:
        if "keys" in _jwks_cache:
            return _jwks_cache["keys"]
        raise


def _public_key_for_kid(keys: list[dict[str, Any]], kid: str | None) -> Any | None:
    if not kid:
        return None
    for key in keys:
        if key.get("kid") == kid:
            return jwt.algorithms.RSAAlgorithm.from_jwk(json.dumps(key))
    return None


def verify_apple_id_token(id_token: str, client_id: str) -> dict[str, Any]:
    header = jwt.get_unverified_header(id_token)
    kid = header.get("kid")

    keys = get_apple_public_keys()
    public_key = _public_key_for_kid(keys, kid)
    if public_key is None:
        keys = get_apple_public_keys(force_refresh=True)
        public_key = _public_key_for_kid(keys, kid)
    if public_key is None:
        raise InvalidTokenError("Unknown Apple key ID")

    return jwt.decode(
        id_token,
        public_key,
        algorithms=["RS256"],
        audience=client_id,
        issuer=APPLE_ISSUER,
    )
