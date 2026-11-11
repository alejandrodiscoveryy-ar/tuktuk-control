\set ON_ERROR_STOP on
-- PostgreSQL aislado: estructura mínima equivalente a la sincronización.
create role authenticated nologin;
create role anon nologin;
create schema auth;
create schema app_private;
create table auth.users(id uuid primary key);
create function auth.uid()
returns uuid language sql stable set search_path = ''
as $$ select nullif(pg_catalog.current_setting('request.jwt.claim.sub', true),'')::uuid $$;
create function app_private.current_user_has_control_write_entitlement()
returns boolean language sql stable as $$ select auth.uid() is not null $$;

insert into auth.users(id) values
('11111111-1111-4111-8111-111111111111'),
('22222222-2222-4222-8222-222222222222');

create table public.sync_entities (
  user_id uuid not null references auth.users(id) on delete cascade,
  vehicle_id text not null,
  entity_type text not null check (entity_type in
    ('dailyRecord','maintenance','vehicle','settings')),
  entity_id text not null,
  device_id text not null default '',
  payload jsonb not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  primary key (user_id, entity_type, entity_id)
);
create index sync_entities_user_updated_idx
  on public.sync_entities(user_id, updated_at);
alter table public.sync_entities enable row level security;
create policy select_owner on public.sync_entities
  for select to authenticated using (auth.uid() = user_id);
create policy insert_owner on public.sync_entities
  for insert to authenticated with check
  (auth.uid() = user_id and app_private.current_user_has_control_write_entitlement());
create policy update_owner on public.sync_entities
  for update to authenticated using
  (auth.uid() = user_id and app_private.current_user_has_control_write_entitlement())
  with check
  (auth.uid() = user_id and app_private.current_user_has_control_write_entitlement());
create policy delete_owner on public.sync_entities
  for delete to authenticated using
  (auth.uid() = user_id and app_private.current_user_has_control_write_entitlement());
grant usage on schema public, auth, app_private to authenticated;
grant select, insert, update, delete on public.sync_entities to authenticated;
