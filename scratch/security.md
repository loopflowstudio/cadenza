# Security Hardening (Current State)

## Goal
Protect Cadenza's student/teacher data by removing dev backdoors, verifying Apple Sign-In, and adding basic API hardening (CORS, rate limits, HTTPS, headers).

## What’s implemented
- Apple ID token verification via Apple JWKS with caching and refresh-on-miss.
- Dev auth gating: dev tokens only in `ENVIRONMENT=dev` and only for dev-created users.
- `/auth/dev-login` available only in dev; returns 404 in non-dev.
- Secrets validation in non-dev: reject default `DATABASE_URL` and `JWT_SECRET_KEY`.
- CORS allow-all in dev; allowlist in non-dev.
- Rate limiting with SlowAPI (auth/write/read tiers).
- HTTPS redirect (non-dev) and security headers middleware.
- Auth errors sanitized to avoid enumeration.

## Key decisions
- Preserve dev workflows in dev only; hide dev endpoints in non-dev (404).
- Fail fast on missing or default secrets in non-dev environments.
- Use app-layer rate limits for portability; note multi-instance storage risk.
- Use Apple Sign-In as the sole auth mechanism (no password auth).

## How it fits together
- `apple_auth.verify_apple_id_token` performs JWT verification and key caching.
- `config.Settings` centralizes env checks, CORS, and rate limits.
- `main.py` wires middleware, CORS, rate limiting, and auth endpoints.

## Risks / follow-ups
- Apple JWKS fetch failure without cache returns 503.
- SlowAPI uses in-process storage; confirm shared storage before multi-instance deployments.
- HTTPS redirect depends on correct `x-forwarded-proto` headers at the load balancer.

## Out of scope
- COPPA compliance, audit logging, infrastructure enforcement (DB/S3 encryption).
- Broader auth features (account recovery, device attestation).
- Per-route CORS/rate limit overrides beyond current defaults.

## Verification checklist
- Dev login works in dev; returns 404 in non-dev.
- `ENVIRONMENT=staging` rejects default DB URL / JWT secret.
- Apple auth rejects invalid tokens and returns 401.
- CORS restricts unknown origins in non-dev.
- Rate limit returns 429 after threshold exceeded.
- Security headers present on responses.
