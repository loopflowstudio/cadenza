import pytest
from fastapi.testclient import TestClient
from sqlmodel import create_engine, Session, SQLModel
import jwt
from unittest.mock import patch, MagicMock

from app.main import app
from app.database import get_db
from app.apple_auth import InvalidTokenError
from app.rate_limit import limiter

SQLALCHEMY_DATABASE_URL = "sqlite:///./test.db"
engine = create_engine(
    SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False}
)


def override_get_db():
    with Session(engine) as session:
        yield session


app.dependency_overrides[get_db] = override_get_db


@pytest.fixture
def client():
    SQLModel.metadata.create_all(engine)
    yield TestClient(app)
    SQLModel.metadata.drop_all(engine)


@pytest.fixture
def apple_token():
    """Factory for creating test Apple ID tokens"""

    def _create_token(
        user_id: str = "test_user_123", email: str = "test@example.com"
    ) -> str:
        payload = {
            "sub": user_id,
            "email": email,
            "iss": "https://appleid.apple.com",
            "aud": "studio.loopflow.Cadenza",
            "exp": 9999999999,
        }
        return jwt.encode(payload, "fake_key", algorithm="HS256")

    return _create_token


@pytest.fixture
def authenticated_client(client, apple_token):
    """Factory for getting an authenticated client with a valid JWT"""

    def _authenticate(
        user_id: str = "test_user_123", email: str = "test@example.com"
    ) -> tuple[TestClient, dict]:
        id_token = apple_token(user_id, email)
        response = client.post("/auth/apple", json={"id_token": id_token})
        auth_data = response.json()
        return client, auth_data

    return _authenticate


@pytest.fixture(autouse=True)
def mock_s3():
    """Mock S3 operations for all tests"""
    with patch("app.s3.get_s3_client") as mock_get_client:
        # Create a mock S3 client
        mock_client = MagicMock()
        mock_get_client.return_value = mock_client

        # Mock put_object to succeed silently
        mock_client.put_object.return_value = {}

        # Mock copy_object to succeed silently
        mock_client.copy_object.return_value = {}

        # Mock delete_object to succeed silently
        mock_client.delete_object.return_value = {}

        # Mock presigned URL generation to return a usable string
        mock_client.generate_presigned_url.return_value = "https://example.com/presigned"

        yield mock_client


@pytest.fixture(autouse=True)
def mock_apple_verification():
    """Mock Apple token verification for tests."""

    def _verify(id_token: str, _client_id: str) -> dict:
        if id_token == "invalid_token":
            raise InvalidTokenError("Invalid token")
        return jwt.decode(
            id_token,
            options={
                "verify_signature": False,
                "verify_aud": False,
                "verify_iss": False,
            },
        )

    with patch("app.apple_auth.verify_apple_id_token", side_effect=_verify):
        yield


@pytest.fixture(autouse=True)
def disable_rate_limiting():
    previous = limiter.enabled
    limiter.enabled = False
    try:
        yield
    finally:
        limiter.enabled = previous
