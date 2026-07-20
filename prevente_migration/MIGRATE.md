# Replicating gestion_prevente on another machine

Two things travel: **the repo** (already on GitHub) and **this folder** (the database
dump + your `.env`). Everything else gets rebuilt on the target machine.

## What this folder holds

| File | What it is |
|---|---|
| `prevente_db_full.sql` | Full `pg_dump` of `prevente_db` — schema, constraints, sequences, and all rows. Verified by restoring into a scratch DB: 4 users, 5 clients, 22 produits, 5 factures, 7 lignes, 14 notifications, 31 activités, 11 FKs — identical to source. |
| `MIGRATE.md` | This file. |

You still need to bring `backend/.env` yourself — see step 3.

## Versions on the source machine (match these)

- Flutter **3.44.4** stable (Dart 3.12.2)
- Python **3.11.0**
- PostgreSQL **16.8**

A different Postgres major version will likely refuse this dump. Flutter/Python can
drift a little, but matching avoids surprises.

## Steps on the new machine

### 1. Clone and check out the right branch

```bash
git clone https://github.com/rymemounfalouti-coder/Application-mobile-de-gestion-de-pr-vente.git gestion_prevente
cd gestion_prevente
git checkout temp
```

The work is on **`temp`**, not `main`. `main` does not have it.

### 2. Restore the database

```bash
psql -U postgres -c "CREATE DATABASE prevente_db;"
psql -U postgres -d prevente_db -v ON_ERROR_STOP=1 -f /path/to/prevente_db_full.sql
```

The dump is `--clean --if-exists --no-owner --no-privileges`, so it is safe to re-run
and does not care what your Postgres role is called.

### 3. Bring over `backend/.env`

It is gitignored — it holds `DB_PASSWORD` and `JWT_SECRET_KEY` — so it is **not** in the
clone. Copy it from this machine:

```bash
cp "C:/Users/user/OneDrive/Desktop/gestion_prevente/backend/.env" <this-folder>/
```

Then drop it into `backend/.env` on the target. Change `DB_PASSWORD` to match the new
machine's postgres password if it differs.

Optional, to match this machine's dev setup: `FLASK_DEBUG=1` enables the auto-reloader,
so backend edits restart the server themselves.

### 4. Rebuild the Python venv — do not reuse the committed one

`backend/venv/` is committed (1193 files), but a Windows virtualenv hardcodes absolute
paths in `pyvenv.cfg` and its `Scripts/` shims. It will not run under a different user
or install path. Delete it locally and rebuild:

```bash
cd backend
rm -rf venv
python -m venv venv
./venv/Scripts/python.exe -m pip install -r requirements.txt
./venv/Scripts/python.exe -m pip install -r requirements-dev.txt   # to run the tests
```

### 5. Flutter deps

```bash
cd ..
flutter pub get
```

### 6. Run and verify

```bash
cd backend && ./venv/Scripts/python.exe app.py     # http://127.0.0.1:5000
cd .. && flutter run
```

Checks that the copy is faithful:

```bash
cd backend && ./venv/Scripts/python.exe -m pytest -q     # expect 100 passed, 9 skipped
```

The admin login is the seeded account in `.env` / `seed_admin.sql`.

Android emulator reaches the host at `10.0.2.2`, not `127.0.0.1` — `api_service.dart`
handles that automatically. For a physical device, pass your PC's LAN IP:
`flutter run --dart-define=API_BASE_URL=http://<LAN-IP>:5000`.

## What does NOT come across

Some app state lives inside the Android app sandbox, not in Postgres:

- **Commercial objectives** — on-device SQLite (`CommercialObjectivesService`)
- **`local_json_store` blobs** — app support directory natively, `localStorage` on web

A fresh install starts empty there. Objectives will read as 0 until re-entered. To carry
them too, pull the app's data directory off the emulator with
`adb backup` / `adb pull` before wiping, or just re-enter them — there are only a
handful.

## Worth fixing while you are at it

`backend/venv/` should not be in git. It is ~1193 files of machine-specific binaries
that cannot work anywhere but this machine:

```bash
git rm -r --cached backend/venv
echo "backend/venv/" >> .gitignore
git commit -m "stop tracking the virtualenv"
```

`requirements.txt` already describes it, which is the part that actually travels.
