from datetime import datetime

from flask import Flask, request, jsonify
from flask_cors import CORS
import psycopg2
import psycopg2.extras
from werkzeug.security import check_password_hash, generate_password_hash

app = Flask(__name__)
app.config["JSON_AS_ASCII"] = False
app.json.ensure_ascii = False
CORS(app)


def get_db_connection():
    return psycopg2.connect(
        host="localhost",
        database="prevente_db",
        user="postgres",
        password="ryme24102005",
        port=5432,
    )


def _columns(cur, table):
    cur.execute(
        """
        SELECT column_name
        FROM information_schema.columns
        WHERE table_name = %s
        """,
        (table,),
    )
    return {row["column_name"] for row in cur.fetchall()}


def _insert_existing(cur, table, values):
    cols = _columns(cur, table)
    payload = {key: value for key, value in values.items() if key in cols}
    if not payload:
        raise ValueError(f"Aucune colonne compatible pour {table}")
    names = list(payload.keys())
    placeholders = ", ".join(["%s"] * len(names))
    sql = f"""
        INSERT INTO {table} ({", ".join(names)})
        VALUES ({placeholders})
        RETURNING *
    """
    cur.execute(sql, [payload[name] for name in names])
    return cur.fetchone()


def _ensure_notifications_table(cur):
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS notifications (
            id SERIAL PRIMARY KEY,
            manager_id INTEGER,
            commercial_id INTEGER,
            commande_id INTEGER,
            type VARCHAR(80) NOT NULL,
            titre VARCHAR(180) NOT NULL,
            message TEXT,
            is_read BOOLEAN DEFAULT FALSE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
        """
    )
    cur.execute("ALTER TABLE notifications ADD COLUMN IF NOT EXISTS description TEXT")
    cur.execute("ALTER TABLE notifications ADD COLUMN IF NOT EXISTS client_id INTEGER")
    cur.execute("ALTER TABLE notifications ADD COLUMN IF NOT EXISTS objectif_id INTEGER")
    cur.execute("ALTER TABLE notifications ADD COLUMN IF NOT EXISTS user_id INTEGER")


def _create_notification(
    cur,
    type_,
    titre,
    description="",
    manager_id=None,
    commercial_id=None,
    commande_id=None,
    client_id=None,
):
    _ensure_notifications_table(cur)
    return _insert_existing(
        cur,
        "notifications",
        {
            "manager_id": manager_id,
            "commercial_id": commercial_id,
            "commande_id": commande_id,
            "client_id": client_id,
            "type": type_,
            "titre": titre,
            "message": description,
            "description": description,
            "is_read": False,
            "created_at": datetime.now(),
        },
    )


def _ensure_recent_activity_table(cur):
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS activites_recentes (
            id SERIAL PRIMARY KEY,
            type_action VARCHAR(80) NOT NULL,
            titre VARCHAR(180) NOT NULL,
            description TEXT,
            commercial_id INTEGER,
            commande_id INTEGER,
            client_id INTEGER,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
        """
    )


def _ensure_rapports_table(cur):
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS rapports (
            id SERIAL PRIMARY KEY,
            commercial_id INTEGER,
            manager_id INTEGER,
            commercial_name VARCHAR(180),
            city VARCHAR(120),
            email VARCHAR(180),
            phone VARCHAR(80),
            report_date DATE,
            sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            summary TEXT,
            activities_count INTEGER DEFAULT 0,
            clients_count INTEGER DEFAULT 0,
            calls INTEGER DEFAULT 0,
            meetings INTEGER DEFAULT 0,
            tasks INTEGER DEFAULT 0,
            claims INTEGER DEFAULT 0,
            orders_count INTEGER DEFAULT 0,
            revenue NUMERIC(12, 2) DEFAULT 0,
            comments TEXT,
            manager_comment TEXT,
            is_read BOOLEAN DEFAULT FALSE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
        """
    )


def _ensure_company_info_table(cur):
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS company_info (
            id INTEGER PRIMARY KEY DEFAULT 1,
            name VARCHAR(180) NOT NULL DEFAULT 'Ryme Distribution',
            logo TEXT,
            address TEXT,
            phone VARCHAR(80),
            email VARCHAR(180),
            website VARCHAR(180),
            currency VARCHAR(20) DEFAULT 'DH',
            tax_info TEXT,
            legal_info TEXT,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
        """
    )
    for column, definition in {
        "logo": "TEXT",
        "address": "TEXT",
        "phone": "VARCHAR(80)",
        "email": "VARCHAR(180)",
        "website": "VARCHAR(180)",
        "currency": "VARCHAR(20) DEFAULT 'DH'",
        "tax_info": "TEXT",
        "legal_info": "TEXT",
        "updated_at": "TIMESTAMP DEFAULT CURRENT_TIMESTAMP",
    }.items():
        cur.execute(f"ALTER TABLE company_info ADD COLUMN IF NOT EXISTS {column} {definition}")
    cur.execute(
        """
        INSERT INTO company_info (
            id, name, address, phone, email, website, currency, tax_info, legal_info, updated_at
        )
        VALUES (
            1, 'Ryme Distribution', 'Casablanca, Maroc', '0522 00 00 00',
            'contact@ryme.ma', '', 'DH', '', '', CURRENT_TIMESTAMP
        )
        ON CONFLICT (id) DO NOTHING
        """
    )


def _log_recent_activity(
    cur,
    type_action,
    titre,
    description="",
    commercial_id=None,
    commande_id=None,
    client_id=None,
):
    _ensure_recent_activity_table(cur)
    return _insert_existing(
        cur,
        "activites_recentes",
        {
            "type_action": type_action,
            "titre": titre,
            "description": description,
            "commercial_id": commercial_id,
            "commande_id": commande_id,
            "client_id": client_id,
            "created_at": datetime.now(),
        },
    )


def _ensure_factures_status_constraint(cur):
    cols = _columns(cur, "factures")
    for col in ("status", "statut"):
        if col in cols:
            cur.execute(
                f"""
                UPDATE factures
                SET {col} = CASE
                    WHEN LOWER(TRIM({col})) IN ('pending', 'en attente') THEN 'en_attente'
                    WHEN LOWER(TRIM({col})) IN ('synced', 'delivered') THEN 'validee'
                    WHEN LOWER(TRIM({col})) IN ('cancelled') THEN 'refusee'
                    WHEN LOWER(TRIM({col})) IN ('validated', 'validée', 'valide', 'validé') THEN 'validee'
                    WHEN LOWER(TRIM({col})) IN ('refused', 'rejected', 'refusée', 'refusé') THEN 'refusee'
                    ELSE LOWER(TRIM({col}))
                END
                WHERE {col} IS NOT NULL
                """
            )
    cur.execute("ALTER TABLE factures DROP CONSTRAINT IF EXISTS factures_status_check")
    if "status" in cols:
        cur.execute(
            """
            ALTER TABLE factures
            ADD CONSTRAINT factures_status_check
            CHECK (status IS NULL OR status IN ('en_attente', 'validee', 'refusee'))
            """
        )


