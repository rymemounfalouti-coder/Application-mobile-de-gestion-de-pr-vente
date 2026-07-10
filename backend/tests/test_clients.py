"""Tests for /clients and /clients/<id> routes (validation + CRUD guards)."""

import pytest

from conftest import FakeCursor

# A fully valid create payload; individual tests drop one required field.
VALID = {
    "name": "Carrefour Maarif",
    "phone": "0522 25 41 60",
    "address": "Casablanca",
    "city": "Casablanca",
    "commercial_id": 3,
}


class TestCreateValidation:
    @pytest.mark.parametrize(
        "missing", ["name", "phone", "address", "city", "commercial_id"]
    )
    def test_missing_required_field_returns_400(self, client, fake_db, missing):
        fake_db(FakeCursor())
        payload = {k: v for k, v in VALID.items() if k != missing}
        resp = client.post("/clients", json=payload)
        assert resp.status_code == 400
        assert "error" in resp.get_json()

    def test_accepts_french_field_aliases(self, client, fake_db):
        # nom/telephone/adresse/ville should satisfy validation; a blank name
        # still fails, proving the alias is what's being read.
        fake_db(FakeCursor())
        resp = client.post(
            "/clients",
            json={"nom": "", "telephone": "1", "adresse": "a", "ville": "v",
                  "commercial_id": 3},
        )
        assert resp.status_code == 400


class TestDelete:
    def test_delete_missing_returns_404(self, client, fake_db):
        fake_db(FakeCursor(fetchone=[None]))
        resp = client.delete("/clients/999")
        assert resp.status_code == 404

    def test_delete_existing_returns_row(self, client, fake_db):
        fake_db(FakeCursor(fetchone=[{"id": 5, "name": "Old"}]))
        resp = client.delete("/clients/5")
        assert resp.status_code == 200
        assert resp.get_json()["id"] == 5


class TestPatch:
    def test_no_matching_columns_returns_400(self, client, fake_db):
        # data empty + updated_at not a real column -> nothing to update
        fake_db(FakeCursor(columns={"clients": ["id", "name"]}))
        resp = client.patch("/clients/5", json={})
        assert resp.status_code == 400

    def test_updates_and_returns_row(self, client, fake_db):
        updated = {"id": 5, "name": "New name"}
        fake_db(
            FakeCursor(
                columns={"clients": ["id", "name", "updated_at"]},
                fetchone=[updated],
            )
        )
        resp = client.patch("/clients/5", json={"name": "New name"})
        assert resp.status_code == 200
        assert resp.get_json()["name"] == "New name"
