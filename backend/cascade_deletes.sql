-- Delete behaviour for the FK graph. Idempotent: re-running is safe.
--
--   client  deleted -> its factures and their details_facture lines go with it
--   user    deleted -> its clients/factures survive, just unassigned (SET NULL)
--   produit deleted -> still blocked (409): removing an invoice line would
--                      silently change the total of an already-issued invoice
--
-- Apply:  psql -d prevente_db -f cascade_deletes.sql
-- Kept in sync with schema_export.sql, which is what --wipe rebuilds from.

BEGIN;

-- A client's invoices die with the client. details_facture.facture_id already
-- cascades, so the invoice lines follow without another constraint.
ALTER TABLE public.factures DROP CONSTRAINT IF EXISTS factures_id_client_fkey;
ALTER TABLE public.factures
    ADD CONSTRAINT factures_id_client_fkey FOREIGN KEY (id_client)
    REFERENCES public.clients(id) ON DELETE CASCADE;

-- Deleting a commercial must not erase the customer base or the revenue
-- history it produced, so the rows survive with a null owner.
ALTER TABLE public.clients DROP CONSTRAINT IF EXISTS clients_commercial_id_fkey;
ALTER TABLE public.clients
    ADD CONSTRAINT clients_commercial_id_fkey FOREIGN KEY (commercial_id)
    REFERENCES public.users(id) ON DELETE SET NULL;

ALTER TABLE public.factures DROP CONSTRAINT IF EXISTS factures_commercial_id_fkey;
ALTER TABLE public.factures
    ADD CONSTRAINT factures_commercial_id_fkey FOREIGN KEY (commercial_id)
    REFERENCES public.users(id) ON DELETE SET NULL;

ALTER TABLE public.factures DROP CONSTRAINT IF EXISTS factures_manager_id_fkey;
ALTER TABLE public.factures
    ADD CONSTRAINT factures_manager_id_fkey FOREIGN KEY (manager_id)
    REFERENCES public.users(id) ON DELETE SET NULL;

-- activites_recentes and notifications carried client_id/commande_id with no
-- constraint at all, so deletes left rows pointing at nothing. Drop the
-- existing orphans, then let the FK prevent new ones.
DELETE FROM public.activites_recentes a
 WHERE (a.client_id IS NOT NULL
        AND NOT EXISTS (SELECT 1 FROM public.clients c WHERE c.id = a.client_id))
    OR (a.commande_id IS NOT NULL
        AND NOT EXISTS (SELECT 1 FROM public.factures f WHERE f.id = a.commande_id));

DELETE FROM public.notifications n
 WHERE (n.client_id IS NOT NULL
        AND NOT EXISTS (SELECT 1 FROM public.clients c WHERE c.id = n.client_id))
    OR (n.commande_id IS NOT NULL
        AND NOT EXISTS (SELECT 1 FROM public.factures f WHERE f.id = n.commande_id));

ALTER TABLE public.activites_recentes DROP CONSTRAINT IF EXISTS activites_recentes_client_id_fkey;
ALTER TABLE public.activites_recentes
    ADD CONSTRAINT activites_recentes_client_id_fkey FOREIGN KEY (client_id)
    REFERENCES public.clients(id) ON DELETE CASCADE;

ALTER TABLE public.activites_recentes DROP CONSTRAINT IF EXISTS activites_recentes_commande_id_fkey;
ALTER TABLE public.activites_recentes
    ADD CONSTRAINT activites_recentes_commande_id_fkey FOREIGN KEY (commande_id)
    REFERENCES public.factures(id) ON DELETE CASCADE;

ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_client_id_fkey;
ALTER TABLE public.notifications
    ADD CONSTRAINT notifications_client_id_fkey FOREIGN KEY (client_id)
    REFERENCES public.clients(id) ON DELETE CASCADE;

ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_commande_id_fkey;
ALTER TABLE public.notifications
    ADD CONSTRAINT notifications_commande_id_fkey FOREIGN KEY (commande_id)
    REFERENCES public.factures(id) ON DELETE CASCADE;

COMMIT;
