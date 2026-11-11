-- Mirror of the migration already APPLIED in Supabase on 2026-11-11.
-- Supabase migration history: 20261111111039
-- Do not re-run manually with a different migration version.
-- Approved scope: privilege hardening on public.sync_entities only.
-- Keeps RLS, DML (select/insert/update/delete) and existing triggers unchanged.

revoke truncate, trigger on table public.sync_entities from authenticated;
revoke trigger on table public.sync_entities from anon;
