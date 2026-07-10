"""Shared pytest fixtures + a DB-free psycopg2 stand-in.

The whole suite (except test_integration.py) runs without PostgreSQL: routes
call ``app.get_db_connection()``, which we monkeypatch to return ``FakeConn``.
``FakeCursor`` answers the app's ``_columns()`` introspection from a supplied
column map and returns queued rows for ``fetchone``/``fetchall``.
"""

import os
import sys

import pytest

_THIS_DIR = os.path.dirname(__file__)
sys.path.insert(0, _THIS_DIR)  # so `from conftest import FakeCursor` works
sys.path.insert(0, os.path.abspath(os.path.join(_THIS_DIR, "..")))  # -> app.py

import app as appmod  # noqa: E402
from app import app as flask_app  # noqa: E402


class FakeCursor:
    """Minimal psycopg2 RealDictCursor replacement.

    Parameters
    ----------
    fetchone / fetchall:
        Queues of rows returned (in order) by non-introspection queries.
    columns:
        Either a list (same columns for every table) or a dict keyed by table
        name. Used to answer the ``information_schema.columns`` lookup that
        ``app._columns`` performs.
    boom:
        When True, ``execute`` raises — used to exercise error branches.
    """

    def __init__(self, fetchone=None, fetchall=None, columns=None, boom=False):
        self.columns = columns if columns is not None else []
        self._fetchone = list(fetchone or [])
        self._fetchall = list(fetchall or [])
        self.boom = boom
        self.executed = []
        self._last_sql = ""
        self._last_params = None

    # --- psycopg2 cursor API ------------------------------------------------
    def execute(self, sql, params=None):
        self.executed.append((sql, params))
        self._last_sql = sql
        self._last_params = params
        if self.boom:
            raise RuntimeError("boom")

    def fetchone(self):
        return self._fetchone.pop(0) if self._fetchone else None

    def fetchall(self):
        if "information_schema.columns" in self._last_sql:
            return [{"column_name": c} for c in self._columns_for()]
        return self._fetchall.pop(0) if self._fetchall else []

    def close(self):
        pass

    # --- helpers ------------------------------------------------------------
    def _columns_for(self):
        table = None
        if self._last_params:
            table = (
                self._last_params[0]
                if isinstance(self._last_params, (list, tuple))
                else self._last_params
            )
        if isinstance(self.columns, dict):
            return self.columns.get(table, [])
        return self.columns

    @property
    def sql(self):
        """All executed SQL joined — handy for `in` assertions."""
        return " ".join(sql for sql, _ in self.executed)


class FakeConn:
    def __init__(self, cursor):
        self._cursor = cursor
        self.committed = 0
        self.rolled_back = 0
        self.closed = False

    def cursor(self, *args, **kwargs):
        return self._cursor

    def commit(self):
        self.committed += 1

    def rollback(self):
        self.rolled_back += 1

    def close(self):
        self.closed = True


@pytest.fixture
def client():
    flask_app.config.update(TESTING=True)
    return flask_app.test_client()


@pytest.fixture
def fake_db(monkeypatch):
    """Install a FakeConn wrapping the given cursor; return the conn."""

    def _install(cursor):
        conn = FakeConn(cursor)
        monkeypatch.setattr(appmod, "get_db_connection", lambda: conn)
        return conn

    return _install