def _normalize_status(status):
    value = (status or "en_attente").strip().lower()
    mapping = {
        "en attente": "en_attente",
        "pending": "en_attente",
        "synced": "validee",
        "delivered": "validee",
        "cancelled": "refusee",
        "validée": "validee",
        "validated": "validee",
        "valide": "validee",
        "validé": "validee",
        "refusée": "refusee",
        "refused": "refusee",
        "rejected": "refusee",
    }
    return mapping.get(value, value)


def _first_existing(cols, candidates, fallback="NULL"):
    for candidate in candidates:
        if candidate in cols:
            return candidate
    return fallback


def _hash_password(password):
    return generate_password_hash(str(password or "123456"))


def _password_matches(stored_password, candidate):
    stored = str(stored_password or "")
    candidate = str(candidate or "")
    if stored.startswith(("pbkdf2:", "scrypt:")):
        return check_password_hash(stored, candidate)
    return stored == candidate


def _normalize_user_role(role):
    value = str(role or "commercial").strip().lower()
    if "admin" in value:
        return "admin"
    if "manager" in value or "manageur" in value:
        return "manager"
    return "commercial"


def _commercial_order_count(cur, commercial_id):
    if not commercial_id:
        return 0
    facture_cols = _columns(cur, "factures")
    commercial_fk = _first_existing(
        facture_cols, ["commercial_id", "id_commercial", "user_id", "created_by"], None
    )
    if not commercial_fk:
        return 0
    cur.execute(f"SELECT COUNT(*) AS total FROM factures WHERE {commercial_fk} = %s", (commercial_id,))
    row = cur.fetchone()
    return int((row or {}).get("total") or 0)


def _commercial_business_status(cur, user):
    role = str(user.get("role") or "").lower()
    if "commercial" not in role:
        return str(user.get("status") or user.get("statut") or user.get("etat") or "")
    return "actif" if _commercial_order_count(cur, user.get("id")) > 0 else "inactif"


def _sync_commercial_business_status(cur, commercial_id):
    if not commercial_id:
        return
    user_cols = _columns(cur, "users")
    status_cols = [col for col in ("status", "statut", "etat") if col in user_cols]
    if not status_cols:
        return
    status = "actif" if _commercial_order_count(cur, commercial_id) > 0 else "inactif"
    assignments = ", ".join([f"{col} = %s" for col in status_cols])
    cur.execute(
        f"UPDATE users SET {assignments} WHERE id = %s AND role ILIKE '%%commercial%%'",
        ([status] * len(status_cols)) + [commercial_id],
    )


def _fetch_order(cur, order_id):
    facture_cols = _columns(cur, "factures")
    detail_cols = _columns(cur, "details_facture")
    produit_cols = _columns(cur, "produits")
    client_fk = _first_existing(facture_cols, ["client_id", "id_client"])
    commercial_fk = _first_existing(
        facture_cols, ["commercial_id", "id_commercial", "user_id", "created_by"]
    )
    product_fk = _first_existing(detail_cols, ["produit_id", "id_prod", "product_id"])
    detail_fk = _first_existing(detail_cols, ["facture_id", "id_fact"])
    product_name_col = _first_existing(produit_cols, ["name", "nom_produit", "designation"], None)
    product_ref_col = _first_existing(produit_cols, ["reference", "ref", "code"], None)
    product_img_col = _first_existing(produit_cols, ["image", "photo"], None)
    product_name = f"p.{product_name_col}" if product_name_col else "NULL"
    product_ref = f"p.{product_ref_col}" if product_ref_col else "NULL"
    product_img = f"p.{product_img_col}" if product_img_col else "NULL"
    cur.execute(
        f"""
        SELECT f.*,
               c.name AS client_name,
               c.client_code,
               c.phone AS client_phone,
               c.city AS client_city,
               c.address AS client_address,
               c.business_type AS client_category,
               c.status AS client_status,
               u.nom AS commercial_nom,
               u.prenom AS commercial_prenom,
               u.email AS commercial_email,
               u.phone AS commercial_phone
        FROM factures f
        LEFT JOIN clients c ON c.id = f.{client_fk}
        LEFT JOIN users u ON u.id = f.{commercial_fk}
        WHERE f.id = %s
        """,
        (order_id,),
    )
    order = cur.fetchone()
    if not order:
        return None
    commercial_name = " ".join(
        part for part in [order.get("commercial_prenom"), order.get("commercial_nom")] if part
    ).strip()
    order["commercial_name"] = commercial_name or order.get("commercial_email") or ""
    order["status"] = _normalize_status(order.get("status") or order.get("statut"))
    order["order_number"] = (
        order.get("order_number")
        or order.get("numero_facture")
        or order.get("numero")
        or order.get("reference")
        or f"CMD-{order['id']}"
    )

    product_join = f"LEFT JOIN produits p ON p.id = d.{product_fk}"
    cur.execute(
        f"""
        SELECT d.*,
               {product_ref} AS product_reference,
               {product_name} AS product_name,
               {product_img} AS product_image
        FROM details_facture d
        {product_join}
        WHERE d.{detail_fk} = %s
        ORDER BY d.id
        """,
        (order_id,),
    )
    order["details"] = cur.fetchall()
    return order


def _fetch_orders(cur, manager_id=None, status=None, commercial_id=None, commercial_email=None):
    facture_cols = _columns(cur, "factures")
    client_fk = _first_existing(facture_cols, ["client_id", "id_client"])
    commercial_fk = _first_existing(
        facture_cols, ["commercial_id", "id_commercial", "user_id", "created_by"]
    )
    date_expr = _first_existing(facture_cols, ["created_at", "date", "date_facture"], "id")
    status_col = _first_existing(facture_cols, ["status", "statut"], None)
    where = []
    params = []
    if status and status_col:
        where.append(f"f.{status_col} = %s")
        params.append(_normalize_status(status))
    if commercial_id and commercial_fk != "NULL":
        where.append(f"f.{commercial_fk} = %s")
        params.append(commercial_id)
    if commercial_email:
        where.append("u.email = %s")
        params.append(commercial_email)
    if manager_id and "manager_id" in facture_cols:
        manager_clauses = ["f.manager_id = %s", "f.manager_id IS NULL"]
        if "status" in facture_cols:
            manager_clauses.append("f.status = 'en_attente'")
        if "statut" in facture_cols:
            manager_clauses.append("f.statut = 'en_attente'")
        where.append(
            f"({' OR '.join(manager_clauses)})"
        )
        params.append(manager_id)
    where_sql = f"WHERE {' AND '.join(where)}" if where else ""
    cur.execute(
        f"""
        SELECT f.*,
               c.name AS client_name,
               c.phone AS client_phone,
               c.city AS client_city,
               c.address AS client_address,
               u.nom AS commercial_nom,
               u.prenom AS commercial_prenom,
               u.email AS commercial_email
        FROM factures f
        LEFT JOIN clients c ON c.id = f.{client_fk}
        LEFT JOIN users u ON u.id = f.{commercial_fk}
        {where_sql}
        ORDER BY f.{date_expr} DESC NULLS LAST, f.id DESC
        """,
        params,
    )
    rows = cur.fetchall()
    for row in rows:
        row["status"] = _normalize_status(row.get("status") or row.get("statut"))
        row["order_number"] = (
            row.get("order_number")
            or row.get("numero_facture")
            or row.get("numero")
            or row.get("reference")
            or f"CMD-{row['id']}"
        )
        row["commercial_name"] = " ".join(
            part for part in [row.get("commercial_prenom"), row.get("commercial_nom")] if part
        ).strip() or row.get("commercial_email") or ""
        detail = _fetch_order(cur, row["id"])
        details = detail.get("details", []) if detail else []
        row["details"] = details
        row["items_count"] = len(details)
        row["products_count"] = sum(
            int(item.get("qte") or item.get("quantite") or item.get("quantity") or 0)
            for item in details
        )
    return rows


