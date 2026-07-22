create table if not exists public.sync_entities (
  user_id uuid not null references auth.users(id) on delete cascade,
  vehicle_id text not null,
  entity_type text not null check (
    entity_type in ('dailyRecord', 'maintenance', 'vehicle', 'settings')
  ),
  entity_id text not null,
  device_id text not null default '',
  payload jsonb not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  primary key (user_id, entity_type, entity_id)
);

create index if not exists sync_entities_user_updated_idx
  on public.sync_entities (user_id, updated_at);

alter table public.sync_entities enable row level security;
alter table public.sync_entities replica identity full;

create policy "Users read only their synchronized data"
  on public.sync_entities
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users insert only their synchronized data"
  on public.sync_entities
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy "Users update only their synchronized data"
  on public.sync_entities
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Users delete only their synchronized data"
  on public.sync_entities
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);

grant select, insert, update, delete on public.sync_entities to authenticated;

alter publication supabase_realtime add table public.sync_entities;
