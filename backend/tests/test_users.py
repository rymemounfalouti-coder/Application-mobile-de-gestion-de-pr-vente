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


class TestPreferences:
    def test_user_can_update_own_preferences(self, client, fake_db, auth_headers):
        conn = fake_db(
            FakeCursor(
                fetchone=[
                    {
                        "user_id": 3,
                        "preferences": {"language": "fr"},
                    }
                ]
            )
        )

        resp = client.patch(
            "/users/3/preferences",
            json={"language": "fr"},
            headers=auth_headers("commercial", user_id=3),
        )

        assert resp.status_code == 200
        assert resp.get_json()["preferences"]["language"] == "fr"
        assert "CREATE TABLE IF NOT EXISTS user_preferences" in conn._cursor.sql
        assert conn.committed == 1

    def test_user_cannot_update_another_users_preferences(
        self, client, fake_db, auth_headers
    ):
        fake_db(FakeCursor())

        resp = client.patch(
            "/users/4/preferences",
            json={"theme": "dark"},
            headers=auth_headers("commercial", user_id=3),
        )

        assert resp.status_code == 403

    def test_unknown_preferences_are_rejected(self, client, fake_db):
        fake_db(FakeCursor())

        resp = client.patch(
            "/users/1/preferences", json={"is_admin": True}
        )

        assert resp.status_code == 400
