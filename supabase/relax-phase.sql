-- =====================================================================
-- PhytoForsan — ontspanningsfase (de afsluitende fase van een sessie)
-- Voer dit uit in de Supabase SQL Editor. Opnieuw uitvoeren is veilig.
--
-- De afsluitende fase heet voortaan "ontspanningsfase" en toont een eigen
-- woord (standaard ONTSPANNING) i.p.v. RUST — zodat het niet dubbel oogt met
-- de rustmomenten in het ademritme. Per protocol te overschrijven.
-- =====================================================================
alter table public.protocols add column if not exists relax_cue_word text;
alter table public.protocols add column if not exists relax_cue_sub  text;

insert into public.app_settings (key, value) values ('default_relax_cue_word', 'ONTSPANNING')
on conflict (key) do nothing;
insert into public.app_settings (key, value) values ('default_relax_cue_sub', 'kom rustig tot rust')
on conflict (key) do nothing;

select 'Ontspanningsfase-velden klaar' as status;
