-- =====================================================================
-- PhytoForsan — toegangscodes (los van gebruikersaccounts)
-- Voer dit uit in de Supabase SQL Editor.
-- Een code ontgrendelt 'deep' (of 'premium') op het apparaat, zonder account.
-- Codes zijn alleen voor admins zichtbaar; inwisselen gaat via een functie die
-- de code niet blootgeeft.
-- =====================================================================
create table if not exists public.access_codes (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  tier text not null default 'deep' check (tier in ('deep','premium')),
  label text,
  active boolean not null default true,
  max_uses int,                 -- null = onbeperkt
  uses int not null default 0,
  expires_at timestamptz,       -- null = geen vervaldatum
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.access_codes enable row level security;
drop policy if exists access_codes_admin_all on public.access_codes;
create policy access_codes_admin_all on public.access_codes
  for all using (public.is_admin()) with check (public.is_admin());

-- Veilige inwissel-functie: geeft alleen het tier terug (of null), niet de codes.
create or replace function public.redeem_access_code(p_code text)
returns text
language plpgsql security definer set search_path = public as $$
declare r public.access_codes%rowtype;
begin
  select * into r from public.access_codes where lower(code) = lower(trim(p_code));
  if not found then return null; end if;
  if not r.active then return null; end if;
  if r.expires_at is not null and r.expires_at < now() then return null; end if;
  if r.max_uses is not null and r.uses >= r.max_uses then return null; end if;
  update public.access_codes set uses = uses + 1, updated_at = now() where id = r.id;
  return r.tier;
end; $$;

grant execute on function public.redeem_access_code(text) to anon, authenticated;

-- Voorbeeldcode (mag je verwijderen of aanpassen):
insert into public.access_codes (code, tier, label)
values ('PHYTO-DEEP-2026', 'deep', 'Algemene deep-toegang')
on conflict (code) do nothing;
