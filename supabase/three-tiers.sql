-- =====================================================================
-- PhytoForsan — drie toegangslagen: free < deep < premium (Plus)
-- Voer dit uit in de Supabase SQL Editor (na plus.sql en content-tiers.sql).
-- Opnieuw uitvoeren is veilig (idempotent).
--
-- Model:
--   free    → gast: basisprotocollen
--   deep    → ingelogd (of rustcode): + verdiepingssessies
--   premium → betaald (Plus): + intensieve protocollen
-- Verdieping is inhoudelijk bereikbaar voor deep; de INTENSIEVE protocollen
-- (access_tier = 'premium' / requires_premium) blijven exclusief voor Plus.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Centrale toegangsfunctie: geeft het niveau van de huidige gebruiker.
--    Ingelogd zonder betaalde/toegekende Plus = 'deep'.
-- ---------------------------------------------------------------------
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
  -- Premium (Plus): actieve entitlement van het type 'premium' (betaald/toegekend)
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
  if prof.access_level = 'premium' then
    return jsonb_build_object('level','premium','source','handmatig','ends_at',null);
  end if;
  -- Ingelogd = minimaal deep (verdiepingssessies)
  return jsonb_build_object('level','deep','source','account','ends_at',null);
end; $$;
grant execute on function public.get_user_access() to authenticated;

-- ---------------------------------------------------------------------
-- 2. Is de huidige gebruiker een Plus-gebruiker (premium)?
-- ---------------------------------------------------------------------
create or replace function public.user_is_premium()
returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and (p.role = 'admin' or p.access_level in ('premium','admin'))
    )
    or exists (
      select 1 from public.user_entitlements e
      where e.user_id = auth.uid()
        and e.entitlement_type = 'premium'
        and e.status = 'active'
        and e.starts_at <= now()
        and (e.ends_at is null or e.ends_at > now())
    )
  );
$$;
grant execute on function public.user_is_premium() to anon, authenticated;

-- ---------------------------------------------------------------------
-- 3. Inhoud (fases) per laag:
--    free → iedereen · deep → ingelogd · premium → Plus.
--    De catalogus (protocols-rijen) blijft publiek leesbaar (kaart + slotje).
-- ---------------------------------------------------------------------
drop policy if exists phases_public_read on public.protocol_phases;
drop policy if exists phases_tier_read on public.protocol_phases;
create policy phases_tier_read on public.protocol_phases
  for select using (
    public.is_admin()
    or exists (
      select 1 from public.protocols pr
      where pr.id = protocol_phases.protocol_id
        and pr.status = 'published'
        and case
          when coalesce(pr.requires_premium, false) or pr.access_tier = 'premium'
            then public.user_is_premium()
          when pr.access_tier = 'deep' or coalesce(pr.requires_deep_access, false)
            then auth.uid() is not null
          else true   -- free
        end
    )
  );

-- ---------------------------------------------------------------------
-- 4. Rustcode geeft 'deep' (geen premium). De code wordt aan het account
--    gekoppeld; verdieping is daarmee bereikbaar, intensief niet.
-- ---------------------------------------------------------------------
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
    for update;
  if not found or not r.active then return jsonb_build_object('ok', false, 'reason', 'ongeldig'); end if;
  if r.expires_at is not null and r.expires_at < now() then return jsonb_build_object('ok', false, 'reason', 'verlopen'); end if;
  if r.max_uses is not null and r.uses >= r.max_uses then return jsonb_build_object('ok', false, 'reason', 'op'); end if;
  if exists (
    select 1 from public.user_entitlements
    where user_id = auth.uid() and source = 'rustcode' and reference_id = r.id::text
  ) then
    return jsonb_build_object('ok', false, 'reason', 'al_gebruikt');
  end if;
  v_days := coalesce(r.days, 30);
  v_ends := now() + make_interval(days => v_days);
  insert into public.user_entitlements (user_id, entitlement_type, source, starts_at, ends_at, status, reference_id)
  values (auth.uid(), 'deep', 'rustcode', now(), v_ends, 'active', r.id::text);
  update public.access_codes set uses = uses + 1, updated_at = now() where id = r.id;
  return jsonb_build_object('ok', true, 'ends_at', v_ends, 'days', v_days);
end; $$;
grant execute on function public.redeem_rest_code(text) to authenticated;
revoke execute on function public.redeem_rest_code(text) from anon;

-- ---------------------------------------------------------------------
-- 5. Geen proefperiode meer (verdieping strikt via inloggen, intensief via
--    betaling): nieuwe accounts krijgen alleen een profiel, geen entitlement.
-- ---------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email, display_name)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'display_name', new.email))
  on conflict (id) do nothing;
  return new;
end; $$;

-- ---------------------------------------------------------------------
-- 6. Bestaande proef-/rustcode-entitlements omzetten naar 'deep' zodat ze
--    geen premium (intensieve) toegang meer geven. Betaalde/toegekende Plus
--    (mollie_payment, admin) blijft ongemoeid.
-- ---------------------------------------------------------------------
update public.user_entitlements
   set entitlement_type = 'deep', updated_at = now()
 where entitlement_type = 'premium'
   and source in ('trial','rustcode');

select 'Drie toegangslagen actief' as status;
