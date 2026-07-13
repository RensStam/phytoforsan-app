-- =====================================================================
-- PhytoForsan — opbouwschema per protocol kunnen vergrendelen
-- Voer dit uit in de Supabase SQL Editor. Opnieuw uitvoeren is veilig.
--
-- Staat 'lock_schema' op true, dan kan de gebruiker het ademritme/opbouwschema
-- van dat protocol niet aanpassen (de ritme-sliders verdwijnen in de app).
-- =====================================================================
alter table public.protocols add column if not exists lock_schema boolean not null default false;

select 'lock_schema-kolom klaar' as status;
