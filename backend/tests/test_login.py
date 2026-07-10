"""Tests for POST /login."""

from conftest import FakeCursor


def test_unknown_user_returns_401(client, fake_db):
    fake_db(FakeCursor(fetchone=[None]))
    resp = client.post("/login", json={"email": "ghost@x.com", "password": "pw"})
    assert resp.status_code == 401
    assert "incorrect" in resp.get_json()["message"].lower()


def test_wrong_password_returns_401(client, fake_db):
    user = {"id": 1, "email": "a@b.com", "password": "secret", "is_active": True}
    fake_db(FakeCursor(fetchone=[user]))
    resp = client.post("/login", json={"email": "a@b.com", "password": "WRONG"})
    assert resp.status_code == 401


def test_success_returns_user_without_password(client, fake_db):
    user = {
        "id": 7,
        "email": "a@b.com",
        "password": "secret",
        "prenom": "Ahmed",
        "nom": "Benali",
        "is_active": True,
    }
    conn = fake_db(FakeCursor(fetchone=[user]))
    resp = client.post("/login", json={"email": "a@b.com", "password": "secret"})
    assert resp.status_code == 200
    body = resp.get_json()
    assert body["name"] == "Ahmed Benali"
    assert body["password"] is None
    # a plaintext password is upgraded to a hash on successful login
    assert conn.committed >= 1
    assert "UPDATE users SET password" in conn._cursor.sql