@app.route("/")
def home():
    return jsonify({"message": "Backend Flask fonctionne"})


@app.route("/company-info", methods=["GET", "PUT"])
def company_info():
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    try:
        _ensure_company_info_table(cur)
        if request.method == "PUT":
            data = request.get_json() or {}
            name = (data.get("name") or data.get("nom") or "").strip()
            if not name:
                return jsonify({"error": "Le nom de l'entreprise est obligatoire"}), 400
            cur.execute(
                """
                UPDATE company_info
                SET
                    name = %s,
                    logo = %s,
                    address = %s,
                    phone = %s,
                    email = %s,
                    website = %s,
                    currency = %s,
                    tax_info = %s,
                    legal_info = %s,
                    updated_at = CURRENT_TIMESTAMP
                WHERE id = 1
                RETURNING *
                """,
                (
                    name,
                    data.get("logo"),
                    data.get("address") or data.get("adresse"),
                    data.get("phone") or data.get("telephone"),
                    data.get("email"),
                    data.get("website") or data.get("site_web"),
                    data.get("currency") or data.get("devise") or "DH",
                    data.get("tax_info") or data.get("fiscal_info"),
                    data.get("legal_info") or data.get("informations_legales"),
                ),
            )
            row = cur.fetchone()
            conn.commit()
            print(f"[COMPANY][PUT] name={row.get('name')} currency={row.get('currency')}")
            return jsonify(row)

        cur.execute("SELECT * FROM company_info WHERE id = 1")
        row = cur.fetchone()
        conn.commit()
        return jsonify(row)
    finally:
        cur.close()
        conn.close()


@app.route("/clients", methods=["GET", "POST"])
def clients():
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    try:
        if request.method == "POST":
            data = request.get_json() or {}
            name = (data.get("name") or data.get("nom") or "").strip()
            if not name:
                return jsonify({"error": "Le nom du client est obligatoire"}), 400
            if not (data.get("phone") or data.get("telephone")):
                return jsonify({"error": "Le téléphone est obligatoire"}), 400
            if not (data.get("address") or data.get("adresse")):
                return jsonify({"error": "L'adresse est obligatoire"}), 400
            if not (data.get("city") or data.get("ville")):
                return jsonify({"error": "La ville est obligatoire"}), 400
            if not data.get("commercial_id"):
                return jsonify({"error": "Le commercial affecté est obligatoire"}), 400

            client_code = (
                data.get("client_code")
                or data.get("code_client")
                or f"CL-{datetime.now().strftime('%Y%m%d%H%M%S')}"
            )
            row = _insert_existing(
                cur,
                "clients",
                {
                    "client_code": client_code,
                    "code_client": client_code,
                    "name": name,
                    "nom": name,
                    "phone": data.get("phone") or data.get("telephone"),
                    "telephone": data.get("phone") or data.get("telephone"),
                    "email": data.get("email"),
                    "city": data.get("city") or data.get("ville") or "Casablanca",
                    "ville": data.get("city") or data.get("ville") or "Casablanca",
                    "address": data.get("address") or data.get("adresse"),
                    "adresse": data.get("address") or data.get("adresse"),
                    "quartier": data.get("quartier") or data.get("district"),
                    "business_type": data.get("business_type") or data.get("category"),
                    "category": data.get("category") or data.get("business_type"),
                    "contact_name": data.get("contact_name"),
                    "responsable": data.get("contact_name") or data.get("responsable"),
                    "notes": data.get("notes") or data.get("commentaire"),
                    "commentaire": data.get("notes") or data.get("commentaire"),
                    "initials": data.get("initials"),
                    "latitude": data.get("latitude"),
                    "longitude": data.get("longitude"),
                    "risk": data.get("risk") or "low",
                    "last_order_date": data.get("last_order_date") or "Nouveau",
                    "status": data.get("status") or "toVisit",
                    "commercial_id": data.get("commercial_id"),
                    "id_commercial": data.get("commercial_id"),
                    "user_id": data.get("commercial_id"),
                    "created_by": data.get("commercial_id"),
                    "created_at": datetime.now(),
                    "updated_at": datetime.now(),
                },
            )
            cur.execute(
                "SELECT id FROM users WHERE role ILIKE '%%manager%%' AND COALESCE(is_active, true)=true ORDER BY id LIMIT 1"
            )
            manager = cur.fetchone()
            _create_notification(
                cur,
                "clients",
                "Nouveau client ajouté",
                f"{row.get('name') or row.get('nom')} • {row.get('city') or row.get('ville') or 'Casablanca'}",
                manager_id=manager["id"] if manager else None,
                commercial_id=data.get("commercial_id"),
                client_id=row.get("id"),
            )
            conn.commit()
            print(
                "[CLIENTS][POST] client créé "
                f"id={row.get('id')} name={row.get('name') or row.get('nom')} "
                f"commercial_id={data.get('commercial_id')}"
            )
            _log_recent_activity(
                cur,
                "nouveau_client",
                "Nouveau client ajouté",
                f"{row.get('name') or row.get('nom')} • {row.get('city') or row.get('ville') or 'Casablanca'}",
                commercial_id=data.get("commercial_id"),
                client_id=row.get("id"),
            )
            conn.commit()
            return jsonify(row), 201

        cols = _columns(cur, "clients")
        where = []
        params = []
        commercial_id = request.args.get("commercial_id")
        commercial_email = request.args.get("commercial_email")
        commercial_col = _first_existing(
            cols, ["commercial_id", "id_commercial", "user_id", "created_by"], None
        )
        join_users = ""
        if commercial_id and commercial_col:
            where.append(f"c.{commercial_col} = %s")
            params.append(commercial_id)
        if commercial_email and commercial_col:
            join_users = f"LEFT JOIN users u ON u.id = c.{commercial_col}"
            where.append("u.email = %s")
            params.append(commercial_email)
        where_sql = f"WHERE {' AND '.join(where)}" if where else ""
        cur.execute(
            f"""
            SELECT
                c.*,
                COALESCE(f.orders_count, 0) AS orders_count,
                COALESCE(f.validated_orders_count, 0) AS validated_orders_count,
                COALESCE(f.ca_total, 0) AS ca_total,
                COALESCE(f.last_order_date::text, c.last_order_date::text) AS computed_last_order_date,
                CASE
                    WHEN lower(COALESCE(c.status, '')) IN ('inactive', 'inactif', 'disabled', 'desactive') THEN 'inactive'
                    WHEN COALESCE(f.validated_orders_count, 0) > 0 THEN 'visited'
                    WHEN COALESCE(f.orders_count, 0) = 0 THEN 'toVisit'
                    ELSE 'toVisit'
                END AS computed_status
            FROM clients c
            {join_users}
            LEFT JOIN (
                SELECT
                    id_client,
                    COUNT(*) AS orders_count,
                    COUNT(*) FILTER (
                        WHERE lower(COALESCE(status, '')) IN ('validee', 'validée', 'validated', 'valide')
                    ) AS validated_orders_count,
                    COALESCE(SUM(total) FILTER (
                        WHERE lower(COALESCE(status, '')) IN ('validee', 'validée', 'validated', 'valide')
                    ), 0) AS ca_total,
                    MAX(date_facture) AS last_order_date
                FROM factures
                GROUP BY id_client
            ) f ON f.id_client = c.id
            {where_sql}
            ORDER BY c.id DESC
            """,
            params,
        )
        rows = cur.fetchall()
        print(
            "[CLIENTS][GET] "
            f"commercial_id={commercial_id} email={commercial_email} count={len(rows)}"
        )
        return jsonify(rows)
    finally:
        cur.close()
        conn.close()


