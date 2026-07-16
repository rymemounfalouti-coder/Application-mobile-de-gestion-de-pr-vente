INSERT INTO public.users (id, email, password, prenom, nom, phone, telephone, role, is_active, status, statut, etat, created_at, updated_at)
VALUES (1, 'admin@prevente.local', 'scrypt:32768:8:1$P2bB2JJzkbws6FO0$ace8f9159acad863f26a82d1c216e772f06225b844c97b42c955415e8a38642fbc2f462f5381af97e5b5626db6a233d8743305aa7d4671ec0d22a6fcd5faf463', 'Admin', 'Prevente', NULL, NULL, 'admin', true, NULL, NULL, NULL, now(), now())
ON CONFLICT (id) DO NOTHING;

SELECT setval(pg_get_serial_sequence('users', 'id'), (SELECT COALESCE(MAX(id), 1) FROM users));
