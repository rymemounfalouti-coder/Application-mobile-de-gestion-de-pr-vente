--
-- PostgreSQL database dump
--

-- Dumped from database version 16.8
-- Dumped by pg_dump version 16.8

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

ALTER TABLE IF EXISTS ONLY public.produits DROP CONSTRAINT IF EXISTS produits_id_cat_fkey;
ALTER TABLE IF EXISTS ONLY public.notifications DROP CONSTRAINT IF EXISTS notifications_commande_id_fkey;
ALTER TABLE IF EXISTS ONLY public.notifications DROP CONSTRAINT IF EXISTS notifications_client_id_fkey;
ALTER TABLE IF EXISTS ONLY public.factures DROP CONSTRAINT IF EXISTS factures_manager_id_fkey;
ALTER TABLE IF EXISTS ONLY public.factures DROP CONSTRAINT IF EXISTS factures_id_client_fkey;
ALTER TABLE IF EXISTS ONLY public.factures DROP CONSTRAINT IF EXISTS factures_commercial_id_fkey;
ALTER TABLE IF EXISTS ONLY public.details_facture DROP CONSTRAINT IF EXISTS details_facture_produit_id_fkey;
ALTER TABLE IF EXISTS ONLY public.details_facture DROP CONSTRAINT IF EXISTS details_facture_facture_id_fkey;
ALTER TABLE IF EXISTS ONLY public.clients DROP CONSTRAINT IF EXISTS clients_commercial_id_fkey;
ALTER TABLE IF EXISTS ONLY public.activites_recentes DROP CONSTRAINT IF EXISTS activites_recentes_commande_id_fkey;
ALTER TABLE IF EXISTS ONLY public.activites_recentes DROP CONSTRAINT IF EXISTS activites_recentes_client_id_fkey;
ALTER TABLE IF EXISTS ONLY public.users DROP CONSTRAINT IF EXISTS users_pkey;
ALTER TABLE IF EXISTS ONLY public.users DROP CONSTRAINT IF EXISTS users_email_key;
ALTER TABLE IF EXISTS ONLY public.user_preferences DROP CONSTRAINT IF EXISTS user_preferences_pkey;
ALTER TABLE IF EXISTS ONLY public.rapports DROP CONSTRAINT IF EXISTS rapports_pkey;
ALTER TABLE IF EXISTS ONLY public.produits DROP CONSTRAINT IF EXISTS produits_pkey;
ALTER TABLE IF EXISTS ONLY public.notifications DROP CONSTRAINT IF EXISTS notifications_pkey;
ALTER TABLE IF EXISTS ONLY public.factures DROP CONSTRAINT IF EXISTS factures_pkey;
ALTER TABLE IF EXISTS ONLY public.details_facture DROP CONSTRAINT IF EXISTS details_facture_pkey;
ALTER TABLE IF EXISTS ONLY public.company_info DROP CONSTRAINT IF EXISTS company_info_pkey;
ALTER TABLE IF EXISTS ONLY public.clients DROP CONSTRAINT IF EXISTS clients_pkey;
ALTER TABLE IF EXISTS ONLY public.categories DROP CONSTRAINT IF EXISTS categories_pkey;
ALTER TABLE IF EXISTS ONLY public.activites_recentes DROP CONSTRAINT IF EXISTS activites_recentes_pkey;
ALTER TABLE IF EXISTS public.users ALTER COLUMN id DROP DEFAULT;
ALTER TABLE IF EXISTS public.rapports ALTER COLUMN id DROP DEFAULT;
ALTER TABLE IF EXISTS public.produits ALTER COLUMN id DROP DEFAULT;
ALTER TABLE IF EXISTS public.notifications ALTER COLUMN id DROP DEFAULT;
ALTER TABLE IF EXISTS public.factures ALTER COLUMN id DROP DEFAULT;
ALTER TABLE IF EXISTS public.details_facture ALTER COLUMN id DROP DEFAULT;
ALTER TABLE IF EXISTS public.clients ALTER COLUMN id DROP DEFAULT;
ALTER TABLE IF EXISTS public.categories ALTER COLUMN id DROP DEFAULT;
ALTER TABLE IF EXISTS public.activites_recentes ALTER COLUMN id DROP DEFAULT;
DROP SEQUENCE IF EXISTS public.users_id_seq;
DROP TABLE IF EXISTS public.users;
DROP TABLE IF EXISTS public.user_preferences;
DROP SEQUENCE IF EXISTS public.rapports_id_seq;
DROP TABLE IF EXISTS public.rapports;
DROP SEQUENCE IF EXISTS public.produits_id_seq;
DROP TABLE IF EXISTS public.produits;
DROP SEQUENCE IF EXISTS public.notifications_id_seq;
DROP TABLE IF EXISTS public.notifications;
DROP SEQUENCE IF EXISTS public.factures_id_seq;
DROP TABLE IF EXISTS public.factures;
DROP SEQUENCE IF EXISTS public.details_facture_id_seq;
DROP TABLE IF EXISTS public.details_facture;
DROP TABLE IF EXISTS public.company_info;
DROP SEQUENCE IF EXISTS public.clients_id_seq;
DROP TABLE IF EXISTS public.clients;
DROP SEQUENCE IF EXISTS public.categories_id_seq;
DROP TABLE IF EXISTS public.categories;
DROP SEQUENCE IF EXISTS public.activites_recentes_id_seq;
DROP TABLE IF EXISTS public.activites_recentes;
SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: activites_recentes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.activites_recentes (
    id integer NOT NULL,
    type_action character varying(80) NOT NULL,
    titre character varying(180) NOT NULL,
    description text,
    commercial_id integer,
    commande_id integer,
    client_id integer,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: activites_recentes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.activites_recentes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: activites_recentes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.activites_recentes_id_seq OWNED BY public.activites_recentes.id;


--
-- Name: categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.categories (
    id integer NOT NULL,
    nom_cat text,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now()
);


--
-- Name: categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.categories_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.categories_id_seq OWNED BY public.categories.id;


--
-- Name: clients; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.clients (
    id integer NOT NULL,
    name text,
    client_code text,
    phone text,
    city text,
    address text,
    business_type text,
    status text,
    last_order_date text,
    commercial_id integer,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now(),
    category text
);


--
-- Name: clients_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.clients_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: clients_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.clients_id_seq OWNED BY public.clients.id;


--
-- Name: company_info; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.company_info (
    id integer DEFAULT 1 NOT NULL,
    name character varying(180) DEFAULT 'Ryme Distribution'::character varying NOT NULL,
    logo text,
    address text,
    phone character varying(80),
    email character varying(180),
    website character varying(180),
    currency character varying(20) DEFAULT 'DH'::character varying,
    tax_info text,
    legal_info text,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: details_facture; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.details_facture (
    id integer NOT NULL,
    facture_id integer,
    produit_id integer,
    quantite integer DEFAULT 1,
    prix_unitaire numeric,
    total numeric
);


--
-- Name: details_facture_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.details_facture_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: details_facture_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.details_facture_id_seq OWNED BY public.details_facture.id;


--
-- Name: factures; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.factures (
    id integer NOT NULL,
    id_client integer,
    commercial_id integer,
    manager_id integer,
    status text DEFAULT 'en_attente'::text,
    total numeric DEFAULT 0,
    date_facture timestamp without time zone DEFAULT now(),
    order_number text,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now(),
    refusal_reason text,
    CONSTRAINT factures_status_check CHECK (((status IS NULL) OR (status = ANY (ARRAY['en_attente'::text, 'validee'::text, 'refusee'::text]))))
);


--
-- Name: factures_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.factures_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: factures_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.factures_id_seq OWNED BY public.factures.id;


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notifications (
    id integer NOT NULL,
    manager_id integer,
    commercial_id integer,
    commande_id integer,
    type character varying(80) NOT NULL,
    titre character varying(180) NOT NULL,
    message text,
    is_read boolean DEFAULT false,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    description text,
    client_id integer,
    objectif_id integer,
    user_id integer
);


--
-- Name: notifications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.notifications_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.notifications_id_seq OWNED BY public.notifications.id;


--
-- Name: produits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.produits (
    id integer NOT NULL,
    nom_produit text,
    name text,
    reference text,
    ref text,
    code text,
    description text,
    categorie text,
    category text,
    id_cat integer,
    prix numeric,
    price numeric,
    prix_vente numeric,
    unit_price numeric,
    stock integer,
    quantite_stock integer,
    status text,
    statut text,
    image text,
    photo text,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now()
);


--
-- Name: produits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.produits_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: produits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.produits_id_seq OWNED BY public.produits.id;


--
-- Name: rapports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rapports (
    id integer NOT NULL,
    commercial_id integer,
    manager_id integer,
    commercial_name character varying(180),
    city character varying(120),
    email character varying(180),
    phone character varying(80),
    report_date date,
    sent_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    summary text,
    activities_count integer DEFAULT 0,
    clients_count integer DEFAULT 0,
    calls integer DEFAULT 0,
    meetings integer DEFAULT 0,
    tasks integer DEFAULT 0,
    claims integer DEFAULT 0,
    orders_count integer DEFAULT 0,
    revenue numeric(12,2) DEFAULT 0,
    comments text,
    manager_comment text,
    is_read boolean DEFAULT false,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: rapports_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.rapports_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rapports_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.rapports_id_seq OWNED BY public.rapports.id;


--
-- Name: user_preferences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_preferences (
    user_id integer NOT NULL,
    preferences jsonb DEFAULT '{}'::jsonb NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id integer NOT NULL,
    email text NOT NULL,
    password text,
    prenom text,
    nom text,
    phone text,
    telephone text,
    role text DEFAULT 'commercial'::text,
    is_active boolean DEFAULT true,
    status text,
    statut text,
    etat text,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now()
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: activites_recentes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activites_recentes ALTER COLUMN id SET DEFAULT nextval('public.activites_recentes_id_seq'::regclass);


--
-- Name: categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories ALTER COLUMN id SET DEFAULT nextval('public.categories_id_seq'::regclass);


--
-- Name: clients id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clients ALTER COLUMN id SET DEFAULT nextval('public.clients_id_seq'::regclass);


--
-- Name: details_facture id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.details_facture ALTER COLUMN id SET DEFAULT nextval('public.details_facture_id_seq'::regclass);


--
-- Name: factures id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.factures ALTER COLUMN id SET DEFAULT nextval('public.factures_id_seq'::regclass);


--
-- Name: notifications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications ALTER COLUMN id SET DEFAULT nextval('public.notifications_id_seq'::regclass);


--
-- Name: produits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.produits ALTER COLUMN id SET DEFAULT nextval('public.produits_id_seq'::regclass);


--
-- Name: rapports id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rapports ALTER COLUMN id SET DEFAULT nextval('public.rapports_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Data for Name: activites_recentes; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.activites_recentes (id, type_action, titre, description, commercial_id, commande_id, client_id, created_at) FROM stdin;
1	nouveau_client	Nouveau client ajouté	Ryme Distribution • Paris	3	\N	1	2026-07-15 21:36:46.258315
2	commande_creee	Commande créée	CMD-2026-4854 • 10450 DH	3	1	1	2026-07-15 21:40:15.32144
3	commande_envoyee_manager	Commande envoyée au manager	CMD-2026-4854 • En attente	3	1	1	2026-07-15 21:40:15.32543
4	activite_creee	Réunion	Ryme Distribution • La Défense, Paris	3	\N	1	2026-07-16 00:32:21.017133
5	visite_demarree	Visite démarrée	Ryme Distribution • La Défense, Paris	3	\N	1	2026-07-16 00:32:31.331643
6	visite_terminee	Visite terminée	Ryme Distribution • La Défense, Paris	3	\N	1	2026-07-16 00:32:44.963455
7	visite_compte_rendu	Compte rendu de visite ajouté	Ryme Distribution • cava	3	\N	1	2026-07-16 00:32:57.425678
8	commande_refusee_manager	Commande refusée par le manager	CMD-2026-4854 • Refusée	3	1	1	2026-07-16 00:35:00.774496
9	commande_creee	Commande créée	CMD-2026-1148 • 5000.0 DH	3	2	1	2026-07-16 01:59:29.272702
10	commande_envoyee_manager	Commande envoyée au manager	CMD-2026-1148 • En attente	3	2	1	2026-07-16 01:59:29.275992
18	nouveau_client	Nouveau client ajouté	Test Client • Casablanca	3	\N	9	2026-07-20 01:40:37.494522
19	commande_creee	Commande créée	CMD-2026-6357 • 110.0 DH	3	3	1	2026-07-20 02:15:51.469481
20	commande_envoyee_manager	Commande envoyée au manager	CMD-2026-6357 • En attente	3	3	1	2026-07-20 02:15:51.47348
21	commande_validee_manager	Commande validée par le manager	CMD-2026-6357 • Validée	3	3	1	2026-07-20 02:16:29.936767
22	rapport_journalier	Rapport journalier envoyé	Lundi 20 Juillet 2026 • 1 commandes	3	\N	\N	2026-07-20 02:17:22.484829
23	commande_validee_manager	Commande validée par le manager	CMD-2026-1148 • Validée	3	2	1	2026-07-20 02:19:40.076295
24	nouveau_client	Nouveau client ajouté	Marjane • Casablanca	13	\N	10	2026-07-20 02:37:15.857883
25	commande_creee	Commande créée	CMD-2026-0484 • 411.28 DH	13	4	10	2026-07-20 02:37:52.811078
26	commande_envoyee_manager	Commande envoyée au manager	CMD-2026-0484 • En attente	13	4	10	2026-07-20 02:37:52.815106
27	activite_creee	Visite client	Marjane • Test, Casablanca	13	\N	10	2026-07-20 02:38:30.890921
28	visite_demarree	Visite démarrée	Marjane • Test, Casablanca	13	\N	10	2026-07-20 02:38:40.384798
29	visite_terminee	Visite terminée	Marjane • Test, Casablanca	13	\N	10	2026-07-20 02:38:44.506953
30	rapport_journalier	Rapport journalier envoyé	Lundi 20 Juillet 2026 • 0 commandes	13	\N	\N	2026-07-20 02:39:02.722148
31	nouveau_client	Nouveau client ajouté	Carrefour • Casablanca	13	\N	11	2026-07-20 02:57:32.541769
32	nouveau_client	Nouveau client ajouté	BIM • Casablanca	13	\N	12	2026-07-20 03:00:20.291377
33	commande_creee	Commande créée	CMD-2026-1294 • 380.24 DH	13	5	12	2026-07-20 03:00:57.781981
34	commande_envoyee_manager	Commande envoyée au manager	CMD-2026-1294 • En attente	13	5	12	2026-07-20 03:00:57.785979
35	activite_creee	Visite client	BIM • test, Casablanca	13	\N	12	2026-07-20 03:01:23.253108
36	visite_demarree	Visite démarrée	BIM • test, Casablanca	13	\N	12	2026-07-20 03:01:32.774731
37	visite_terminee	Visite terminée	BIM • test, Casablanca	13	\N	12	2026-07-20 03:01:35.88823
38	rapport_journalier	Rapport journalier envoyé	Lundi 20 Juillet 2026 • 0 commandes	13	\N	\N	2026-07-20 03:01:57.554089
\.


--
-- Data for Name: categories; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.categories (id, nom_cat, created_at, updated_at) FROM stdin;
2	Thé vert en filaments	2026-07-16 11:16:37.909056	2026-07-16 11:16:37.909056
1	Thé vert en grains Gunpowder	2026-07-16 11:16:37.909056	2026-07-16 11:16:37.909056
\.


--
-- Data for Name: clients; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.clients (id, name, client_code, phone, city, address, business_type, status, last_order_date, commercial_id, created_at, updated_at, category) FROM stdin;
1	Ryme Distribution	CL-20260715213646	0767166610	Paris	La Défense	Restaurant	toVisit	Nouveau	3	2026-07-15 21:36:46.160078	2026-07-19 16:29:49.088644	Prospect
9	Test Client	CL-20260720014037	060606060606	Casablanca	casablanca	Épicerie	toVisit	Nouveau	3	2026-07-20 01:40:37.446747	2026-07-20 01:52:29.472526	test
10	Marjane	CL1784511434567	0606060606	Casablanca	Test	Supermarchés & Grandes Surfaces	visited	Nouveau	13	2026-07-20 02:37:15.819271	2026-07-20 02:37:29.380379	Supermarchés & Grandes Surfaces
11	Carrefour	CL1784512651165	0610101010	Casablanca	test	Supermarchés & Grandes Surfaces	visited	Nouveau	13	2026-07-20 02:57:32.505676	2026-07-20 02:57:45.646121	Supermarchés & Grandes Surfaces
12	BIM	CL1784512819025	0610101010	Casablanca	test	Supermarchés & Grandes Surfaces	visited	Nouveau	13	2026-07-20 03:00:20.24378	2026-07-20 03:00:38.493631	Supermarchés & Grandes Surfaces
\.


--
-- Data for Name: company_info; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.company_info (id, name, logo, address, phone, email, website, currency, tax_info, legal_info, updated_at) FROM stdin;
1	Ryme Distribution	\N	Casablanca, Maroc	0522 00 00 00	contact@ryme.ma		DH			2026-07-15 21:19:42.786721
\.


--
-- Data for Name: details_facture; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.details_facture (id, facture_id, produit_id, quantite, prix_unitaire, total) FROM stdin;
1	1	1	11	950	10450
2	2	1	5	1000.0	5000.0
3	3	2	5	22.0	110.0
4	4	2	7	21.34	149.38
5	4	3	10	26.189999999999998	261.9
6	5	2	8	21.34	170.72
7	5	3	8	26.189999999999998	209.51999999999998
\.


--
-- Data for Name: factures; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.factures (id, id_client, commercial_id, manager_id, status, total, date_facture, order_number, created_at, updated_at, refusal_reason) FROM stdin;
1	1	3	2	refusee	10450	2026-07-15 21:39:54.854	CMD-2026-4854	2026-07-15 21:40:15.211	2026-07-16 00:35:00.710715	Prix incorrect
3	1	3	2	validee	110.0	2026-07-20 02:15:36.357534	CMD-2026-6357	2026-07-20 02:15:50.0786	2026-07-20 02:16:29.901386	\N
2	1	3	2	validee	5000.0	2026-07-16 01:57:51.148199	CMD-2026-1148	2026-07-16 01:59:28.527742	2026-07-20 02:19:40.029797	\N
4	10	13	2	en_attente	411.28	2026-07-20 02:37:30.484837	CMD-2026-0484	2026-07-20 02:37:51.338712	2026-07-20 01:37:52.789687	\N
5	12	13	2	en_attente	380.24	2026-07-20 03:00:41.294814	CMD-2026-1294	2026-07-20 03:00:56.406127	2026-07-20 02:00:57.764773	\N
\.


--
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.notifications (id, manager_id, commercial_id, commande_id, type, titre, message, is_read, created_at, description, client_id, objectif_id, user_id) FROM stdin;
1	2	3	\N	clients	Nouveau client ajouté	Ryme Distribution • Paris	t	2026-07-15 21:36:46.248786	Ryme Distribution • Paris	1	\N	\N
2	2	3	1	nouvelle_commande	Nouvelle commande en attente	Nouvelle commande créée par Ilyass Commercial	t	2026-07-15 21:40:15.275429	\N	\N	\N	\N
3	2	3	1	demande_annulation	Demande d'annulation de commande	Le commercial demande l'annulation de CMD-2026-4854	t	2026-07-16 00:33:18.321135	\N	\N	\N	\N
4	2	3	2	nouvelle_commande	Nouvelle commande en attente	Nouvelle commande créée par Ilyass Commercial	t	2026-07-16 01:59:29.168367	\N	\N	\N	\N
12	2	3	\N	clients	Nouveau client ajouté	Test Client • Casablanca	t	2026-07-20 01:40:37.484881	Test Client • Casablanca	9	\N	\N
13	2	3	3	nouvelle_commande	Nouvelle commande en attente	Nouvelle commande créée par Ryme Mnf	f	2026-07-20 02:15:51.412231	\N	\N	\N	\N
14	2	3	\N	rapport_journalier	Nouveau rapport journalier	Rapport journalier envoyé par Ryme Mnf	f	2026-07-20 02:17:21.512995	\N	\N	\N	\N
15	2	13	\N	clients	Nouveau client ajouté	Marjane • Casablanca	f	2026-07-20 02:37:15.850353	Marjane • Casablanca	10	\N	\N
16	2	13	4	nouvelle_commande	Nouvelle commande en attente	Nouvelle commande créée par Sara Ramzi	f	2026-07-20 02:37:52.752321	\N	\N	\N	\N
17	2	13	\N	rapport_journalier	Nouveau rapport journalier	Rapport journalier envoyé par Sara Ramzi	f	2026-07-20 02:39:01.751643	\N	\N	\N	\N
18	2	13	\N	clients	Nouveau client ajouté	Carrefour • Casablanca	f	2026-07-20 02:57:32.532242	Carrefour • Casablanca	11	\N	\N
19	2	13	\N	clients	Nouveau client ajouté	BIM • Casablanca	f	2026-07-20 03:00:20.282655	BIM • Casablanca	12	\N	\N
20	2	13	5	nouvelle_commande	Nouvelle commande en attente	Nouvelle commande créée par Sara Ramzi	f	2026-07-20 03:00:57.734045	\N	\N	\N	\N
21	2	13	\N	rapport_journalier	Nouveau rapport journalier	Rapport journalier envoyé par Sara Ramzi	f	2026-07-20 03:01:56.608327	\N	\N	\N	\N
\.


--
-- Data for Name: produits; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.produits (id, nom_produit, name, reference, ref, code, description, categorie, category, id_cat, prix, price, prix_vente, unit_price, stock, quantite_stock, status, statut, image, photo, created_at, updated_at) FROM stdin;
1	Test	Test	Test	Test	Test	Test	Thé Vert Premium	Thé Vert Premium	\N	1000	1000	1000	1000	1000	1000	actif	actif			2026-07-15 21:32:34.550021	2026-07-15 21:32:34.550021
2	Assil Chaara Premium 200g	Assil Chaara Premium 200g	41022-200	41022-200	41022-200	200g	Thé vert en filaments	Thé vert en filaments	2	22	22	22	22	120	120	actif	actif	assets/images/products/chaara_premium_200g.jpeg	assets/images/products/chaara_premium_200g.jpeg	2026-07-16 11:16:37.909056	2026-07-16 11:16:37.909056
3	Assil Chaara Premium 250g	Assil Chaara Premium 250g	41022-250	41022-250	41022-250	250g	Thé vert en filaments	Thé vert en filaments	2	27	27	27	27	100	100	actif	actif	assets/images/products/chaara_premium_250g.jpeg	assets/images/products/chaara_premium_250g.jpeg	2026-07-16 11:16:37.909056	2026-07-16 11:16:37.909056
4	Assil Chaara Premium 500g	Assil Chaara Premium 500g	41022-500	41022-500	41022-500	500g	Thé vert en filaments	Thé vert en filaments	2	52	52	52	52	90	90	actif	actif	assets/images/products/chaara_premium_500g.jpeg	assets/images/products/chaara_premium_500g.jpeg	2026-07-16 11:16:37.909056	2026-07-16 11:16:37.909056
5	Assil Chaara Premium 1kg	Assil Chaara Premium 1kg	41022-1000	41022-1000	41022-1000	1kg	Thé vert en filaments	Thé vert en filaments	2	98	98	98	98	70	70	actif	actif	assets/images/products/chaara_premium_1kg.jpeg	assets/images/products/chaara_premium_1kg.jpeg	2026-07-16 11:16:37.909056	2026-07-16 11:16:37.909056
6	Assil Chaara Premium 2kg	Assil Chaara Premium 2kg	41022-2000	41022-2000	41022-2000	2kg	Thé vert en filaments	Thé vert en filaments	2	185	185	185	185	50	50	actif	actif	assets/images/products/chaara_premium_2kg.jpeg	assets/images/products/chaara_premium_2kg.jpeg	2026-07-16 11:16:37.909056	2026-07-16 11:16:37.909056
7	Assil Chaara Classique 200g	Assil Chaara Classique 200g	9305-200	9305-200	9305-200	200g	Thé vert en filaments	Thé vert en filaments	2	18	18	18	18	140	140	actif	actif	assets/images/products/chaara_classique_200g.jpeg	assets/images/products/chaara_classique_200g.jpeg	2026-07-16 11:16:37.909056	2026-07-16 11:16:37.909056
8	Assil Chaara Classique 250g	Assil Chaara Classique 250g	9305-250	9305-250	9305-250	250g	Thé vert en filaments	Thé vert en filaments	2	23	23	23	23	130	130	actif	actif	assets/images/products/chaara_classique_250g.jpeg	assets/images/products/chaara_classique_250g.jpeg	2026-07-16 11:16:37.909056	2026-07-16 11:16:37.909056
9	Assil Chaara Classique 500g	Assil Chaara Classique 500g	9305-500	9305-500	9305-500	500g	Thé vert en filaments	Thé vert en filaments	2	44	44	44	44	110	110	actif	actif	assets/images/products/chaara_classique_500.jpeg	assets/images/products/chaara_classique_500.jpeg	2026-07-16 11:16:37.909056	2026-07-16 11:16:37.909056
10	Assil Chaara Classique 1kg	Assil Chaara Classique 1kg	9305-1000	9305-1000	9305-1000	1kg	Thé vert en filaments	Thé vert en filaments	2	85	85	85	85	80	80	actif	actif	assets/images/products/chaara_classique_1kg.jpeg	assets/images/products/chaara_classique_1kg.jpeg	2026-07-16 11:16:37.909056	2026-07-16 11:16:37.909056
11	Assil Chaara Classique 2kg	Assil Chaara Classique 2kg	9305-2000	9305-2000	9305-2000	2kg	Thé vert en filaments	Thé vert en filaments	2	160	160	160	160	60	60	actif	actif	assets/images/products/chaara_classique_2kg.jpeg	assets/images/products/chaara_classique_2kg.jpeg	2026-07-16 11:16:37.909056	2026-07-16 11:16:37.909056
12	Assil Al-Lamma Premium 200g	Assil Al-Lamma Premium 200g	ALP-200	ALP-200	ALP-200	200g	Thé vert en grains Gunpowder	Thé vert en grains Gunpowder	1	20	20	20	20	120	120	actif	actif	assets/images/products/allamma_premium_200g.jpeg	assets/images/products/allamma_premium_200g.jpeg	2026-07-16 11:16:37.909056	2026-07-16 11:16:37.909056
13	Assil Al-Lamma Premium 250g	Assil Al-Lamma Premium 250g	ALP-250	ALP-250	ALP-250	250g	Thé vert en grains Gunpowder	Thé vert en grains Gunpowder	1	25	25	25	25	110	110	actif	actif	assets/images/products/allamma_premium_250g.jpeg	assets/images/products/allamma_premium_250g.jpeg	2026-07-16 11:16:37.909056	2026-07-16 11:16:37.909056
14	Assil Al-Lamma Premium 500g	Assil Al-Lamma Premium 500g	ALP-500	ALP-500	ALP-500	500g	Thé vert en grains Gunpowder	Thé vert en grains Gunpowder	1	49	49	49	49	95	95	actif	actif	assets/images/products/allamma_premium_500g.jpeg	assets/images/products/allamma_premium_500g.jpeg	2026-07-16 11:16:37.909056	2026-07-16 11:16:37.909056
15	Assil Al-Lamma Premium 1kg	Assil Al-Lamma Premium 1kg	ALP-1000	ALP-1000	ALP-1000	1kg	Thé vert en grains Gunpowder	Thé vert en grains Gunpowder	1	92	92	92	92	75	75	actif	actif	assets/images/products/allamma_premium_1kg.jpeg	assets/images/products/allamma_premium_1kg.jpeg	2026-07-16 11:16:37.909056	2026-07-16 11:16:37.909056
16	Assil Al-Lamma Premium 2kg	Assil Al-Lamma Premium 2kg	ALP-2000	ALP-2000	ALP-2000	2kg	Thé vert en grains Gunpowder	Thé vert en grains Gunpowder	1	175	175	175	175	55	55	actif	actif	assets/images/products/allamma_premium_2kg.jpeg	assets/images/products/allamma_premium_2kg.jpeg	2026-07-16 11:16:37.909056	2026-07-16 11:16:37.909056
17	Assil Al-Lamma Classique 200g	Assil Al-Lamma Classique 200g	ALC-200	ALC-200	ALC-200	200g	Thé vert en grains Gunpowder	Thé vert en grains Gunpowder	1	16	16	16	16	150	150	actif	actif	assets/images/products/allamma_classique_200g.jpeg	assets/images/products/allamma_classique_200g.jpeg	2026-07-16 11:16:37.909056	2026-07-16 11:16:37.909056
18	Assil Al-Lamma Classique 250g	Assil Al-Lamma Classique 250g	ALC-250	ALC-250	ALC-250	250g	Thé vert en grains Gunpowder	Thé vert en grains Gunpowder	1	21	21	21	21	140	140	actif	actif	assets/images/products/allamma_classique_250g.jpeg	assets/images/products/allamma_classique_250g.jpeg	2026-07-16 11:16:37.909056	2026-07-16 11:16:37.909056
19	Assil Al-Lamma Classique 500g	Assil Al-Lamma Classique 500g	ALC-500	ALC-500	ALC-500	500g	Thé vert en grains Gunpowder	Thé vert en grains Gunpowder	1	40	40	40	40	120	120	actif	actif	assets/images/products/allamma_classique_500g.jpeg	assets/images/products/allamma_classique_500g.jpeg	2026-07-16 11:16:37.909056	2026-07-16 11:16:37.909056
20	Assil Al-Lamma Classique 1kg	Assil Al-Lamma Classique 1kg	ALC-1000	ALC-1000	ALC-1000	1kg	Thé vert en grains Gunpowder	Thé vert en grains Gunpowder	1	78	78	78	78	90	90	actif	actif	assets/images/products/allamma_classique_1kg.jpeg	assets/images/products/allamma_classique_1kg.jpeg	2026-07-16 11:16:37.909056	2026-07-16 11:16:37.909056
21	Assil Al-Lamma Classique 2kg	Assil Al-Lamma Classique 2kg	ALC-2000	ALC-2000	ALC-2000	2kg	Thé vert en grains Gunpowder	Thé vert en grains Gunpowder	1	150	150	150	150	70	70	actif	actif	assets/images/products/allamma_classique_2kg.jpeg	assets/images/products/allamma_classique_2kg.jpeg	2026-07-16 11:16:37.909056	2026-07-16 11:16:37.909056
24	the vert	the vert	test ref	test ref	test ref	test	test	test	\N	10.0	10.0	10.0	10.0	1000	1000	actif	actif	assets/images/products/allamma_classique_1kg.jpeg	assets/images/products/allamma_classique_1kg.jpeg	2026-07-20 01:39:44.30834	2026-07-20 01:39:44.30834
\.


--
-- Data for Name: rapports; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.rapports (id, commercial_id, manager_id, commercial_name, city, email, phone, report_date, sent_at, summary, activities_count, clients_count, calls, meetings, tasks, claims, orders_count, revenue, comments, manager_comment, is_read, created_at) FROM stdin;
1	3	2	Ryme Mnf	Casablanca	ryme.mounfalouti@gmail.com	\N	2026-07-20	2026-07-20 02:17:21.554656	1 commandes, 0 visites, 0 appels	0	0	0	0	0	0	1	110.00	\N	\N	t	2026-07-20 02:17:21.554656
2	13	2	Sara Ramzi	Casablanca	sara@teasud.ma	\N	2026-07-20	2026-07-20 02:39:01.759079	0 commandes, 1 visites, 0 appels	1	0	0	1	1	0	0	0.00	\N	\N	f	2026-07-20 02:39:01.759079
3	13	2	Sara Ramzi	Casablanca	sara@teasud.ma	\N	2026-07-20	2026-07-20 03:01:56.614506	0 commandes, 1 visites, 0 appels	2	0	0	2	2	0	0	0.00	\N	\N	f	2026-07-20 03:01:56.614506
\.


--
-- Data for Name: user_preferences; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.user_preferences (user_id, preferences, updated_at) FROM stdin;
2	{"language": "fr"}	2026-07-16 10:57:09.269511
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.users (id, email, password, prenom, nom, phone, telephone, role, is_active, status, statut, etat, created_at, updated_at) FROM stdin;
2	ryme@mounfalouti.ma	scrypt:32768:8:1$w6Z4IAVNF9l667YZ$e54760b84ffe1c09cb2a84f1d3e0f732f78905acd67ffdfb0af1c024cbf6b448a3472bf4e45b850cc4cebcb231b2036a01b0a437fb1e0a84675846ce126b35f0	Ryme	Mounfalouti	0767166610	0767166610	manager	t	actif	actif	actif	2026-07-15 21:11:17.672214	2026-07-20 00:18:05.16191
1	admin@teasud.ma	scrypt:32768:8:1$P2bB2JJzkbws6FO0$ace8f9159acad863f26a82d1c216e772f06225b844c97b42c955415e8a38642fbc2f462f5381af97e5b5626db6a233d8743305aa7d4671ec0d22a6fcd5faf463	Ryme	Teasud	\N	\N	admin	t	\N	\N	\N	2026-07-15 21:05:53.088602	2026-07-20 01:38:41.457188
3	ryme.mounfalouti@gmail.com	scrypt:32768:8:1$e9YT7TSl9kKX3t84$4db8b166bb3efd85f85e2d7ca96144d9d2541700f8107bc34240c281e892caee088f6b09612f28d321bacd2dea0ad576f0299653db44f0880f028c60d310d493	Ryme	Mnf	0767166610	0767166610	commercial	t	actif	actif	actif	2026-07-15 21:15:49.021164	2026-07-20 00:49:38.957659
13	sara@teasud.ma	scrypt:32768:8:1$W7B7XURDciEUEYXj$9175a4b001e5167f0d2e5839ebe9466abc249060e065747fc120cea82e96a7f2e0107736bd7b5d2abce874f994915e2b5467f0bf0c72941f1dea50fb17f5ea27	Sara	Ramzi	0606060606	0606060606	commercial	t	actif	actif	actif	2026-07-20 01:38:28.985148	2026-07-20 01:38:28.985148
\.


--
-- Name: activites_recentes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.activites_recentes_id_seq', 38, true);


--
-- Name: categories_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.categories_id_seq', 2, true);


--
-- Name: clients_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.clients_id_seq', 12, true);


--
-- Name: details_facture_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.details_facture_id_seq', 7, true);


--
-- Name: factures_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.factures_id_seq', 5, true);


--
-- Name: notifications_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.notifications_id_seq', 21, true);


--
-- Name: produits_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.produits_id_seq', 24, true);


--
-- Name: rapports_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.rapports_id_seq', 3, true);


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.users_id_seq', 13, true);


--
-- Name: activites_recentes activites_recentes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activites_recentes
    ADD CONSTRAINT activites_recentes_pkey PRIMARY KEY (id);


--
-- Name: categories categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


--
-- Name: clients clients_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clients
    ADD CONSTRAINT clients_pkey PRIMARY KEY (id);


--
-- Name: company_info company_info_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_info
    ADD CONSTRAINT company_info_pkey PRIMARY KEY (id);


--
-- Name: details_facture details_facture_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.details_facture
    ADD CONSTRAINT details_facture_pkey PRIMARY KEY (id);


--
-- Name: factures factures_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.factures
    ADD CONSTRAINT factures_pkey PRIMARY KEY (id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: produits produits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.produits
    ADD CONSTRAINT produits_pkey PRIMARY KEY (id);


--
-- Name: rapports rapports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rapports
    ADD CONSTRAINT rapports_pkey PRIMARY KEY (id);


--
-- Name: user_preferences user_preferences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_preferences
    ADD CONSTRAINT user_preferences_pkey PRIMARY KEY (user_id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: activites_recentes activites_recentes_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activites_recentes
    ADD CONSTRAINT activites_recentes_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.clients(id) ON DELETE CASCADE;


--
-- Name: activites_recentes activites_recentes_commande_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activites_recentes
    ADD CONSTRAINT activites_recentes_commande_id_fkey FOREIGN KEY (commande_id) REFERENCES public.factures(id) ON DELETE CASCADE;


--
-- Name: clients clients_commercial_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clients
    ADD CONSTRAINT clients_commercial_id_fkey FOREIGN KEY (commercial_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: details_facture details_facture_facture_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.details_facture
    ADD CONSTRAINT details_facture_facture_id_fkey FOREIGN KEY (facture_id) REFERENCES public.factures(id) ON DELETE CASCADE;


--
-- Name: details_facture details_facture_produit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.details_facture
    ADD CONSTRAINT details_facture_produit_id_fkey FOREIGN KEY (produit_id) REFERENCES public.produits(id);


--
-- Name: factures factures_commercial_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.factures
    ADD CONSTRAINT factures_commercial_id_fkey FOREIGN KEY (commercial_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: factures factures_id_client_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.factures
    ADD CONSTRAINT factures_id_client_fkey FOREIGN KEY (id_client) REFERENCES public.clients(id) ON DELETE CASCADE;


--
-- Name: factures factures_manager_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.factures
    ADD CONSTRAINT factures_manager_id_fkey FOREIGN KEY (manager_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: notifications notifications_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.clients(id) ON DELETE CASCADE;


--
-- Name: notifications notifications_commande_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_commande_id_fkey FOREIGN KEY (commande_id) REFERENCES public.factures(id) ON DELETE CASCADE;


--
-- Name: produits produits_id_cat_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.produits
    ADD CONSTRAINT produits_id_cat_fkey FOREIGN KEY (id_cat) REFERENCES public.categories(id);


--
-- PostgreSQL database dump complete
--

