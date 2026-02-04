# Questions

## Open questions

### COPPA compliance timeline

The app serves students who may be under 13. COPPA requires parental consent for collecting data from children. This is out of scope for this wave but needs a dedicated wave before public launch.

### Production infrastructure

The security hardening assumes:
- HTTPS termination at load balancer (not in FastAPI)
- Managed PostgreSQL with encryption at rest
- S3 with default encryption enabled

These are infrastructure decisions outside this codebase. Need confirmation this is the deployment model.

### Apple Client ID

Apple token verification requires `APPLE_CLIENT_ID` to match the Apple bundle ID. Confirm the production value.

### Dev-login endpoint scope

Security hardening notes conflict: one earlier doc suggested removing `/auth/dev-login`, while the current implementation keeps it but gates to dev only (404 in non-dev). Confirm this is the intended long-term behavior.
