"""One-shot local DB bootstrap: creates prevente_db (if missing), applies
schema_export.sql, then seed_admin.sql. Reads DB_* from backend/.env.

Usage: python setup_db.py
"""
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
    return psycopg2.connect(
        host=DB_HOST, port=DB_PORT, user=DB_USER, password=DB_PASSWORD, dbname=dbname
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
    ensure_database()
    run_sql_file(HERE / "schema_export.sql")
    run_sql_file(HERE / "seed_admin.sql")
    print("Done. Login with admin@prevente.local / admin123")
