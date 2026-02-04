from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import RedirectResponse, Response

from app.config import settings


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next) -> Response:
        response = await call_next(request)
        response.headers["Strict-Transport-Security"] = (
            "max-age=31536000; includeSubDomains"
        )
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["X-XSS-Protection"] = "1; mode=block"
        return response


class HttpsRedirectMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next) -> Response:
        if settings.is_dev:
            return await call_next(request)

        forwarded_proto = request.headers.get("x-forwarded-proto", "")
        if request.url.scheme != "https" and forwarded_proto != "https":
            https_url = request.url.replace(scheme="https")
            return RedirectResponse(url=str(https_url), status_code=307)

        return await call_next(request)
