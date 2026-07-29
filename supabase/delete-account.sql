-- =====================================================================
-- PhytoForsan — account verwijderen: factuur-snapshot behouden
-- Voer dit uit in de Supabase SQL Editor. Opnieuw uitvoeren is veilig.
--
-- Bij het verwijderen van een account worden alle persoonsgegevens gewist
-- (profiel incl. NAW, voortgang, toegang, rechten). De betaalregels moeten
-- voor de administratie bewaard blijven, maar de NAW-gegevens staan alleen in
-- het profiel — dat verdwijnt. Daarom kopieert de Edge Function `delete-account`
-- de factuurgegevens vlak vóór het verwijderen naar deze snapshot-kolommen,
-- zodat elke factuur op zichzelf compleet blijft.
-- =====================================================================
alter table public.payment_records add column if not exists billing_name text;
alter table public.payment_records add column if not exists billing_address text;
alter table public.payment_records add column if not exists billing_email text;
alter table public.payment_records add column if not exists billing_snapshot_at timestamptz;

select 'Factuur-snapshot-kolommen klaar' as status;
