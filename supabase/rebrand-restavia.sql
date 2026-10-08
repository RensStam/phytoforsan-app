-- =====================================================================
-- Restavia — rebranding van opgeslagen teksten in de database
-- Voer dit één keer uit in de Supabase SQL Editor.
-- Past ALLEEN zichtbare merkteksten aan; slugs, id's, toegangsniveaus,
-- betalingen en gebruikersdata blijven ongewijzigd.
-- =====================================================================

-- 1. App-instellingen (teksten die de app op het profielscherm toont)
update public.app_settings set value = 'Restavia' where key = 'app_name';

update public.app_settings
set value = 'Contact

Restavia
Contactgegevens volgen binnenkort.

© 2026 Restavia. Alle rechten voorbehouden.'
where key = 'contact_text' and value ilike '%phyto%';

update public.app_settings
set value =
  replace(replace(replace(replace(replace(value,
    E'PhytoForsan Relax App\nEen initiatief van Rens Stam voor PhytoForsan.nl.', E'Restavia\nBreathe. Feel. Flow.'),
    E'PhytoForsan Relax App\r\nEen initiatief van Rens Stam voor PhytoForsan.nl.', E'Restavia\r\nBreathe. Feel. Flow.'),
    'PhytoForsan Relax Plus', 'Restavia Plus'),
    'PhytoForsan Relax App', 'Restavia'),
    'PhytoForsan Relax', 'Restavia')
where value ilike '%phyto%';

-- 2. Protocolteksten (alleen merkverwijzingen)
update public.protocols set
  short_description = replace(replace(replace(short_description, 'PhytoForsan Relax Plus','Restavia Plus'), 'PhytoForsan Relax','Restavia'), 'het PhytoForsan-gevoel','een rustig gevoel'),
  long_description  = replace(replace(replace(replace(long_description,
                        'Een kalme digitale aanvulling op het PhytoForsan-gevoel: vertragen', 'Een kalme digitale pauze: vertragen'),
                        'PhytoForsan Relax Plus','Restavia Plus'), 'PhytoForsan Relax','Restavia'), 'het PhytoForsan-gevoel','een rustig gevoel'),
  evidence_text     = replace(replace(evidence_text, 'PhytoForsan Relax','Restavia'), 'PhytoForsan','Restavia'),
  safety_text       = replace(replace(safety_text,   'PhytoForsan Relax','Restavia'), 'PhytoForsan','Restavia'),
  closing_text      = replace(replace(closing_text,  'PhytoForsan Relax','Restavia'), 'PhytoForsan','Restavia')
where coalesce(short_description,'') || coalesce(long_description,'') || coalesce(evidence_text,'')
      || coalesce(safety_text,'') || coalesce(closing_text,'') ilike '%phyto%';

-- 3. Controle: wat bevat nog "phyto"?
select 'app_settings' as tabel, key as id, left(value, 120) as tekst from public.app_settings where value ilike '%phyto%'
union all
select 'protocols', slug, left(coalesce(short_description,'') || ' | ' || coalesce(long_description,''), 120)
from public.protocols
where coalesce(short_description,'') || coalesce(long_description,'') || coalesce(evidence_text,'')
      || coalesce(safety_text,'') || coalesce(closing_text,'') ilike '%phyto%';
