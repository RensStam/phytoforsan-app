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
       'Een vrije meditatie zonder ademsturing. Tijd, stilte en optioneel zachte klankmarkeringen.',
       'Gebruik de meditatietimer voor een vrije sessie in stilte of met zachte klankmarkeringen. De app stuurt je ademhaling niet. Je bepaalt zelf hoe je zit, ademt of luistert. De cirkel toont alleen het verloop van de tijd.',
       'free', 'published', 16, false
on conflict (slug) do nothing;

-- Bestaat de rij al maar staat hij op concept (bijv. door de oude fase-validatie
-- bij het opslaan van teksten)? Zet hem dan terug op published.
update public.protocols
set status = 'published'
where slug = 'meditationTimer' and status <> 'published';

select slug, title, status from public.protocols where slug = 'meditationTimer';
