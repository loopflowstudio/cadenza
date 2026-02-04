from app.rate_limit import limiter


def test_cors_allows_any_origin_in_dev(client):
    response = client.options(
        "/health",
        headers={
            "Origin": "https://evil.com",
            "Access-Control-Request-Method": "GET",
        },
    )
    assert response.headers.get("access-control-allow-origin") == "https://evil.com"


def test_rate_limit_returns_429_after_threshold(client, apple_token):
    original_key_func = limiter._key_func
    previous_enabled = limiter.enabled

    def _test_key_func(_request):
        return "rate-limit-test"

    limiter._key_func = _test_key_func
    limiter.enabled = True
    try:
        for _ in range(10):
            response = client.post(
                "/auth/apple",
                json={"id_token": apple_token(user_id="limit", email="limit@test")},
            )
            assert response.status_code == 200

        response = client.post(
            "/auth/apple",
            json={"id_token": apple_token(user_id="limit2", email="limit2@test")},
        )
        assert response.status_code == 429
    finally:
        limiter._key_func = original_key_func
        limiter.enabled = previous_enabled
