"""
Auth endpoint behavior tests.

These tests verify the authentication contract:
- Users can authenticate with Apple
- Sessions persist across requests
- Protected endpoints require valid authentication
"""

def test_api_is_reachable(client):
    """API root endpoint responds"""
    response = client.get("/")
    assert response.status_code == 200

def test_new_user_can_sign_in_with_apple(client, apple_token):
    """New users can authenticate with valid Apple ID token"""
    id_token = apple_token(user_id="new_user", email="new@example.com")

    response = client.post("/auth/apple", json={"id_token": id_token})

    assert response.status_code == 200
    body = response.json()
    assert "access_token" in body, "Should return access token"
    assert "user" in body, "Should return user info"
    assert body["user"]["email"] == "new@example.com"

def test_returning_user_gets_same_identity(client, apple_token):
    """Same Apple user ID returns same user account on subsequent logins"""
    id_token = apple_token(user_id="same_user", email="user@example.com")

    first_login = client.post("/auth/apple", json={"id_token": id_token})
    second_login = client.post("/auth/apple", json={"id_token": id_token})

    first_user = first_login.json()["user"]
    second_user = second_login.json()["user"]

    assert first_user["email"] == second_user["email"]
    assert "id" in first_user and first_user["id"] == second_user["id"], \
        "Same Apple user should get same account"

def test_access_token_grants_access_to_protected_endpoints(authenticated_client):
    """Valid access token allows access to user info"""
    client, auth_data = authenticated_client(email="protected@example.com")
    access_token = auth_data["access_token"]

    response = client.get("/auth/me", headers={"Authorization": f"Bearer {access_token}"})

    assert response.status_code == 200
    user = response.json()
    assert user["email"] == "protected@example.com"

def test_invalid_token_is_rejected(client):
    """Protected endpoints reject invalid tokens"""
    response = client.get("/auth/me", headers={"Authorization": "Bearer invalid_token"})
    assert response.status_code == 401

def test_missing_token_is_rejected(client):
    """Protected endpoints reject requests without tokens"""
    response = client.get("/auth/me")
    assert response.status_code == 401
