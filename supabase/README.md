# Ascent cloud (Supabase)

Ascent works fully offline. A Supabase project adds online features; a
build without one shows no cloud surfaces at all (CLAUDE.md §7).

## What runs here
| Feature | Supabase piece |
|---|---|
| Sign-in | Auth, email one-time code (no passwords stored by Ascent) |
| Cloud backup | Storage bucket `backups`, private, one folder per user, files encrypted on the phone |

## One-time setup
1. Create a project at supabase.com (free tier is enough to start).
2. **Auth → Providers → Email**: keep Email on. Under **Auth → Email
   Templates → Magic Link**, make the email show the code: include
   `{{ .Token }}` (Ascent signs in with the 6-digit code, not a link).
3. Apply the migrations, either with the CLI
   (`supabase link --project-ref <ref>` then `supabase db push`) or by
   pasting `migrations/*.sql` into **SQL Editor** in order.
4. **Project Settings → API**: copy the Project URL and the
   publishable (anon) key. Both are safe to ship; row-level security and
   the storage policies protect the data. Never put the `service_role` key
   in the app.

## Build with the cloud on
```bash
flutter run --dart-define=SUPABASE_URL=https://<ref>.supabase.co --dart-define=SUPABASE_ANON_KEY=<publishable key>
```
Release builds take the same two `--dart-define`s. Without them the app is
the offline app, unchanged.
