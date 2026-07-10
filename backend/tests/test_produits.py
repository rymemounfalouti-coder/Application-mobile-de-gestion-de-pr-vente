"""Tests for /produits and /produits/<id> routes."""

from conftest import FakeCursor

PRODUIT_COLS = {"produits": ["id", "name", "nom_produit", "reference", "ref", "code"]}


class TestCreate:
    def test_missing_reference_returns_400(self, client, fake_db):
        fake_db(FakeCursor())
        resp = client.post("/produits", json={"name": "Thé vert"})
        assert resp.status_code == 400

    def test_duplicate_reference_returns_409(self, client, fake_db):
        fake_db(FakeCursor(columns=PRODUIT_COLS, fetchone=[{"id": 12}]))
        resp = client.post(
            "/produits", json={"reference": "41022-2000", "name": "Thé"}
        )
        assert resp.status_code == 409


class TestPatch:
    def test_duplicate_reference_returns_409(self, client, fake_db):
        fake_db(FakeCursor(columns=PRODUIT_COLS, fetchone=[{"id": 99}]))
        resp = client.patch("/produits/5", json={"reference": "41022-2000"})
        assert resp.status_code == 409


class TestDelete:
    def test_delete_missing_returns_404(self, client, fake_db):
        fake_db(FakeCursor(fetchone=[None]))
        resp = client.delete("/produits/999")
        assert resp.status_code == 404

    def test_delete_existing_returns_row(self, client, fake_db):
        fake_db(FakeCursor(fetchone=[{"id": 3, "name": "Thé"}]))
        resp = client.delete("/produits/3")
        assert resp.status_code == 200
        assert resp.get_json()["id"] == 3
