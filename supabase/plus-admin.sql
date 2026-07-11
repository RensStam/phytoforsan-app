-- =====================================================================
-- PhytoForsan Relax Plus — beheer: betalingen kunnen verwijderen
-- Voer dit uit in de Supabase SQL Editor (na plus.sql).
-- Alleen admins mogen betaalrecords verwijderen (bv. testbetalingen).
-- =====================================================================
drop policy if exists payments_admin_delete on public.payment_records;
create policy payments_admin_delete on public.payment_records
  for delete using (public.is_admin());

select 'Betalingenbeheer klaar' as status;
