-- =====================================================================
-- PhytoForsan — Meditatietimer terugzetten in Supabase
-- Voer dit uit in de Supabase SQL Editor.
-- De slug 'meditationTimer' koppelt aan het ingebouwde meditatie-protocol
-- (vrije timer zonder ademsturing). Geen fases nodig.
-- =====================================================================
insert into public.categories (slug, title, sort_order, status)
values ('meditatie', 'Meditatie', 3, 'published')
on conflict (slug) do nothing;

insert into public.protocols (slug, title, category_id, short_description, long_description, access_tier, status, sort_order, night)
select 'meditationTimer', 'Meditatietimer',
       (select id from public.categories where slug = 'meditatie' limit 1),
       'Een vrije meditatie zonder ademsturing of klank. Alleen tijd, ruimte en aandacht.',
       'Gebruik de meditatietimer voor een stille sessie op je eigen manier. De app stuurt je ademhaling niet en gebruikt geen humming of klankprotocol. De cirkel toont alleen het verloop van de sessie.',
       'free', 'published', 16, false
on conflict (slug) do nothing;

select slug, title, status from public.protocols where slug = 'meditationTimer';
