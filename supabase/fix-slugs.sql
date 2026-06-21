-- =====================================================================
-- PhytoForsan — herstel technische slugs (titels blijven ongewijzigd)
-- Voer dit uit in de Supabase SQL Editor. Zet de slug terug naar de vaste ID
-- die de app koppelt aan tegels, klank en beveiliging.
-- Veilig: alleen de slug verandert; titel/teksten/fases blijven zoals ze zijn.
-- =====================================================================
update public.protocols set slug='longExhale'            where slug='lange-uitademing';
update public.protocols set slug='resonanceBreath'       where slug='resonantie-adem';
update public.protocols set slug='sleepBreath'           where slug='slaapadem';
update public.protocols set slug='flowingBreath'         where slug='vloeiende-adem';
update public.protocols set slug='bellyRegulationBreath' where slug='buikregulatie-adem';
update public.protocols set slug='bijPiekeren'           where slug='bij-piekeren';
update public.protocols set slug='lichaamTotRust'        where slug='lichaam-tot-rust';
update public.protocols set slug='relax'                 where slug='relax-moment';
update public.protocols set slug='vanOnrustNaarRust'     where slug='van-onrust-naar-rust';
update public.protocols set slug='lang'                  where slug='deep-relax';
update public.protocols set slug='focus'                 where slug='korte-reset';
update public.protocols set slug='focusReset'            where slug='focus-reset';
update public.protocols set slug='herstel'               where slug='stillness-flow';
update public.protocols set slug='vanEmotiesNaarOntspanning' where slug='van-emoties-naar-ontspanning';
update public.protocols set slug='bijOverprikkeling'     where slug='bij-overprikkeling';
update public.protocols set slug='voorHetSlapen'         where slug='voor-het-slapen';
update public.protocols set slug='nachtelijkWakkerWorden' where slug='nachtelijk-wakker-worden';
update public.protocols set slug='holotropicBreathTest'  where slug='holotropische-ademtest';
update public.protocols set slug='activeBreathTest'      where slug='actieve-ademtest';
-- maen / amen / om / herstelmoment hadden al de juiste slug.

-- Controle: bekijk het resultaat
select slug, title, status, access_tier from public.protocols order by sort_order;
