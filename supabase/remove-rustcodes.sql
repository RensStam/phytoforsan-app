-- =====================================================================
-- Restavia — rustcodes volledig verwijderen
-- Eenmalig uitvoeren in de Supabase SQL Editor (opnieuw uitvoeren is veilig).
--
-- Toegangsmodel hierna: gast (free) → gratis account (deep) → Restavia Plus
-- (premium) + admin. De algemene entitlement-structuur (user_entitlements,
-- get_user_access, user_is_premium, Plus/Mollie, proefperiode-ondersteuning)
-- blijft ONGEMOEID.
--
-- Gecontroleerde afhankelijkheden van access_codes (projectbreed):
--   • app (index.html): riep alleen redeem_rest_code aan → verwijderd
--   • backoffice (backend.html): tab "Rustcodes" → verwijderd
--   • functies: redeem_rest_code (+ oude redeem_access_code) → hieronder gedropt
--   • user_entitlements.reference_id: tekstveld, géén foreign key
--   • edge functions: geen verwijzingen
-- De tabel wordt alleen verwijderd als er daarna géén foreign keys of views
-- meer naar verwijzen; anders blijft hij staan en wordt hij als DEPRECATED
-- gemarkeerd.
-- =====================================================================

-- 1. Bestaande rustcode-entitlements (alfa) verwijderen
delete from public.user_entitlements where source = 'rustcode';

-- 2. Rustcode-functies verwijderen
drop function if exists public.redeem_rest_code(text);
drop function if exists public.redeem_access_code(text);

-- 3. access_codes: alleen verwijderen als niets er meer van afhangt
do $$
declare
  n_fk int := 0;
  n_view int := 0;
begin
  if to_regclass('public.access_codes') is null then
    raise notice 'access_codes bestaat al niet meer';
    return;
  end if;
  select count(*) into n_fk
    from pg_constraint
   where confrelid = 'public.access_codes'::regclass
     and conrelid <> 'public.access_codes'::regclass;
  select count(distinct r.ev_class) into n_view
    from pg_depend d
    join pg_rewrite r on r.oid = d.objid
   where d.refobjid = 'public.access_codes'::regclass
     and r.ev_class <> 'public.access_codes'::regclass;
  if n_fk = 0 and n_view = 0 then
    drop table public.access_codes;
    raise notice 'access_codes verwijderd';
  else
    comment on table public.access_codes is
      'DEPRECATED: rustcodes zijn uit Restavia verwijderd; niet meer gebruiken.';
    raise notice 'access_codes NIET verwijderd (% foreign keys, % views) — gemarkeerd als deprecated', n_fk, n_view;
  end if;
end $$;

-- 4. Documentatie van de toegestane entitlement-bronnen
comment on column public.user_entitlements.source is
  'trial | mollie_payment | google_play (toekomstig) | admin | manual';

-- 5. Controle
select
  to_regclass('public.access_codes') is null                                    as access_codes_verwijderd,
  (select count(*) from public.user_entitlements where source = 'rustcode')     as rustcode_entitlements,
  exists (select 1 from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
           where ns.nspname = 'public' and p.proname in ('redeem_rest_code','redeem_access_code')) as rustcode_functies_aanwezig;
