-- Restavia: e-mailadres in Contact + tagline in hoofdletters in "Over Restavia"
-- Eenmalig uitvoeren in de Supabase SQL Editor.
update public.app_settings
set value = E'Contact\n\nRestavia\nEen initiatief van Domein Stam\nStaverdenseweg 94\n8075 AS Elspeet\nrestavia@domeinstam.nl\n\n© 2026 Restavia (Domein Stam). Alle rechten voorbehouden.'
where key = 'contact_text';

update public.app_settings
set value = replace(value, 'Breathe. Feel. Flow.', 'BREATHE. FEEL. FLOW.')
where key = 'about_text';

select key, right(value, 140) from public.app_settings where key in ('about_text','contact_text');
