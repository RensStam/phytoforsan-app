-- =====================================================================
-- PhytoForsan — opslag-bucket voor media (audio + afbeeldingen)
-- Voer dit uit in de Supabase SQL Editor.
-- Bestanden zijn publiek leesbaar (zodat de app ze kan afspelen/tonen);
-- alleen admins mogen uploaden/wijzigen/verwijderen.
-- =====================================================================
insert into storage.buckets (id, name, public)
values ('media', 'media', true)
on conflict (id) do nothing;

-- Publiek lezen
drop policy if exists "media public read" on storage.objects;
create policy "media public read" on storage.objects
  for select using (bucket_id = 'media');

-- Alleen admins schrijven/wijzigen/verwijderen
drop policy if exists "media admin insert" on storage.objects;
create policy "media admin insert" on storage.objects
  for insert with check (bucket_id = 'media' and public.is_admin());

drop policy if exists "media admin update" on storage.objects;
create policy "media admin update" on storage.objects
  for update using (bucket_id = 'media' and public.is_admin());

drop policy if exists "media admin delete" on storage.objects;
create policy "media admin delete" on storage.objects
  for delete using (bucket_id = 'media' and public.is_admin());
