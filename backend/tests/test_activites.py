"""Tests for the /activites-recentes route (the endpoint the app was calling
in the ERR_CONNECTION_REFUSED log)."""

from conftest import FakeCursor

ACTIVITY_COLS = {
    "activites_recentes": [
        "id",
        "type_action",
        "titre",
        "description",
        "commercial_id",
        "commande_id",
        "client_id",
        "created_at",
    ]
}


def test_post_creates_activity(client, fake_db):
    row = {"id": 1, "type_action": "visite", "titre": "Visite client",
           "commercial_id": 3}
    fake_db(FakeCursor(columns=ACTIVITY_COLS, fetchone=[row]))
    resp = client.post(
        "/activites-recentes",
        json={"type_action": "visite", "titre": "Visite client",
              "commercial_id": 3},
    )
    assert resp.status_code == 201
    assert resp.get_json()["type_action"] == "visite"


def test_post_via_commercial_prefixed_alias(client, fake_db):
    # both /activites-recentes and /commercial/activites-recentes map here
    row = {"id": 2, "type_action": "action", "titre": "Activité récente"}
    fake_db(FakeCursor(columns=ACTIVITY_COLS, fetchone=[row]))
    resp = client.post("/commercial/activites-recentes", json={})
    assert resp.status_code == 201


def test_get_filtered_by_commercial(client, fake_db):
    rows = [{"id": 1, "type_action": "visite", "commercial_id": 3}]
    fake_db(FakeCursor(fetchall=[rows]))
    resp = client.get("/activites-recentes?commercial_id=3")
    assert resp.status_code == 200
    assert len(resp.get_json()) == 1
