"""Tests for /notifications routes."""

from conftest import FakeCursor


class TestList:
    def test_list_all(self, client, fake_db):
        fake_db(FakeCursor(fetchall=[[{"id": 1, "titre": "X"}]]))
        resp = client.get("/notifications")
        assert resp.status_code == 200
        assert len(resp.get_json()) == 1

    def test_list_scoped_to_manager(self, client, fake_db):
        conn = fake_db(FakeCursor(fetchall=[[{"id": 1}]]))
        resp = client.get("/notifications?manager_id=2")
        assert resp.status_code == 200
        # manager filter reaches the WHERE clause
        assert "manager_id = %s" in conn._cursor.sql


class TestMarkRead:
    def test_missing_returns_404(self, client, fake_db):
        fake_db(FakeCursor(fetchone=[None]))
        resp = client.patch("/notifications/999/read")
        assert resp.status_code == 404

    def test_marks_read(self, client, fake_db):
        fake_db(FakeCursor(fetchone=[{"id": 1, "is_read": True}]))
        resp = client.patch("/notifications/1/read")
        assert resp.status_code == 200


def test_mark_all_read(client, fake_db):
    fake_db(FakeCursor(fetchall=[[{"id": 1}, {"id": 2}]]))
    resp = client.patch("/notifications/read-all")
    assert resp.status_code == 200
    assert len(resp.get_json()) == 2


class TestDelete:
    def test_missing_returns_404(self, client, fake_db):
        fake_db(FakeCursor(fetchone=[None]))
        resp = client.delete("/notifications/999")
        assert resp.status_code == 404

    def test_delete_existing(self, client, fake_db):
        fake_db(FakeCursor(fetchone=[{"id": 5}]))
        resp = client.delete("/notifications/5")
        assert resp.status_code == 200
        assert resp.get_json()["id"] == 5
