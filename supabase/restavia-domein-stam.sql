-- Restavia: vermelding "een initiatief van Domein Stam" in de opgeslagen teksten
-- Eenmalig uitvoeren in de Supabase SQL Editor.
update public.app_settings
set value = value || E'

Restavia is een initiatief van Domein Stam.'
where key = 'about_text' and value not ilike '%Domein Stam%';

update public.app_settings
set value = E'Contact

Restavia
Een initiatief van Domein Stam
Staverdenseweg 94
8075 AS Elspeet

© 2026 Restavia (Domein Stam). Alle rechten voorbehouden.'
where key = 'contact_text';

select key, right(value, 160) from public.app_settings where key in ('about_text','contact_text');
