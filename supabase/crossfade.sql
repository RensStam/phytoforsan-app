-- =====================================================================
-- PhytoForsan — overvloei-tijd (crossfade) voor de meditatietimer-muziek
-- Voer dit uit in de Supabase SQL Editor. Opnieuw uitvoeren is veilig.
--
-- Per achtergrondmuziek-koppeling instelbaar hoeveel seconden het einde van de
-- track over het begin heen vloeit bij het herhalen. Alleen de meditatietimer
-- gebruikt dit (die speelt via Web Audio met crossfade-loop); leeg = 3s standaard.
-- =====================================================================
alter table public.protocol_audio add column if not exists crossfade_seconds numeric(5,2);

select 'Crossfade-kolom klaar' as status;
