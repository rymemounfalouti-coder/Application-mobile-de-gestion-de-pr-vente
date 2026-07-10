"""Tests for the /company-info route (GET + PUT)."""

from conftest import FakeCursor


def test_put_missing_name_returns_400(client, fake_db):
    fake_db(FakeCursor())
    resp = client.put("/company-info", json={"name": "   "})
    assert resp.status_code == 400


def test_put_updates_and_returns_row(client, fake_db):
    row = {"id": 1, "name": "Ryme Distribution", "currency": "DH"}
    fake_db(FakeCursor(fetchone=[row]))
    resp = client.put("/company-info", json={"name": "Ryme Distribution"})
    assert resp.status_code == 200
    assert resp.get_json()["name"] == "Ryme Distribution"


def test_get_returns_row(client, fake_db):
    row = {"id": 1, "name": "Ryme Distribution"}
    fake_db(FakeCursor(fetchone=[row]))
    resp = client.get("/company-info")
    assert resp.status_code == 200
    assert resp.get_json()["id"] == 1
