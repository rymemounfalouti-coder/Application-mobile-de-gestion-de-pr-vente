"""Smoke test for the health-check root route (no DB access)."""


def test_home_ok(client):
    resp = client.get("/")
    assert resp.status_code == 200
    assert resp.get_json() == {"message": "Backend Flask fonctionne"}
