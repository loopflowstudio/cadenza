# Security Hardening Review

## What was implemented
- Added Apple ID token verification using Apple JWKS, with caching and refresh on unknown key IDs.
- Hardened auth: dev tokens only work in dev for dev-created users, and auth errors are sanitized.
- Added environment validation for secrets and added environment-driven CORS + rate limiting.
- Added security middleware for HTTPS redirects (non-dev) and security headers.
- Added tests for dev auth gating, CORS, and rate limiting, plus updated auth flow tests.

## Key choices
- Cached Apple JWKS with a refresh-on-miss path to handle key rotation without constant network calls.
- Dev conveniences are gated by `ENVIRONMENT=dev` and user type, instead of removal, to preserve local workflows.
- CORS allow-all is only for dev; non-dev requires explicit origins.
- Rate limiting is implemented at the app layer using slowapi for portability and testability.

## How it fits together
- `apple_auth.verify_apple_id_token` handles signature verification and key caching; `main.py` calls it during Apple login.
- `config.Settings` centralizes environment checks, rate limits, and CORS origin parsing.
- `main.py` applies middleware (HTTPS redirect + security headers), CORS, and rate limiting decorators.

## Risks and bottlenecks
- If Apple JWKS fetch fails and there is no cache, Apple login returns 503.
- Rate limiting relies on in-process storage; multi-instance deployments should confirm shared storage.
- HTTPS redirect relies on correct `x-forwarded-proto` headers from the load balancer.

## What's not included
- COPPA compliance, audit logging, and infrastructure enforcement (DB/S3 encryption).
- Broader auth hardening beyond Apple Sign In (e.g., account recovery, device attestation).
- CORS and rate limit configuration for per-route overrides outside the endpoints already covered.
