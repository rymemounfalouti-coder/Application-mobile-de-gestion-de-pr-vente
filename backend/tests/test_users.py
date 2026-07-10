"""Tests for /users and /users/<id> routes."""

from conftest import FakeCursor

USER_COLS = {
    "users": ["id", "nom", "prenom", "name", "email", "role", "updated_at"]
}


class TestCreate:
    def test_missing_email_returns_400(self, client, fake_db):
        fake_db(FakeCursor())
        resp = client.post("/users", json={"name": "No Email"})
        assert resp.status_code == 400

    def test_duplicate_email_returns_409(self, client, fake_db):
        fake_db(FakeCursor(fetchone=[{"id": 1}]))
        resp = client.post(
            "/users", json={"email": "taken@x.com", "name": "Dupe"}
        )
        assert resp.status_code == 409


class TestPatch:
    def test_patch_missing_returns_404(self, client, fake_db):
        # role "manager" so _commercial_business_status short-circuits (no more DB)
        fake_db(FakeCursor(columns=USER_COLS, fetchone=[None]))
        resp = client.patch(
            "/users/999", json={"name": "Ghost User", "role": "manager"}
        )
        assert resp.status_code == 404


class TestDelete:
    def test_delete_missing_returns_404(self, client, fake_db):
        fake_db(FakeCursor(fetchone=[None]))
        resp = client.delete("/users/999")
        assert resp.status_code == 404

    def test_delete_existing_returns_row(self, client, fake_db):
        fake_db(FakeCursor(fetchone=[{"id": 4, "email": "a@b.com"}]))
        resp = client.delete("/users/4")
        assert resp.status_code == 200
        assert resp.get_json()["id"] == 4
