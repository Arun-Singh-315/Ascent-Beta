-- Ascent cloud backups (CLAUDE.md §7).
-- A private bucket; each person can only touch files under their own
-- folder: backups/<auth.uid()>/<file>. Files are already encrypted on the
-- phone (AES-256-GCM, password never leaves the device).

insert into storage.buckets (id, name, public, file_size_limit)
values ('backups', 'backups', false, 104857600) -- 100 MB per file
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit;

drop policy if exists "backups: owner reads" on storage.objects;
drop policy if exists "backups: owner uploads" on storage.objects;
drop policy if exists "backups: owner updates" on storage.objects;
drop policy if exists "backups: owner deletes" on storage.objects;

create policy "backups: owner reads" on storage.objects
  for select to authenticated
  using (bucket_id = 'backups'
         and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "backups: owner uploads" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'backups'
              and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "backups: owner updates" on storage.objects
  for update to authenticated
  using (bucket_id = 'backups'
         and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "backups: owner deletes" on storage.objects
  for delete to authenticated
  using (bucket_id = 'backups'
         and (storage.foldername(name))[1] = (select auth.uid())::text);
