-- =====================================================================
-- Helperfunctie voor de Edge Function "notify-existing-account".
--
-- Controleert of een e-mailadres al een account heeft in auth.users.
-- Alleen de service-role (dus alleen de Edge Function, nooit de app zelf
-- of een bezoeker) mag dit aanroepen -- zo blijft het geen manier om van
-- buitenaf te ontdekken welke e-mailadressen al geregistreerd zijn.
-- =====================================================================
create or replace function public.email_has_account(check_email text)
returns boolean
language sql security definer
set search_path = public, auth
as $$
  select exists(
    select 1 from auth.users
    where lower(email) = lower(check_email)
  );
$$;

revoke all on function public.email_has_account(text) from public, anon, authenticated;
grant execute on function public.email_has_account(text) to service_role;