@app.route("/clients/<int:client_id>", methods=["PATCH", "DELETE"])
def update_delete_client(client_id):
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    try:
        if request.method == "DELETE":
            cur.execute("DELETE FROM clients WHERE id = %s RETURNING *", (client_id,))
            row = cur.fetchone()
            conn.commit()
            if not row:
                return jsonify({"message": "Client introuvable"}), 404
            return jsonify(row)

        data = request.get_json() or {}
        cols = _columns(cur, "clients")
        values = {
            "name": data.get("name") or data.get("nom"),
            "nom": data.get("name") or data.get("nom"),
            "phone": data.get("phone") or data.get("telephone"),
            "telephone": data.get("phone") or data.get("telephone"),
            "email": data.get("email"),
            "city": data.get("city") or data.get("ville"),
            "ville": data.get("city") or data.get("ville"),
            "address": data.get("address") or data.get("adresse"),
            "adresse": data.get("address") or data.get("adresse"),
            "quartier": data.get("quartier") or data.get("district"),
            "business_type": data.get("business_type") or data.get("category"),
            "category": data.get("category") or data.get("business_type"),
            "contact_name": data.get("contact_name"),
            "responsable": data.get("contact_name") or data.get("responsable"),
            "notes": data.get("notes") or data.get("commentaire"),
            "commentaire": data.get("notes") or data.get("commentaire"),
            "latitude": data.get("latitude"),
            "longitude": data.get("longitude"),
            "commercial_id": data.get("commercial_id"),
            "id_commercial": data.get("commercial_id"),
            "user_id": data.get("commercial_id"),
            "created_by": data.get("commercial_id"),
            "status": data.get("status") or data.get("statut"),
            "statut": data.get("status") or data.get("statut"),
            "updated_at": datetime.now(),
        }
        payload = {
            key: value
            for key, value in values.items()
            if key in cols and value is not None
        }
        if not payload:
            return jsonify({"message": "Aucune colonne compatible"}), 400
        assignments = ", ".join([f"{key} = %s" for key in payload])
        cur.execute(
            f"UPDATE clients SET {assignments} WHERE id = %s RETURNING *",
            [*payload.values(), client_id],
        )
        row = cur.fetchone()
        conn.commit()
        if not row:
            return jsonify({"message": "Client introuvable"}), 404
        return jsonify(row)
    finally:
        cur.close()
        conn.close()


@app.route("/produits", methods=["GET", "POST"])
def get_produits():
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    try:
        if request.method == "POST":
            data = request.get_json() or {}
            reference = (data.get("reference") or data.get("ref") or "").strip()
            if not reference:
                return jsonify({"message": "Référence obligatoire"}), 400
            cols = _columns(cur, "produits")
            reference_col = _first_existing(cols, ["reference", "ref", "code"], None)
            if reference_col:
                cur.execute(
                    f"SELECT id FROM produits WHERE LOWER({reference_col}) = LOWER(%s) LIMIT 1",
                    (reference,),
                )
                if cur.fetchone():
                    return jsonify({"message": "Référence produit déjà utilisée"}), 409
            row = _insert_existing(
                cur,
                "produits",
                {
                    "nom_produit": data.get("nom_produit") or data.get("name"),
                    "name": data.get("name") or data.get("nom_produit"),
                    "reference": reference,
                    "ref": reference,
                    "code": data.get("code") or reference,
                    "description": data.get("description"),
                    "categorie": data.get("categorie") or data.get("category"),
                    "category": data.get("category") or data.get("categorie"),
                    "prix": data.get("prix") or data.get("price"),
                    "price": data.get("price") or data.get("prix"),
                    "prix_vente": data.get("prix") or data.get("price"),
                    "unit_price": data.get("prix") or data.get("price"),
                    "stock": data.get("stock"),
                    "quantite_stock": data.get("stock"),
                    "status": data.get("status") or data.get("statut") or "actif",
                    "statut": data.get("status") or data.get("statut") or "actif",
                    "image": data.get("image") or data.get("photo"),
                    "photo": data.get("photo") or data.get("image"),
                    "created_at": datetime.now(),
                    "updated_at": datetime.now(),
                },
            )
            conn.commit()
            return jsonify(row), 201

        cur.execute(
            """
            SELECT p.*, c.nom_cat
            FROM produits p
            LEFT JOIN categories c ON p.id_cat = c.id
            ORDER BY p.id
            """
        )
        produits = cur.fetchall()
        return jsonify(produits)
    except psycopg2.IntegrityError as exc:
        conn.rollback()
        return jsonify({"message": "Produit non enregistré", "error": str(exc)}), 400
    except Exception as exc:
        conn.rollback()
        return jsonify({"message": "Erreur produit", "error": str(exc)}), 500
    finally:
        cur.close()
        conn.close()


