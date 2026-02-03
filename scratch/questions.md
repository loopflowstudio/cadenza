# Questions

## ~~Wave backlog missing~~ (Resolved)

The `roadmap/` directory does not exist. Proceeding with security hardening based on codebase analysis. The branch name "security" indicates the intent; the design in `scratch/security.md` defines scope.

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

The design requires `APPLE_CLIENT_ID` env var for token verification. This should match the bundle ID registered with Apple. Need to confirm the production value.
