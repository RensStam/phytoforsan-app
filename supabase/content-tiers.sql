-- =====================================================================
-- PhytoForsan — protocolinhoud per toegangsniveau (RLS)
-- Voer dit uit in de Supabase SQL Editor (ná plus.sql).
--
-- Vanaf nu levert het backend de verdiepings-/premiumprotocollen (en hun
-- fases) uitsluitend aan ingelogde gebruikers met een actieve entitlement
-- (proefperiode, rustcode of Plus), een handmatig niveau of adminrol.
-- Vrije protocollen blijven voor iedereen leesbaar, ook voor gasten.
-- =====================================================================

-- Heeft de huidige gebruiker extra toegang (trial/rustcode/Plus/handmatig/admin)?
create or replace function public.user_has_extra_access()
returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid()
        and (p.role = 'admin' or p.access_level in ('deep','premium','admin'))
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
grant execute on function public.user_has_extra_access() to anon, authenticated;

-- Protocollen: vrij niveau voor iedereen; extra niveaus alleen met toegang.
drop policy if exists protocols_public_read on public.protocols;
drop policy if exists protocols_tier_read on public.protocols;
create policy protocols_tier_read on public.protocols
  for select using (
    public.is_admin()
    or (
      status = 'published' and (
        (coalesce(access_tier, 'free') = 'free'
          and not coalesce(requires_deep_access, false)
          and not coalesce(requires_premium, false))
        or public.user_has_extra_access()
      )
    )
  );

-- Fases: leesbaar wanneer het bijbehorende protocol leesbaar is.
drop policy if exists phases_public_read on public.protocol_phases;
drop policy if exists phases_tier_read on public.protocol_phases;
create policy phases_tier_read on public.protocol_phases
  for select using (
    public.is_admin()
    or exists (
      select 1 from public.protocols pr
      where pr.id = protocol_phases.protocol_id
        and pr.status = 'published'
        and (
          (coalesce(pr.access_tier, 'free') = 'free'
            and not coalesce(pr.requires_deep_access, false)
            and not coalesce(pr.requires_premium, false))
          or public.user_has_extra_access()
        )
    )
  );

select 'Protocolinhoud per toegangsniveau actief' as status;
