"""Unit tests for the pure / near-pure helper functions in app.py."""

import pytest

from app import (
    _columns,
    _first_existing,
    _hash_password,
    _insert_existing,
    _normalize_status,
    _normalize_user_role,
    _password_matches,
)
from conftest import FakeCursor


class TestNormalizeStatus:
    @pytest.mark.parametrize(
        "raw,expected",
        [
            ("pending", "en_attente"),
            ("en attente", "en_attente"),
            (None, "en_attente"),
            ("", "en_attente"),
            ("validated", "validee"),
            ("valide", "validee"),
            ("validée", "validee"),
            ("synced", "validee"),
            ("delivered", "validee"),
            ("refused", "refusee"),
            ("rejected", "refusee"),
            ("cancelled", "refusee"),
            ("  EN ATTENTE  ", "en_attente"),  # trims + lowercases
            ("something_else", "something_else"),  # unknown passes through
        ],
    )
    def test_mapping(self, raw, expected):
        assert _normalize_status(raw) == expected


class TestNormalizeUserRole:
    @pytest.mark.parametrize(
        "raw,expected",
        [
            ("admin", "admin"),
            ("Administrateur", "admin"),
            ("manager", "manager"),
            ("Manageur", "manager"),
            ("commercial", "commercial"),
            ("Vendeur", "commercial"),  # unknown -> commercial
            (None, "commercial"),
            ("", "commercial"),
        ],
    )
    def test_mapping(self, raw, expected):
        assert _normalize_user_role(raw) == expected


class TestFirstExisting:
    def test_returns_first_present_candidate(self):
        assert _first_existing({"a", "b"}, ["x", "b", "a"]) == "b"

    def test_default_fallback_is_null_literal(self):
        assert _first_existing(set(), ["x"]) == "NULL"

    def test_custom_fallback(self):
        assert _first_existing(set(), ["x"], fallback=None) is None


class TestPasswords:
    def test_hash_roundtrip(self):
        hashed = _hash_password("s3cret")
        assert hashed != "s3cret"
        assert _password_matches(hashed, "s3cret")
        assert not _password_matches(hashed, "wrong")

    def test_hash_defaults_when_empty(self):
        # falls back to "123456" when no password supplied
        assert _password_matches(_hash_password(None), "123456")

    def test_plaintext_equality_when_not_hashed(self):
        assert _password_matches("plainpw", "plainpw")
        assert not _password_matches("plainpw", "nope")


class TestColumns:
    def test_reads_column_names_as_set(self):
        cur = FakeCursor(columns={"clients": ["id", "name", "phone"]})
        assert _columns(cur, "clients") == {"id", "name", "phone"}

    def test_passes_table_name_as_param(self):
        cur = FakeCursor(columns={"users": ["id"]})
        _columns(cur, "users")
        assert cur.executed[-1][1] == ("users",)


class TestInsertExisting:
    def test_filters_to_existing_columns(self):
        row = {"id": 1, "name": "Acme"}
        cur = FakeCursor(columns={"clients": ["id", "name"]}, fetchone=[row])
        result = _insert_existing(
            cur, "clients", {"name": "Acme", "ghost_col": "dropped"}
        )
        assert result == row
        # the INSERT only mentions the real column, not the ghost one
        insert_sql = cur.executed[-1][0]
        assert "name" in insert_sql
        assert "ghost_col" not in insert_sql

    def test_raises_when_no_compatible_columns(self):
        cur = FakeCursor(columns={"clients": []})
        with pytest.raises(ValueError):
            _insert_existing(cur, "clients", {"whatever": 1})
