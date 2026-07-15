"""Security-boundary regression tests.

These tests exercise the public HTTP boundary rather than helper functions so
they fail if authentication, authorization, throttling, or CORS are removed.
"""

from app import _hash_password
from conftest import FakeCursor


def test_business_endpoint_rejects_missing_token(anonymous_client, fake_db):
    fake_db(FakeCursor(fetchall=[[]]))

    response = anonymous_client.get("/users")

    assert response.status_code == 401


def test_login_returns_access_token(client, fake_db):
    user = {
        "id": 7,
        "email": "manager@presales.ma",
        "password": "secret",
        "prenom": "Sara",
        "nom": "Manager",
        "role": "manager",
        "is_active": True,
    }
    fake_db(FakeCursor(fetchone=[user]))

    response = client.post(
        "/login",
        json={"email": "manager@presales.ma", "password": "secret"},
    )

    assert response.status_code == 200
    assert response.get_json()["access_token"]


def test_login_is_rate_limited(client, fake_db):
    fake_db(FakeCursor(fetchone=[None, None, None, None, None, None]))

    responses = [
        client.post(
            "/login",
            json={"email": "attacker@example.invalid", "password": "wrong"},
        )
        for _ in range(6)
    ]

    assert [response.status_code for response in responses[:5]] == [401] * 5
    assert responses[5].status_code == 429


def test_untrusted_origin_is_not_allowed(client):
    response = client.get("/", headers={"Origin": "https://evil.example"})

    assert "Access-Control-Allow-Origin" not in response.headers


def test_invalid_token_is_rejected(anonymous_client):
    response = anonymous_client.get(
        "/users",
        headers={"Authorization": "Bearer not-a-valid-jwt"},
    )

    assert response.status_code == 401


def test_commercial_cannot_create_users(client, fake_db, auth_headers):
    fake_db(FakeCursor())

    response = client.post(
        "/users",
        json={"email": "new@presales.ma", "name": "New User"},
        headers=auth_headers("commercial", user_id=3),
    )

    assert response.status_code == 403


def test_manager_can_access_manager_orders(client, fake_db, auth_headers):
    fake_db(
        FakeCursor(
            columns={"factures": ["id", "manager_id", "date_facture"]},
            fetchall=[[]],
        )
    )

    response = client.get(
        "/manager/commandes?manager_id=999",
        headers=auth_headers("manager", user_id=7),
    )

    assert response.status_code == 200


def test_commercial_order_filter_cannot_be_spoofed(client, fake_db, auth_headers):
    conn = fake_db(
        FakeCursor(
            columns={
                "factures": [
                    "id",
                    "client_id",
                    "commercial_id",
                    "date_facture",
                    "status",
                ]
            },
            fetchall=[[]],
        )
    )

    response = client.get(
        "/commandes?commercial_id=999&commercial_email=other@example.com",
        headers=auth_headers(
            "commercial",
            user_id=3,
            email="commercial@presales.ma",
        ),
    )

    assert response.status_code == 200
    query_params = [
        value
        for _, params in conn._cursor.executed
        if params
        for value in (params if isinstance(params, (list, tuple)) else [params])
    ]
    assert 999 not in query_params
    assert "999" not in query_params
    assert "other@example.com" not in query_params
    assert 3 in query_params
    assert "commercial@presales.ma" in query_params


def test_user_can_change_own_password(client, fake_db, auth_headers):
    conn = fake_db(
        FakeCursor(
            fetchone=[{"id": 3, "password": _hash_password("current-pass")}]
        )
    )

    response = client.post(
        "/users/3/change-password",
        json={
            "current_password": "current-pass",
            "new_password": "new-secure-pass",
        },
        headers=auth_headers("commercial", user_id=3),
    )

    assert response.status_code == 200
    assert "UPDATE users SET password" in conn._cursor.sql


def test_user_cannot_change_another_password(client, fake_db, auth_headers):
    fake_db(FakeCursor())

    response = client.post(
        "/users/4/change-password",
        json={
            "current_password": "current-pass",
            "new_password": "new-secure-pass",
        },
        headers=auth_headers("commercial", user_id=3),
    )

    assert response.status_code == 403
