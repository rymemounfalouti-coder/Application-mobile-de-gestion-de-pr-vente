from datetime import datetime

from flask import Flask, request, jsonify
from flask_cors import CORS
import psycopg2
import psycopg2.extras

app = Flask(__name__)
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


def _ensure_factures_status_constraint(cur):
    cur.execute("ALTER TABLE factures DROP CONSTRAINT IF EXISTS factures_status_check")
    cur.execute(
        """
        ALTER TABLE factures
        ADD CONSTRAINT factures_status_check
        CHECK (
            status IS NULL OR status IN (
                'en_attente',
                'validee',
                'refusee',
                'pending',
                'synced',
                'delivered',
                'cancelled'
            )
        )
        """
    )


def _normalize_status(status):
    value = (status or "en_attente").strip().lower()
    mapping = {
        "en attente": "en_attente",
        "pending": "en_attente",
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


@app.route("/")
def home():
    return jsonify({"message": "Backend Flask fonctionne"})


@app.route("/clients", methods=["GET"])
def get_clients():
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cur.execute("SELECT * FROM clients ORDER BY id")
    clients = cur.fetchall()
    cur.close()
    conn.close()
    return jsonify(clients)


@app.route("/produits", methods=["GET"])
def get_produits():
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cur.execute(
        """
        SELECT p.*, c.nom_cat
        FROM produits p
        LEFT JOIN categories c ON p.id_cat = c.id
        ORDER BY p.id
        """
    )
    produits = cur.fetchall()
    cur.close()
    conn.close()
    return jsonify(produits)


@app.route("/users", methods=["GET"])
def get_users():
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cur.execute("SELECT * FROM users ORDER BY id")
    users = cur.fetchall()
    cur.close()
    conn.close()
    return jsonify(users)


@app.route("/login", methods=["POST"])
def login():
    data = request.json or {}
    email = data.get("email")
    password = data.get("password")

    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cur.execute(
        """
        SELECT id, nom, prenom, email, phone, role, is_active
        FROM users
        WHERE email = %s AND password = %s AND is_active = true
        """,
        (email, password),
    )
    user = cur.fetchone()
    cur.close()
    conn.close()
    if user is None:
        return jsonify({"message": "Email ou mot de passe incorrect"}), 401
    user["name"] = " ".join(
        part for part in [user.get("prenom"), user.get("nom")] if part
    ).strip()
    return jsonify(user)


@app.route("/factures", methods=["GET"])
@app.route("/commandes", methods=["GET"])
def get_factures():
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    facture_cols = _columns(cur, "factures")
    client_fk = _first_existing(facture_cols, ["client_id", "id_client"])
    commercial_fk = _first_existing(
        facture_cols, ["commercial_id", "id_commercial", "user_id", "created_by"]
    )
    date_expr = _first_existing(facture_cols, ["created_at", "date", "date_facture"], "id")
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
        ORDER BY f.{date_expr} DESC NULLS LAST, f.id DESC
        """
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
    commercial_id = data.get("commercial_id") or data.get("user_id") or data.get("created_by")

    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    try:
        _ensure_notifications_table(cur)
        _ensure_factures_status_constraint(cur)
        order = _insert_existing(
            cur,
            "factures",
            {
                "client_id": data.get("client_id"),
                "id_client": data.get("client_id"),
                "commercial_id": commercial_id,
                "id_commercial": commercial_id,
                "user_id": commercial_id,
                "created_by": commercial_id,
                "manager_id": data.get("manager_id"),
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
        for line in lines:
            product_id = line.get("product_id") or line.get("produit_id") or line.get("id_prod")
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

        manager_id = data.get("manager_id")
        if not manager_id:
            cur.execute(
                "SELECT id FROM users WHERE role ILIKE '%%manager%%' AND COALESCE(is_active, true)=true ORDER BY id LIMIT 1"
            )
            manager = cur.fetchone()
            manager_id = manager["id"] if manager else None
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
        conn.commit()
        print(f"[COMMANDES] inserted order_id={order_id} status={status} commercial_id={commercial_id}")
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
        conn.commit()
        if not order:
            return jsonify({"message": "Commande introuvable"}), 404
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
            "SELECT * FROM notifications WHERE manager_id = %s ORDER BY created_at DESC",
            (manager_id,),
        )
    else:
        cur.execute("SELECT * FROM notifications ORDER BY created_at DESC")
    rows = cur.fetchall()
    conn.commit()
    cur.close()
    conn.close()
    return jsonify(rows)


if __name__ == "__main__":
    app.run(debug=True, port=5000)