@app.route("/produits/<int:produit_id>", methods=["PATCH", "DELETE"])
def update_delete_produit(produit_id):
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    try:
        if request.method == "DELETE":
            cur.execute("DELETE FROM produits WHERE id = %s RETURNING *", (produit_id,))
            row = cur.fetchone()
            conn.commit()
            if not row:
                return jsonify({"message": "Produit introuvable"}), 404
            return jsonify(row)

        data = request.get_json() or {}
        cols = _columns(cur, "produits")
        reference = data.get("reference") or data.get("ref")
        if reference:
            reference = reference.strip()
            reference_col = _first_existing(cols, ["reference", "ref", "code"], None)
            if reference_col:
                cur.execute(
                    f"SELECT id FROM produits WHERE LOWER({reference_col}) = LOWER(%s) AND id <> %s LIMIT 1",
                    (reference, produit_id),
                )
                if cur.fetchone():
                    return jsonify({"message": "Référence produit déjà utilisée"}), 409
        values = {
            "nom_produit": data.get("nom_produit") or data.get("name"),
            "name": data.get("name") or data.get("nom_produit"),
            "reference": reference,
            "ref": reference,
            "code": data.get("code") or reference,
            "description": data.get("description"),
            "categorie": data.get("categorie") or data.get("category"),
            "category": data.get("category") or data.get("categorie"),
            "prix": data.get("prix") or data.get("price"),
            "price": data.get("price") or data.get("prix"),
            "prix_vente": data.get("prix") or data.get("price"),
            "unit_price": data.get("prix") or data.get("price"),
            "stock": data.get("stock"),
            "quantite_stock": data.get("stock"),
            "status": data.get("status") or data.get("statut"),
            "statut": data.get("status") or data.get("statut"),
            "image": data.get("image") or data.get("photo"),
            "photo": data.get("photo") or data.get("image"),
            "updated_at": datetime.now(),
        }
        payload = {
            key: value
            for key, value in values.items()
            if key in cols and value is not None
        }
        if not payload:
            return jsonify({"message": "Aucune colonne compatible"}), 400
        assignments = ", ".join([f"{key} = %s" for key in payload])
        cur.execute(
            f"UPDATE produits SET {assignments} WHERE id = %s RETURNING *",
            [*payload.values(), produit_id],
        )
        row = cur.fetchone()
        conn.commit()
        if not row:
            return jsonify({"message": "Produit introuvable"}), 404
        return jsonify(row)
    except psycopg2.IntegrityError as exc:
        conn.rollback()
        return jsonify({"message": "Produit non enregistré", "error": str(exc)}), 400
    except Exception as exc:
        conn.rollback()
        return jsonify({"message": "Erreur produit", "error": str(exc)}), 500
    finally:
        cur.close()
        conn.close()


@app.route("/commercial/activites-recentes", methods=["GET", "POST"])
@app.route("/activites-recentes", methods=["GET", "POST"])
def activites_recentes():
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    try:
        _ensure_recent_activity_table(cur)
        if request.method == "POST":
            data = request.get_json() or {}
            row = _log_recent_activity(
                cur,
                data.get("type_action") or "action",
                data.get("titre") or "Activité récente",
                data.get("description") or "",
                commercial_id=data.get("commercial_id"),
                commande_id=data.get("commande_id"),
                client_id=data.get("client_id"),
            )
            conn.commit()
            print(
                "[ACTIVITES][POST] "
                f"type={row.get('type_action')} commercial_id={row.get('commercial_id')}"
            )
            return jsonify(row), 201

        commercial_id = request.args.get("commercial_id")
        commercial_email = request.args.get("commercial_email")
        if commercial_email and not commercial_id:
            cur.execute(
                "SELECT id FROM users WHERE email = %s ORDER BY id LIMIT 1",
                (commercial_email,),
            )
            user = cur.fetchone()
            commercial_id = user["id"] if user else None
        params = []
        where_sql = ""
        if commercial_id:
            where_sql = "WHERE commercial_id = %s"
            params.append(commercial_id)
        cur.execute(
            f"""
            SELECT *
            FROM activites_recentes
            {where_sql}
            ORDER BY created_at DESC, id DESC
            LIMIT 100
            """,
            params,
        )
        rows = cur.fetchall()
        print(
            "[ACTIVITES][GET] "
            f"commercial_id={commercial_id} email={commercial_email} count={len(rows)}"
        )
        conn.commit()
        return jsonify(rows)
    finally:
        cur.close()
        conn.close()


@app.route("/users", methods=["GET", "POST"])
def get_users():
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    try:
        if request.method == "POST":
            data = request.get_json() or {}
            email = (data.get("email") or "").strip().lower()
            if not email:
                return jsonify({"message": "Email obligatoire"}), 400
            cur.execute("SELECT id FROM users WHERE LOWER(email) = LOWER(%s) LIMIT 1", (email,))
            if cur.fetchone():
                return jsonify({"message": "Cet email existe déjà"}), 409
            full_name = data.get("name") or data.get("full_name") or ""
            prenom = data.get("prenom")
            nom = data.get("nom")
            if not prenom and not nom and full_name:
                parts = full_name.strip().split()
                prenom = parts[0] if parts else ""
                nom = " ".join(parts[1:]) if len(parts) > 1 else ""
            role = _normalize_user_role(data.get("role"))
            business_status = "inactif" if "commercial" in str(role).lower() else "actif"
            row = _insert_existing(
                cur,
                "users",
                {
                    "nom": nom,
                    "prenom": prenom,
                    "name": full_name,
                    "email": email,
                    "phone": data.get("phone") or data.get("telephone"),
                    "telephone": data.get("phone") or data.get("telephone"),
                    "password": _hash_password(data.get("password") or "123456"),
                    "role": role,
                    "is_active": data.get("is_active", True),
                    "status": business_status,
                    "statut": business_status,
                    "etat": business_status,
                    "created_at": datetime.now(),
                    "updated_at": datetime.now(),
                },
            )
            row["password"] = None
            row["status"] = _commercial_business_status(cur, row)
            row["statut"] = row["status"]
            row["etat"] = row["status"]
            conn.commit()
            return jsonify(row), 201

        cur.execute("SELECT * FROM users ORDER BY id")
        users = cur.fetchall()
        for user in users:
            user["password"] = None
            business_status = _commercial_business_status(cur, user)
            if business_status:
                user["status"] = business_status
                user["statut"] = business_status
                user["etat"] = business_status
        return jsonify(users)
    except psycopg2.IntegrityError as exc:
        conn.rollback()
        return jsonify({"message": "Utilisateur non enregistré", "error": str(exc)}), 400
    except Exception as exc:
        conn.rollback()
        return jsonify({"message": "Erreur utilisateur", "error": str(exc)}), 500
    finally:
        cur.close()
        conn.close()


