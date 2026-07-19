"""Local database bootstrap and additive demo-data recovery.

Reads DB_* from backend/.env or the current environment.

Usage:
    python setup_db.py
    python setup_db.py --seed-only
    python setup_db.py --wipe   # drop every table and rebuild from schema_export.sql
"""
import argparse
import os
from pathlib import Path

import psycopg2
from dotenv import load_dotenv

load_dotenv()

HERE = Path(__file__).parent
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")
DB_NAME = os.getenv("DB_NAME", "prevente_db")


def _connect(dbname):
    try:
        return psycopg2.connect(
            host=DB_HOST, port=DB_PORT, user=DB_USER, password=DB_PASSWORD, dbname=dbname
        )
    except (psycopg2.OperationalError, UnicodeDecodeError) as exc:
        raise SystemExit(
            f"Could not connect to Postgres as {DB_USER!r} (host={DB_HOST}, db={dbname}). "
            f"Check DB_PASSWORD in backend/.env matches this machine's postgres password. "
            f"Original error: {exc!r}"
        )


def ensure_database():
    conn = _connect("postgres")
    conn.autocommit = True
    cur = conn.cursor()
    cur.execute("SELECT 1 FROM pg_database WHERE datname = %s", (DB_NAME,))
    if not cur.fetchone():
        cur.execute(f'CREATE DATABASE "{DB_NAME}"')
        print(f"Created database {DB_NAME}")
    else:
        print(f"Database {DB_NAME} already exists")
    cur.close()
    conn.close()


def wipe_database():
    conn = _connect(DB_NAME)
    conn.autocommit = True
    cur = conn.cursor()
    cur.execute("DROP SCHEMA public CASCADE; CREATE SCHEMA public;")
    cur.close()
    conn.close()
    print(f"Wiped all tables in {DB_NAME}")


def run_sql_file(path):
    sql = path.read_text(encoding="utf-8")
    conn = _connect(DB_NAME)
    conn.autocommit = True
    cur = conn.cursor()
    cur.execute(sql)
    cur.close()
    conn.close()
    print(f"Applied {path.name}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--seed-only",
        action="store_true",
        help="Restore additive seed data without reapplying the schema.",
    )
    parser.add_argument(
        "--wipe",
        action="store_true",
        help="Drop every table first, then rebuild the schema from scratch.",
    )
    args = parser.parse_args()

    if args.wipe:
        ensure_database()
        wipe_database()
        run_sql_file(HERE / "schema_export.sql")
    elif not args.seed_only:
        ensure_database()
        run_sql_file(HERE / "schema_export.sql")
    run_sql_file(HERE / "seed_admin.sql")
    run_sql_file(HERE / "seed_demo_products.sql")
    print("Done. Restored the 20-product TeaSud catalog without replacing existing rows.")
