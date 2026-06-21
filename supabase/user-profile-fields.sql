-- =====================================================================
-- PhytoForsan — uitgebreid gebruikersprofiel + privilege-beveiliging
-- Voer dit uit in de Supabase SQL Editor.
-- =====================================================================

-- Extra profielvelden (alle optioneel)
alter table public.profiles add column if not exists first_name text;
alter table public.profiles add column if not exists last_name text;
alter table public.profiles add column if not exists sex text;            -- man | vrouw | anders | onbekend
alter table public.profiles add column if not exists birthdate date;
alter table public.profiles add column if not exists phone text;
alter table public.profiles add column if not exists street text;
alter table public.profiles add column if not exists house_number text;
alter table public.profiles add column if not exists postal_code text;
alter table public.profiles add column if not exists city text;
alter table public.profiles add column if not exists country text;
alter table public.profiles add column if not exists consent_at timestamptz;  -- akkoord verwerking gegevens

-- Beveiliging: een gewone gebruiker mag zijn eigen rol/toegangsniveau NIET wijzigen.
-- (Persoonsgegevens mag hij wel zelf bijwerken via de bestaande self-update policy.)
create or replace function public.protect_profile_privileges()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then
    new.role := old.role;
    new.access_level := old.access_level;
  end if;
  return new;
end; $$;

drop trigger if exists profiles_protect_priv on public.profiles;
create trigger profiles_protect_priv
  before update on public.profiles
  for each row execute function public.protect_profile_privileges();

-- =====================================================================
-- Voortgang + instellingen per gebruiker (volgt mee tussen apparaten)
-- =====================================================================
create table if not exists public.user_state (
  user_id uuid primary key references auth.users(id) on delete cascade,
  sessions jsonb not null default '[]'::jsonb,   -- sessiegeschiedenis
  settings jsonb not null default '{}'::jsonb,   -- ademritmes, volume e.d.
  updated_at timestamptz not null default now()
);
alter table public.user_state enable row level security;
drop policy if exists user_state_self on public.user_state;
create policy user_state_self on public.user_state
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists user_state_admin_read on public.user_state;
create policy user_state_admin_read on public.user_state
  for select using (public.is_admin());
