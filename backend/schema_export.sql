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
    category text,
    status text,
    last_order_date text,
    commercial_id integer,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now()
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
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


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
-- Name: produits produits_id_cat_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.produits
    ADD CONSTRAINT produits_id_cat_fkey FOREIGN KEY (id_cat) REFERENCES public.categories(id);


--
-- PostgreSQL database dump complete
--

