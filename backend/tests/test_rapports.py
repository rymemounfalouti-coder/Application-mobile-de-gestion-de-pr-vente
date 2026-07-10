"""Tests for /rapports routes (list, mark-read, manager comment)."""

from conftest import FakeCursor


def test_list_returns_rows(client, fake_db):
    fake_db(FakeCursor(fetchall=[[{"id": 1, "summary": "RAS"}]]))
    resp = client.get("/rapports")
    assert resp.status_code == 200
    assert len(resp.get_json()) == 1


class TestMarkRead:
    def test_missing_returns_404(self, client, fake_db):
        fake_db(FakeCursor(fetchone=[None]))
        resp = client.patch("/rapports/999/read")
        assert resp.status_code == 404

    def test_marks_read(self, client, fake_db):
        fake_db(FakeCursor(fetchone=[{"id": 1, "is_read": True}]))
        resp = client.patch("/rapports/1/read")
        assert resp.status_code == 200
        assert resp.get_json()["is_read"] is True


class TestComment:
    def test_missing_returns_404(self, client, fake_db):
        fake_db(FakeCursor(fetchone=[None]))
        resp = client.post("/rapports/999/comments", json={"comment": "hi"})
        assert resp.status_code == 404

    def test_saves_comment(self, client, fake_db):
        fake_db(FakeCursor(fetchone=[{"id": 1, "manager_comment": "Bien joué"}]))
        resp = client.post("/rapports/1/comments", json={"comment": "Bien joué"})
        assert resp.status_code == 200
        assert resp.get_json()["manager_comment"] == "Bien joué"
