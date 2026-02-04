import os
from importlib import reload
from unittest.mock import patch

import pytest


def test_dev_login_works_in_dev_environment(client):
    response = client.post("/auth/dev-login?email=test@example.com")
    assert response.status_code == 200
    assert "access_token" in response.json()


def test_dev_login_returns_404_in_staging(client):
    with patch("app.main.settings.environment", "staging"):
        response = client.post("/auth/dev-login?email=test@example.com")
        assert response.status_code == 404


def test_dev_token_rejected_for_apple_signin_users(client, apple_token):
    id_token = apple_token(user_id="real_apple_user", email="real@example.com")
    response = client.post("/auth/apple", json={"id_token": id_token})
    user_id = response.json()["user"]["id"]

    response = client.get(
        "/auth/me",
        headers={"Authorization": f"Bearer dev_token_user_{user_id}"},
    )
    assert response.status_code == 401


def test_dev_token_works_for_dev_login_users(client):
    response = client.post("/auth/dev-login?email=devuser@example.com")
    user_id = response.json()["user"]["id"]

    response = client.get(
        "/auth/me",
        headers={"Authorization": f"Bearer dev_token_user_{user_id}"},
    )
    assert response.status_code == 200
    assert response.json()["email"] == "devuser@example.com"


def test_config_rejects_default_secrets_in_prod():
    with patch.dict(
        os.environ,
        {
            "ENVIRONMENT": "prod",
            "DATABASE_URL": "postgresql://user:pass@host:5432/dbname",
        },
        clear=False,
    ):
        with pytest.raises(ValueError, match="JWT_SECRET_KEY must be set"):
            import app.config

            reload(app.config)
