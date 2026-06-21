-- =====================================================================
-- PhytoForsan — gebruiker veilig kunnen verwijderen vanuit het backend
-- Voer dit uit in de Supabase SQL Editor.
-- Verwijdert het account uit auth.users (profiel cascadet mee). Alleen admins
-- mogen dit; de service-role key blijft uit de frontend.
-- =====================================================================
create or replace function public.admin_delete_user(p_user uuid)
returns void
language plpgsql security definer set search_path = public, auth as $$
begin
  if not public.is_admin() then
    raise exception 'Niet geautoriseerd';
  end if;
  if p_user = auth.uid() then
    raise exception 'Je kunt je eigen account niet verwijderen';
  end if;
  delete from auth.users where id = p_user;  -- profiel + user_access cascaden mee
end; $$;

revoke all on function public.admin_delete_user(uuid) from public, anon;
grant execute on function public.admin_delete_user(uuid) to authenticated;
