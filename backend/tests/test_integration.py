"""Opt-in integration tests against a real PostgreSQL instance.

These exercise the dynamic-column introspection and real SQL that the mocked
suite can't. They are READ-ONLY (no inserts) so they won't pollute your data,
and they are skipped unless you explicitly enable them:

    RUN_DB_TESTS=1 pytest backend/tests/test_integration.py

They connect via app.get_db_connection() (localhost prevente_db). If the DB
isn't reachable, each test is skipped rather than failed.
"""

import os

import pytest

import app as appmod

pytestmark = pytest.mark.skipif(
    not os.environ.get("RUN_DB_TESTS"),
    reason="set RUN_DB_TESTS=1 to run integration tests against a real DB",
)


@pytest.fixture(autouse=True)
def require_db():
    try:
        conn = appmod.get_db_connection()
        conn.close()
    except Exception as exc:  # pragma: no cover - depends on environment
        pytest.skip(f"PostgreSQL not reachable: {exc}")


def test_home(client):
    assert client.get("/").status_code == 200


@pytest.mark.parametrize(
    "path",
    ["/users", "/produits", "/clients", "/commandes", "/rapports",
     "/notifications", "/company-info"],
)
def test_read_endpoints_return_json(client, path):
    resp = client.get(path)
    assert resp.status_code == 200
    # every read endpoint returns JSON (list, or an object for company-info)
    assert resp.is_json


def test_login_rejects_bad_credentials(client):
    resp = client.post(
        "/login",
        json={"email": "definitely-not-a-user@example.invalid", "password": "x"},
    )
    assert resp.status_code == 401
