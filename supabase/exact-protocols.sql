-- =====================================================================
-- PhytoForsan — exacte, cyclus-gestuurde ademprotocollen
-- Voer dit uit in de Supabase SQL Editor. Opnieuw uitvoeren is veilig.
--
-- Model: een ademfase krijgt een AANTAL CYCLI (breath_cycles). De exacte
-- fase-duur = cycli × cyclusduur (in/hold/uit/pauze). Elk protocol eindigt met
-- een afsluitende rust (closing_rest_seconds; leeg = app-brede standaard) en
-- daarna het eindbericht. Zo is de totaalduur absoluut en op de muziek af te
-- stemmen, en beweegt hij mee met het ritme.
-- =====================================================================

-- Aantal ademcycli per (ademende) fase; duration_seconds blijft de bron voor de
-- app en wordt bij opslaan gezet op breath_cycles × cyclusduur.
alter table public.protocol_phases add column if not exists breath_cycles int;

-- Afsluitende rust per protocol (seconden). NULL = gebruik de app-brede standaard.
alter table public.protocols add column if not exists closing_rest_seconds int;

-- App-brede standaard voor de afsluitrust (seconden).
insert into public.app_settings (key, value)
values ('default_closing_rest_seconds', '15')
on conflict (key) do nothing;

select 'Exacte-protocol-kolommen klaar' as status;