@app.route("/users/<int:user_id>", methods=["PATCH", "DELETE"])
def update_delete_user(user_id):
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    try:
        if request.method == "DELETE":
            cur.execute("DELETE FROM users WHERE id = %s RETURNING *", (user_id,))
            row = cur.fetchone()
            conn.commit()
            if not row:
                return jsonify({"message": "Utilisateur introuvable"}), 404
            return jsonify(row)

        data = request.get_json() or {}
        cols = _columns(cur, "users")
        if data.get("email"):
            email = data.get("email").strip().lower()
            cur.execute(
                "SELECT id FROM users WHERE LOWER(email) = LOWER(%s) AND id <> %s LIMIT 1",
                (email, user_id),
            )
            if cur.fetchone():
                return jsonify({"message": "Cet email existe déjà"}), 409
            data["email"] = email
        full_name = data.get("name") or data.get("full_name")
        prenom = data.get("prenom")
        nom = data.get("nom")
        if full_name and not prenom and not nom:
            parts = full_name.strip().split()
            prenom = parts[0] if parts else ""
            nom = " ".join(parts[1:]) if len(parts) > 1 else ""
        role = _normalize_user_role(data.get("role")) if data.get("role") else None
        business_status = None
        if role and "commercial" in str(role).lower():
            business_status = "actif" if _commercial_order_count(cur, user_id) > 0 else "inactif"
        values = {
            "nom": nom,
            "prenom": prenom,
            "name": full_name,
            "email": data.get("email"),
            "phone": data.get("phone") or data.get("telephone"),
            "telephone": data.get("phone") or data.get("telephone"),
            "password": _hash_password(data.get("password")) if data.get("password") else None,
            "role": role,
            "is_active": data.get("is_active"),
            "status": business_status,
            "statut": business_status,
            "etat": business_status,
            "updated_at": datetime.now(),
        }
        payload = {
            key: value
            for key, value in values.items()
            if key in cols and value is not None
        }
        if not payload:
            return jsonify({"message": "Aucune colonne compatible"}), 400
        assignments = ", ".join([f"{key} = %s" for key in payload])
        cur.execute(
            f"UPDATE users SET {assignments} WHERE id = %s RETURNING *",
            [*payload.values(), user_id],
        )
        row = cur.fetchone()
        conn.commit()
        if not row:
            return jsonify({"message": "Utilisateur introuvable"}), 404
        row["password"] = None
        business_status = _commercial_business_status(cur, row)
        if business_status:
            row["status"] = business_status
            row["statut"] = business_status
            row["etat"] = business_status
        return jsonify(row)
    except psycopg2.IntegrityError as exc:
        conn.rollback()
        return jsonify({"message": "Utilisateur non enregistré", "error": str(exc)}), 400
    except Exception as exc:
        conn.rollback()
        return jsonify({"message": "Erreur utilisateur", "error": str(exc)}), 500
    finally:
        cur.close()
        conn.close()


@app.route("/rapports", methods=["GET", "POST"])
def rapports():
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    try:
        _ensure_rapports_table(cur)
        _ensure_notifications_table(cur)
        if request.method == "POST":
            data = request.get_json() or {}
            commercial_id = data.get("commercial_id")
            manager_id = data.get("manager_id")
            if not manager_id:
                cur.execute(
                    "SELECT id FROM users WHERE role ILIKE '%%manager%%' AND COALESCE(is_active, true)=true ORDER BY id LIMIT 1"
                )
                manager = cur.fetchone()
                manager_id = manager["id"] if manager else None
            if commercial_id and not data.get("commercial_name"):
                cur.execute("SELECT * FROM users WHERE id = %s", (commercial_id,))
                user = cur.fetchone()
                if user:
                    data["commercial_name"] = " ".join(
                        part for part in [user.get("prenom"), user.get("nom")] if part
                    ).strip() or user.get("email")
                    data["email"] = data.get("email") or user.get("email")
                    data["phone"] = data.get("phone") or user.get("phone")
                    data["city"] = data.get("city") or user.get("city") or user.get("ville")
            row = _insert_existing(
                cur,
                "rapports",
                {
                    "commercial_id": commercial_id,
                    "manager_id": manager_id,
                    "commercial_name": data.get("commercial_name"),
                    "city": data.get("city") or data.get("ville"),
                    "email": data.get("email"),
                    "phone": data.get("phone") or data.get("telephone"),
                    "report_date": data.get("report_date") or data.get("date"),
                    "sent_at": datetime.now(),
                    "summary": data.get("summary") or data.get("resume"),
                    "activities_count": data.get("activities_count") or 0,
                    "clients_count": data.get("clients_count") or 0,
                    "calls": data.get("calls") or 0,
                    "meetings": data.get("meetings") or 0,
                    "tasks": data.get("tasks") or 0,
                    "claims": data.get("claims") or 0,
                    "orders_count": data.get("orders_count") or 0,
                    "revenue": data.get("revenue") or 0,
                    "comments": data.get("comments") or data.get("commentaire"),
                    "created_at": datetime.now(),
                    "is_read": False,
                },
            )
            cur.execute(
                """
                INSERT INTO notifications
                    (manager_id, commercial_id, type, titre, message, is_read, created_at)
                VALUES (%s, %s, %s, %s, %s, false, CURRENT_TIMESTAMP)
                """,
                (
                    manager_id,
                    commercial_id,
                    "rapport_journalier",
                    "Nouveau rapport journalier",
                    f"Rapport journalier envoyé par {row.get('commercial_name') or 'un commercial'}",
                ),
            )
            conn.commit()
            print(
                f"[RAPPORTS][POST] id={row.get('id')} commercial_id={commercial_id} manager_id={manager_id}"
            )
            return jsonify(row), 201

        cur.execute("SELECT * FROM rapports ORDER BY sent_at DESC, id DESC")
        rows = cur.fetchall()
        print(f"[RAPPORTS][GET] count={len(rows)}")
        return jsonify(rows)
    finally:
        cur.close()
        conn.close()


@app.route("/rapports/<int:rapport_id>/read", methods=["PATCH"])
def mark_rapport_read(rapport_id):
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    try:
        _ensure_rapports_table(cur)
        cur.execute(
            "UPDATE rapports SET is_read = true WHERE id = %s RETURNING *",
            (rapport_id,),
        )
        row = cur.fetchone()
        conn.commit()
        if not row:
            return jsonify({"message": "Rapport introuvable"}), 404
        return jsonify(row)
    finally:
        cur.close()
        conn.close()


@app.route("/rapports/<int:rapport_id>/comments", methods=["POST"])
def add_rapport_comment(rapport_id):
    data = request.get_json() or {}
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    try:
        _ensure_rapports_table(cur)
        cur.execute(
            "UPDATE rapports SET manager_comment = %s WHERE id = %s RETURNING *",
            (data.get("comment") or data.get("comments") or "", rapport_id),
        )
        row = cur.fetchone()
        conn.commit()
        if not row:
            return jsonify({"message": "Rapport introuvable"}), 404
        return jsonify(row)
    finally:
        cur.close()
        conn.close()


