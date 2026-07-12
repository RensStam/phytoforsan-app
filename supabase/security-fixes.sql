-- =====================================================================
-- PhytoForsan — beveiligingsfixes (audit 2026-07-12)
-- Voer dit uit in de Supabase SQL Editor. Opnieuw uitvoeren is veilig.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. KRITIEK — eigen profiel-update kon het toegangsniveau verhogen.
-- De oude policy pinde alleen 'role'; een ingelogde gebruiker kon via de
-- REST-API zijn eigen access_level op 'premium' (of 'admin') zetten en zo
-- gratis alle betaalde inhoud krijgen. Nu zijn role, access_level én email
-- onveranderbaar voor de gebruiker zelf (alleen admin mag ze wijzigen).
-- ---------------------------------------------------------------------
drop policy if exists profiles_self_update on public.profiles;
create policy profiles_self_update on public.profiles
  for update using (id = auth.uid())
  with check (
    id = auth.uid()
    and role         = (select p.role         from public.profiles p where p.id = auth.uid())
    and access_level = (select p.access_level from public.profiles p where p.id = auth.uid())
    and email        = (select p.email        from public.profiles p where p.id = auth.uid())
  );

-- ---------------------------------------------------------------------
-- 2. Oude apparaat-codefunctie verwijderen.
-- De app gebruikt alleen nog redeem_rest_code (account-gebonden). De oude
-- functie was voor iedereen (ook gasten) aanroepbaar en verhoogde bij elke
-- gok het gebruik van een code — daarmee kon een kwaadwillende codes
-- brute-forcen of het maximale gebruik van een geldige code "opbranden".
-- ---------------------------------------------------------------------
drop function if exists public.redeem_access_code(text);

-- ---------------------------------------------------------------------
-- 3. Rustcode verzilveren: rij vergrendelen tijdens de controle.
-- Voorkomt dat twee gelijktijdige verzoeken samen het maximale gebruik
-- van een code overschrijden (race condition).
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
    for update;   -- lock: geen gelijktijdige dubbele verzilvering
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
  values (auth.uid(), 'premium', 'rustcode', now(), v_ends, 'active', r.id::text);
  update public.access_codes set uses = uses + 1, updated_at = now() where id = r.id;
  return jsonb_build_object('ok', true, 'ends_at', v_ends, 'days', v_days);
end; $$;
grant execute on function public.redeem_rest_code(text) to authenticated;
revoke execute on function public.redeem_rest_code(text) from anon;

-- ---------------------------------------------------------------------
-- 4. Gaststatistiek begrenzen tegen vervuiling.
-- Iedereen mag (bewust) anoniem sessies registreren; deze grenzen houden
-- de invoer gezond: maximaal 6 uur per sessie, nette veldlengtes.
-- ---------------------------------------------------------------------
alter table public.usage_sessions drop constraint if exists usage_sessions_sane;
alter table public.usage_sessions add constraint usage_sessions_sane check (
  seconds >= 0 and seconds <= 21600
  and char_length(device_id) between 1 and 64
  and (protocol_slug is null or char_length(protocol_slug) <= 80)
);

select 'Beveiligingsfixes toegepast' as status;
