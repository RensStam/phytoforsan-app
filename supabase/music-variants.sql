-- =====================================================================
-- PhytoForsan — meerdere muziekvarianten voor de meditatietimer
-- Voer dit uit in de Supabase SQL Editor. Opnieuw uitvoeren is veilig.
--
-- Een protocol kan nu meerdere achtergrond-varianten hebben (bv. "Ochtend",
-- "Avond"), elk met een eigen naam, dagdeel, volume, loop en crossfade. De app
-- kiest automatisch de variant die bij het dagdeel hoort; de gebruiker kan in
-- het meditatiescherm zelf wisselen. Alleen de meditatietimer gebruikt dit.
-- =====================================================================
alter table public.protocol_audio add column if not exists variant_label text;         -- naam die de gebruiker ziet
alter table public.protocol_audio add column if not exists daypart text;               -- morning | afternoon | evening | night | null
alter table public.protocol_audio add column if not exists sort_order int not null default 0;

select 'Muziekvariant-kolommen klaar' as status;
