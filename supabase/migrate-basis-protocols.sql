-- =====================================================================
-- PhytoForsan — basis-ademprotocollen naar exacte cycli zetten
-- Voer dit uit NA exact-protocols.sql. Opnieuw uitvoeren is veilig.
--
-- Zet per protocol het aantal ademcycli en de exacte fase-duur (= cycli ×
-- cyclusduur). De afsluitrust blijft leeg → de app gebruikt de globale
-- standaard (15s). De frontend eindigt daardoor exact op een rust, gevolgd
-- door het eindbericht.
-- =====================================================================

-- Lange Uitademing: cyclus 4+1+6+1 = 12s → 25 cycli = 300s
update public.protocol_phases ph
   set breath_cycles = 25, duration_seconds = 300
  from public.protocols p
 where ph.protocol_id = p.id and p.slug = 'longExhale' and ph.type = 'breath';

-- Resonantie Adem: cyclus 5+0+5+0 = 10s → 30 cycli = 300s
update public.protocol_phases ph
   set breath_cycles = 30, duration_seconds = 300
  from public.protocols p
 where ph.protocol_id = p.id and p.slug = 'resonanceBreath' and ph.type = 'breath';

-- Slaapadem: cyclus 4+1+8+2 = 15s → 40 cycli = 600s
update public.protocol_phases ph
   set breath_cycles = 40, duration_seconds = 600
  from public.protocols p
 where ph.protocol_id = p.id and p.slug = 'sleepBreath' and ph.type = 'breath';

-- Vloeiende Adem: cyclus 4+0+4+0 = 8s → 38 cycli = 304s (was 37,5 → afgerond)
update public.protocol_phases ph
   set breath_cycles = 38, duration_seconds = 304
  from public.protocols p
 where ph.protocol_id = p.id and p.slug = 'flowingBreath' and ph.type = 'breath';

select slug, ph.type, ph.breath_cycles, ph.duration_seconds
  from public.protocol_phases ph
  join public.protocols p on p.id = ph.protocol_id
 where p.slug in ('longExhale','resonanceBreath','sleepBreath','flowingBreath')
 order by p.slug;
