-- =====================================================================
-- PhytoForsan — Gastgebruik registreren (usage_sessions)
-- Voer dit uit in de Supabase SQL Editor.
--
-- De app registreert per afgeronde/afgebroken sessie (>= 1 minuut) van
-- GASTEN (niet-ingelogde gebruikers) een anonieme rij: een willekeurig
-- apparaatnummer, het protocol, de duur en het tijdstip. Geen
-- persoonsgegevens. Beveiliging: iedereen mag alleen TOEVOEGEN,
-- uitsluitend admins kunnen lezen.
-- =====================================================================
create table if not exists public.usage_sessions (
  id uuid primary key default gen_random_uuid(),
  device_id text not null,
  protocol_slug text,
  seconds integer default 0,
  completed boolean default false,
  is_guest boolean default true,
  created_at timestamptz not null default now()
);

create index if not exists usage_sessions_device_idx  on public.usage_sessions (device_id);
create index if not exists usage_sessions_created_idx on public.usage_sessions (created_at desc);

alter table public.usage_sessions enable row level security;

drop policy if exists usage_sessions_insert_all on public.usage_sessions;
create policy usage_sessions_insert_all on public.usage_sessions
  for insert with check (true);

drop policy if exists usage_sessions_admin_read on public.usage_sessions;
create policy usage_sessions_admin_read on public.usage_sessions
  for select using (public.is_admin());

select 'usage_sessions klaar' as status;