@app.route("/login", methods=["POST"])
def login():
    data = request.json or {}
    email = (data.get("email") or "").strip().lower()
    password = data.get("password")

    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cur.execute(
        """
        SELECT *
        FROM users
        WHERE LOWER(email) = LOWER(%s) AND COALESCE(is_active, true) = true
        ORDER BY id
        LIMIT 1
        """,
        (email,),
    )
    user = cur.fetchone()
    if user and not _password_matches(user.get("password"), password):
        user = None
    if user and not str(user.get("password") or "").startswith(("pbkdf2:", "scrypt:")):
        cur.execute(
            "UPDATE users SET password = %s WHERE id = %s",
            (_hash_password(password), user["id"]),
        )
        conn.commit()
    cur.close()
    conn.close()
    if user is None:
        return jsonify({"message": "Email ou mot de passe incorrect"}), 401
    user["name"] = " ".join(
        part for part in [user.get("prenom"), user.get("nom")] if part
    ).strip()
    user["password"] = None
    return jsonify(user)


@app.route("/factures", methods=["GET"])
@app.route("/commandes", methods=["GET"])
def get_factures():
    manager_id = request.args.get("manager_id")
    status = request.args.get("status")
    commercial_id = request.args.get("commercial_id")
    commercial_email = request.args.get("commercial_email")
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    rows = _fetch_orders(
        cur,
        manager_id=manager_id,
        status=status,
        commercial_id=commercial_id,
        commercial_email=commercial_email,
    )
    print(
        f"[COMMANDES][GET] manager_id={manager_id} commercial_id={commercial_id} "
        f"commercial_email={commercial_email} status={status} count={len(rows)}"
    )
    cur.close()
    conn.close()
    return jsonify(rows)


@app.route("/manager/commandes", methods=["GET"])
@app.route("/commandes/manager", methods=["GET"])
def get_manager_commandes():
    manager_id = request.args.get("manager_id")
    status = request.args.get("status")
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    rows = _fetch_orders(cur, manager_id=manager_id, status=status)
    print(
        f"[MANAGER][COMMANDES] manager_id={manager_id} status={status} count={len(rows)}"
    )
    cur.close()
    conn.close()
    return jsonify(rows)


@app.route("/factures/<int:order_id>", methods=["GET"])
@app.route("/commandes/<int:order_id>", methods=["GET"])
def get_commande(order_id):
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    order = _fetch_order(cur, order_id)
    cur.close()
    conn.close()
    if not order:
        return jsonify({"message": "Commande introuvable"}), 404
    return jsonify(order)


@app.route("/commandes", methods=["POST"])
@app.route("/factures", methods=["POST"])
def create_commande():
    data = request.json or {}
    lines = data.get("lines") or data.get("details") or []
    status = _normalize_status(data.get("status") or "en_attente")
    client_id = data.get("client_id")
    client_code = data.get("client_code")
    client_name = data.get("client_name")
    commercial_id = data.get("commercial_id") or data.get("user_id") or data.get("created_by")
    commercial_email = data.get("commercial_email") or data.get("email")

    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    try:
        _ensure_notifications_table(cur)
        _ensure_factures_status_constraint(cur)
        if commercial_email:
            cur.execute(
                "SELECT id FROM users WHERE email = %s ORDER BY id LIMIT 1",
                (commercial_email,),
            )
            commercial = cur.fetchone()
            if commercial:
                commercial_id = commercial["id"]
        if client_code:
            cur.execute(
                "SELECT id FROM clients WHERE client_code = %s ORDER BY id LIMIT 1",
                (client_code,),
            )
            client = cur.fetchone()
            if client:
                client_id = client["id"]
        if client_name and not client_id:
            cur.execute(
                "SELECT id FROM clients WHERE LOWER(name) = LOWER(%s) ORDER BY id LIMIT 1",
                (client_name,),
            )
            client = cur.fetchone()
            if client:
                client_id = client["id"]
        manager_id = data.get("manager_id")
        if not manager_id:
            cur.execute(
                "SELECT id FROM users WHERE role ILIKE '%%manager%%' AND COALESCE(is_active, true)=true ORDER BY id LIMIT 1"
            )
            manager = cur.fetchone()
            manager_id = manager["id"] if manager else None
        order = _insert_existing(
            cur,
            "factures",
            {
                "client_id": client_id,
                "id_client": client_id,
                "commercial_id": commercial_id,
                "id_commercial": commercial_id,
                "user_id": commercial_id,
                "created_by": commercial_id,
                "manager_id": manager_id,
                "order_number": data.get("order_number"),
                "numero_facture": data.get("order_number"),
                "numero": data.get("order_number"),
                "reference": data.get("reference") or data.get("order_number"),
                "date": data.get("date") or datetime.utcnow(),
                "date_facture": data.get("date") or datetime.utcnow(),
                "created_at": data.get("created_at") or datetime.utcnow(),
                "updated_at": datetime.utcnow(),
                "delivery_date": data.get("delivery_date"),
                "date_livraison": data.get("delivery_date"),
                "status": status,
                "statut": status,
                "total": data.get("total") or 0,
                "montant_total": data.get("total") or 0,
                "notes": data.get("notes") or data.get("commentaire"),
                "commentaire": data.get("notes") or data.get("commentaire"),
            },
        )
        order_id = order["id"]
        produit_cols = _columns(cur, "produits")
        product_ref_col = _first_existing(produit_cols, ["reference", "ref", "code"], None)
        product_name_col = _first_existing(produit_cols, ["name", "nom_produit", "designation"], None)
        for line in lines:
            product_id = line.get("product_id") or line.get("produit_id") or line.get("id_prod")
            product_reference = line.get("product_reference") or line.get("reference")
            product_name = line.get("product_name") or line.get("name")
            if product_reference and product_ref_col:
                cur.execute(
                    f"SELECT id FROM produits WHERE {product_ref_col} = %s ORDER BY id LIMIT 1",
                    (product_reference,),
                )
                product = cur.fetchone()
                if product:
                    product_id = product["id"]
            if product_name and product_name_col and not product_id:
                cur.execute(
                    f"SELECT id FROM produits WHERE LOWER({product_name_col}) = LOWER(%s) ORDER BY id LIMIT 1",
                    (product_name,),
                )
                product = cur.fetchone()
                if product:
                    product_id = product["id"]
            quantity = line.get("quantity") or line.get("qte") or line.get("quantite") or 0
            unit_price = line.get("unit_price") or line.get("prix_vendu") or line.get("prix_unitaire") or 0
            _insert_existing(
                cur,
                "details_facture",
                {
                    "facture_id": order_id,
                    "id_fact": order_id,
                    "produit_id": product_id,
                    "id_prod": product_id,
                    "product_id": product_id,
                    "qte": quantity,
                    "quantite": quantity,
                    "quantity": quantity,
                    "prix_vendu": unit_price,
                    "prix_unitaire": unit_price,
                    "unit_price": unit_price,
                    "total": line.get("total") or (float(quantity) * float(unit_price)),
                    "line_total": line.get("total") or (float(quantity) * float(unit_price)),
                },
            )

        cur.execute(
            """
            INSERT INTO notifications
                (manager_id, commercial_id, commande_id, type, titre, message, is_read, created_at)
            VALUES (%s, %s, %s, %s, %s, %s, false, CURRENT_TIMESTAMP)
            """,
            (
                manager_id,
                commercial_id,
                order_id,
                "nouvelle_commande",
                "Nouvelle commande en attente",
                f"Nouvelle commande créée par {data.get('commercial_name') or 'un commercial'}",
            ),
        )
        _log_recent_activity(
            cur,
            "commande_creee",
            "Commande créée",
            f"{order.get('order_number') or order.get('numero_facture') or order.get('numero') or f'CMD-{order_id}'} • {data.get('total') or 0} DH",
            commercial_id=commercial_id,
            commande_id=order_id,
            client_id=client_id,
        )
        _log_recent_activity(
            cur,
            "commande_envoyee_manager",
            "Commande envoyée au manager",
            f"{order.get('order_number') or order.get('numero_facture') or order.get('numero') or f'CMD-{order_id}'} • En attente",
            commercial_id=commercial_id,
            commande_id=order_id,
            client_id=client_id,
        )
        _sync_commercial_business_status(cur, commercial_id)
        conn.commit()
        print(
            f"[COMMANDES][POST] inserted order_id={order_id} status={status} "
            f"commercial_id={commercial_id} manager_id={manager_id} lines={len(lines)}"
        )
        created = _fetch_order(cur, order_id)
        return jsonify(created), 201
    except Exception as exc:
        conn.rollback()
        print(f"[COMMANDES][ERROR] {exc}")
        return jsonify({"message": "Erreur création commande", "error": str(exc)}), 500
    finally:
        cur.close()
        conn.close()


