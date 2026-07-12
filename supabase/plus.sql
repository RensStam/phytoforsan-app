-- =====================================================================
-- PhytoForsan Relax Plus — entitlements, rustcodes, betalingen, proefperiode
-- Voer dit uit in de Supabase SQL Editor (na schema.sql en access-codes.sql).
--
-- Centrale waarheid voor toegang: public.user_entitlements.
--   entitlement_type = 'premium'  (Plus)
--   source           = trial | rustcode | mollie_payment | admin
-- De app leest toegang uitsluitend via get_user_access().
-- =====================================================================

-- ---------- 1. user_entitlements: centrale toegangstabel ----------
create table if not exists public.user_entitlements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  entitlement_type text not null default 'premium',
  source text not null,                       -- trial | rustcode | mollie_payment | admin
  starts_at timestamptz not null default now(),
  ends_at timestamptz,                        -- null = onbeperkt
  status text not null default 'active',     -- active | expired | revoked
  reference_id text,                          -- access_code id of Mollie payment id
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists user_entitlements_user_idx on public.user_entitlements (user_id, status);
create index if not exists user_entitlements_ends_idx on public.user_entitlements (ends_at);

alter table public.user_entitlements enable row level security;
drop policy if exists entitlements_self_read on public.user_entitlements;
create policy entitlements_self_read on public.user_entitlements
  for select using (user_id = auth.uid() or public.is_admin());
drop policy if exists entitlements_admin_write on public.user_entitlements;
create policy entitlements_admin_write on public.user_entitlements
  for all using (public.is_admin()) with check (public.is_admin());
-- Gewone gebruikers schrijven nooit rechtstreeks; dat doen de security-definer
-- functies hieronder en de Mollie-webhook (service role).

-- ---------- 2. payment_records: controle & dubbele-verwerking-preventie ----------
create table if not exists public.payment_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  provider text not null default 'mollie',
  provider_payment_id text not null unique,
  amount numeric(10,2),
  currency text not null default 'EUR',
  product_type text not null default 'relax_plus_year',
  status text not null default 'open',        -- open | paid | failed | canceled | expired
  processed_at timestamptz,                   -- gezet zodra entitlement is aangemaakt
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists payment_records_user_idx on public.payment_records (user_id);

alter table public.payment_records enable row level security;
drop policy if exists payments_self_read on public.payment_records;
create policy payments_self_read on public.payment_records
  for select using (user_id = auth.uid() or public.is_admin());
-- Schrijven: alleen de Edge Functions (service role, omzeilt RLS).

-- ---------- 3. Rustcodes: dagen toegang per code ----------
alter table public.access_codes add column if not exists days int not null default 30;

-- ---------- 4. Proefperiode: 30 dagen Plus bij eerste registratie ----------
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_new uuid;
begin
  insert into public.profiles (id, email, display_name)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'display_name', new.email))
  on conflict (id) do nothing
  returning id into v_new;
  -- Alleen bij een écht nieuw profiel: 30 dagen proefperiode
  if v_new is not null then
    insert into public.user_entitlements (user_id, entitlement_type, source, starts_at, ends_at, status)
    values (v_new, 'premium', 'trial', now(), now() + interval '30 days', 'active');
  end if;
  return new;
end; $$;

-- ---------- 5. Centrale toegangsfunctie ----------
-- Eén bron van waarheid voor de app: wat mag deze gebruiker, tot wanneer, en waardoor?
create or replace function public.get_user_access()
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  prof public.profiles%rowtype;
  ent public.user_entitlements%rowtype;
begin
  if auth.uid() is null then
    return jsonb_build_object('level','free','source','guest','ends_at',null);
  end if;
  select * into prof from public.profiles where id = auth.uid();
  if prof.role = 'admin' or prof.access_level = 'admin' then
    return jsonb_build_object('level','admin','source','admin','ends_at',null);
  end if;
  select * into ent from public.user_entitlements
    where user_id = auth.uid()
      and entitlement_type = 'premium'
      and status = 'active'
      and starts_at <= now()
      and (ends_at is null or ends_at > now())
    order by ends_at desc nulls first
    limit 1;
  if found then
    return jsonb_build_object('level','premium','source',ent.source,'ends_at',ent.ends_at);
  end if;
  -- Handmatig gezette niveaus op het profiel (bestaand veld) blijven werken.
  if prof.access_level in ('deep','premium') then
    return jsonb_build_object('level',prof.access_level,'source','handmatig','ends_at',null);
  end if;
  return jsonb_build_object('level','free','source','account','ends_at',null);
end; $$;
grant execute on function public.get_user_access() to authenticated;

-- ---------- 6. Rustcode verzilveren (ingelogde gebruiker → entitlement) ----------
create or replace function public.redeem_rest_code(p_code text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  r public.access_codes%rowtype;
  v_days int;
  v_ends timestamptz;
begin
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'reason', 'login');
  end if;
  select * into r from public.access_codes
    where lower(code) = lower(trim(p_code))
    for update;   -- lock: geen gelijktijdige dubbele verzilvering
  if not found or not r.active then return jsonb_build_object('ok', false, 'reason', 'ongeldig'); end if;
  if r.expires_at is not null and r.expires_at < now() then return jsonb_build_object('ok', false, 'reason', 'verlopen'); end if;
  if r.max_uses is not null and r.uses >= r.max_uses then return jsonb_build_object('ok', false, 'reason', 'op'); end if;
  -- Dezelfde code niet twee keer door dezelfde gebruiker laten verzilveren
  if exists (
    select 1 from public.user_entitlements
    where user_id = auth.uid() and source = 'rustcode' and reference_id = r.id::text
  ) then
    return jsonb_build_object('ok', false, 'reason', 'al_gebruikt');
  end if;
  v_days := coalesce(r.days, 30);
  v_ends := now() + make_interval(days => v_days);
  insert into public.user_entitlements (user_id, entitlement_type, source, starts_at, ends_at, status, reference_id)
  values (auth.uid(), 'premium', 'rustcode', now(), v_ends, 'active', r.id::text);
  update public.access_codes set uses = uses + 1, updated_at = now() where id = r.id;
  return jsonb_build_object('ok', true, 'ends_at', v_ends, 'days', v_days);
end; $$;
grant execute on function public.redeem_rest_code(text) to authenticated;

-- ---------- 7. Handmatig Plus geven (support/admin) ----------
create or replace function public.admin_grant_plus(p_user uuid, p_days int default 365)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_ends timestamptz;
begin
  if not public.is_admin() then return jsonb_build_object('ok', false, 'reason', 'geen_admin'); end if;
  v_ends := now() + make_interval(days => p_days);
  insert into public.user_entitlements (user_id, entitlement_type, source, starts_at, ends_at, status)
  values (p_user, 'premium', 'admin', now(), v_ends, 'active');
  return jsonb_build_object('ok', true, 'ends_at', v_ends);
end; $$;
grant execute on function public.admin_grant_plus(uuid, int) to authenticated;

select 'Plus-structuur klaar' as status;
