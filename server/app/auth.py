from datetime import datetime, timedelta, timezone
from typing import Annotated
import jwt
from jwt.exceptions import InvalidTokenError
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlmodel import Session, select

from app.config import settings
from app.database import get_db
from app.models import User

security = HTTPBearer()


def create_access_token(data: dict) -> str:
    to_encode = data.copy()
    # Ensure sub is a string as required by JWT spec
    if "sub" in to_encode and not isinstance(to_encode["sub"], str):
        to_encode["sub"] = str(to_encode["sub"])
    expire = datetime.now(timezone.utc) + timedelta(hours=settings.jwt_expiration_hours)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(
        to_encode, settings.jwt_secret_key, algorithm=settings.jwt_algorithm
    )
    return encoded_jwt


def decode_apple_identity_token(id_token: str) -> dict:
    """
    In production, this should validate the Apple ID token by:
    1. Fetching Apple's public keys from https://appleid.apple.com/auth/keys
    2. Verifying the token signature
    3. Validating claims (iss, aud, exp, etc.)

    For now, we'll decode without verification for development.
    """
    try:
        payload = jwt.decode(id_token, options={"verify_signature": False})
        return payload
    except InvalidTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid Apple ID token"
        )


def get_current_user(
    credentials: Annotated[HTTPAuthorizationCredentials, Depends(security)],
    db: Annotated[Session, Depends(get_db)],
) -> User:
    token = credentials.credentials

    # Development mode: accept dev_token_user_X format
    if token.startswith("dev_token_user_"):
        try:
            user_id = int(token.replace("dev_token_user_", ""))
            user = db.exec(select(User).where(User.id == user_id)).first()
            if user:
                return user
            # Auto-create dev users if they don't exist
            user = User(
                apple_user_id=f"mock_{user_id}",
                email=f"user{user_id}@example.com",
                full_name=f"Dev User {user_id}",
                user_type=None,
            )
            db.add(user)
            db.commit()
            db.refresh(user)
            return user
        except (ValueError, TypeError):
            pass  # Fall through to normal JWT validation

    try:
        payload = jwt.decode(
            token, settings.jwt_secret_key, algorithms=[settings.jwt_algorithm]
        )
        user_id = payload.get("sub")
        if user_id is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid authentication credentials",
            )
        # Ensure user_id is an integer
        user_id = int(user_id)
    except (InvalidTokenError, ValueError, TypeError) as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid authentication credentials: {str(e)}",
        )

    user = db.exec(select(User).where(User.id == user_id)).first()
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"User not found for id {user_id}",
        )
    return user
