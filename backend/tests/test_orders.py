"""Tests for the commande/facture routes (list, detail, create, status)."""

from conftest import FakeCursor


class TestList:
    def test_empty_list(self, client, fake_db):
        fake_db(FakeCursor(columns={"factures": []}, fetchall=[[]]))
        resp = client.get("/commandes")
        assert resp.status_code == 200
        assert resp.get_json() == []

    def test_manager_endpoint_empty(self, client, fake_db):
        fake_db(FakeCursor(columns={"factures": []}, fetchall=[[]]))
        resp = client.get("/manager/commandes?manager_id=2")
        assert resp.status_code == 200
        assert resp.get_json() == []


class TestDetail:
    def test_missing_returns_404(self, client, fake_db):
        fake_db(FakeCursor(fetchone=[None]))
        resp = client.get("/commandes/999")
        assert resp.status_code == 404


class TestStatusUpdate:
    def test_missing_order_returns_404(self, client, fake_db):
        fake_db(
            FakeCursor(
                columns={"factures": ["status", "statut", "updated_at"]},
                fetchone=[None],
            )
        )
        resp = client.patch("/commandes/999", json={"status": "validee"})
        assert resp.status_code == 404

    def test_no_status_column_returns_500(self, client, fake_db):
        # a factures table with no status/statut/updated_at -> nothing to set
        fake_db(FakeCursor(columns={"factures": ["id"]}))
        resp = client.patch("/commandes/1", json={"status": "validee"})
        assert resp.status_code == 500

    def test_validation_logs_activity(self, client, fake_db):
        order = {
            "id": 1,
            "status": "validee",
            "commercial_id": 3,
            "client_id": 8,
            "order_number": "CMD-2026-001",
        }
        activity = {"id": 1, "type_action": "commande_validee_manager"}
        conn = fake_db(
            FakeCursor(
                columns={
                    "factures": ["status", "statut", "updated_at"],
                    "activites_recentes": [
                        "id", "type_action", "titre", "description",
                        "commercial_id", "commande_id", "client_id", "created_at",
                    ],
                },
                fetchone=[order, activity],
            )
        )
        resp = client.patch("/commandes/1", json={"status": "validee"})
        assert resp.status_code == 200
        assert resp.get_json()["status"] == "validee"
        assert "activites_recentes" in conn._cursor.sql


class TestCreate:
    def test_db_failure_returns_500(self, client, fake_db):
        # execute() blows up inside the try block -> rolled back, 500
        conn = fake_db(FakeCursor(boom=True))
        resp = client.post("/commandes", json={"total": 100, "lines": []})
        assert resp.status_code == 500
        assert "error" in resp.get_json()
        assert conn.rolled_back >= 1