@app.route("/commandes/<int:order_id>", methods=["PATCH"])
@app.route("/factures/<int:order_id>/status", methods=["PATCH"])
def update_commande_status(order_id):
    data = request.json or {}
    status = _normalize_status(data.get("status"))
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    try:
        _ensure_factures_status_constraint(cur)
        cols = _columns(cur, "factures")
        values = []
        assignments = []
        for col in ("status", "statut"):
            if col in cols:
                assignments.append(f"{col} = %s")
                values.append(status)
        if "refusal_reason" in cols and data.get("refusal_reason"):
            assignments.append("refusal_reason = %s")
            values.append(data.get("refusal_reason"))
        if "manager_id" in cols and data.get("manager_id"):
            assignments.append("manager_id = %s")
            values.append(data.get("manager_id"))
        if "updated_at" in cols:
            assignments.append("updated_at = CURRENT_TIMESTAMP")
        if not assignments:
            return jsonify({"message": "Aucune colonne statut trouvée"}), 500
        values.append(order_id)
        cur.execute(
            f"UPDATE factures SET {', '.join(assignments)} WHERE id = %s RETURNING *",
            values,
        )
        order = cur.fetchone()
        if not order:
            return jsonify({"message": "Commande introuvable"}), 404
        commercial_id = (
            order.get("commercial_id")
            or order.get("id_commercial")
            or order.get("user_id")
            or order.get("created_by")
        )
        client_id = order.get("client_id") or order.get("id_client")
        order_number = (
            order.get("order_number")
            or order.get("numero_facture")
            or order.get("numero")
            or f"CMD-{order_id}"
        )
        if status == "validee":
            _log_recent_activity(
                cur,
                "commande_validee_manager",
                "Commande validée par le manager",
                f"{order_number} • Validée",
                commercial_id=commercial_id,
                commande_id=order_id,
                client_id=client_id,
            )
        elif status == "refusee":
            _log_recent_activity(
                cur,
                "commande_refusee_manager",
                "Commande refusée par le manager",
                f"{order_number} • Refusée",
                commercial_id=commercial_id,
                commande_id=order_id,
                client_id=client_id,
            )
        conn.commit()
        print(
            f"[COMMANDES][PATCH] order_id={order_id} status={status} "
            f"manager_id={data.get('manager_id')}"
        )
        return jsonify(order)
    except Exception as exc:
        conn.rollback()
        return jsonify({"message": "Erreur mise à jour statut", "error": str(exc)}), 500
    finally:
        cur.close()
        conn.close()


@app.route("/notifications", methods=["GET"])
def get_notifications():
    manager_id = request.args.get("manager_id")
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    _ensure_notifications_table(cur)
    if manager_id:
        cur.execute(
            """
            SELECT *
            FROM notifications
            WHERE manager_id = %s OR manager_id IS NULL OR type = 'nouvelle_commande'
            ORDER BY created_at DESC
            """,
            (manager_id,),
        )
    else:
        cur.execute("SELECT * FROM notifications ORDER BY created_at DESC")
    rows = cur.fetchall()
    print(f"[MANAGER][NOTIFICATIONS] manager_id={manager_id} count={len(rows)}")
    conn.commit()
    cur.close()
    conn.close()
    return jsonify(rows)


@app.route("/notifications/<int:notification_id>/read", methods=["PATCH"])
def mark_notification_read(notification_id):
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    try:
        _ensure_notifications_table(cur)
        cur.execute(
            "UPDATE notifications SET is_read = true WHERE id = %s RETURNING *",
            (notification_id,),
        )
        row = cur.fetchone()
        conn.commit()
        if not row:
            return jsonify({"message": "Notification introuvable"}), 404
        return jsonify(row)
    finally:
        cur.close()
        conn.close()


@app.route("/notifications/read-all", methods=["PATCH"])
def mark_all_notifications_read():
    manager_id = request.args.get("manager_id")
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    try:
        _ensure_notifications_table(cur)
        if manager_id:
            cur.execute(
                "UPDATE notifications SET is_read = true WHERE manager_id = %s OR manager_id IS NULL RETURNING *",
                (manager_id,),
            )
        else:
            cur.execute("UPDATE notifications SET is_read = true RETURNING *")
        rows = cur.fetchall()
        conn.commit()
        return jsonify(rows)
    finally:
        cur.close()
        conn.close()


@app.route("/notifications/<int:notification_id>", methods=["DELETE"])
def delete_notification(notification_id):
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    try:
        _ensure_notifications_table(cur)
        cur.execute(
            "DELETE FROM notifications WHERE id = %s RETURNING *",
            (notification_id,),
        )
        row = cur.fetchone()
        conn.commit()
        if not row:
            return jsonify({"message": "Notification introuvable"}), 404
        return jsonify(row)
    finally:
        cur.close()
        conn.close()


if __name__ == "__main__":
    app.run(debug=True, port=5000)
