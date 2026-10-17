-- TUKTUK: documentos privados de identidad del conductor.
-- No aplicar automáticamente en producción.
-- Compatible con conductores ya registrados.

alter table public.driver_profiles
  add column if not exists identity_front_asset_id uuid,
  add column if not exists identity_back_asset_id uuid;

-- Backfill sin bloqueo: quienes ya tienen perfil quedan exentos.
alter table public.driver_profiles
  add column if not exists identity_docs_required boolean not null default false;

-- Solo perfiles creados despues de la migracion tendran el requisito.
alter table public.driver_profiles
  alter column identity_docs_required set default true;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'driver_identity_front_asset_fk'
      and conrelid = 'public.driver_profiles'::regclass
  ) then
    alter table public.driver_profiles
      add constraint driver_identity_front_asset_fk
      foreign key (project_id, identity_front_asset_id)
      references public.media_assets(project_id, id)
      on delete restrict;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'driver_identity_back_asset_fk'
      and conrelid = 'public.driver_profiles'::regclass
  ) then
    alter table public.driver_profiles
      add constraint driver_identity_back_asset_fk
      foreign key (project_id, identity_back_asset_id)
      references public.media_assets(project_id, id)
      on delete restrict;
  end if;
end;
$$;

-- Los documentos no comparten el bucket de fotos del Marketplace.
insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'marketplace-identity',
  'marketplace-identity',
  false,
  5242880,
  array['image/jpeg']
)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

create or replace function app_private.marketplace_identity_path_is_prepared(
  target_bucket text,
  target_path text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null
    and target_bucket = 'marketplace-identity'
    and exists (
      select 1
      from public.media_assets a
      join public.projects p
        on p.id = a.project_id
      where p.slug = 'tuktuk-control'
        and a.owner_user_id = auth.uid()
        and a.storage_bucket = target_bucket
        and a.storage_path = target_path
        and a.asset_kind in (
          'identity_front',
          'identity_back'
        )
        and a.status = 'pending'
    );
$$;

create or replace function app_private.marketplace_identity_path_is_owned(
  target_bucket text,
  target_path text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null
    and target_bucket = 'marketplace-identity'
    and exists (
      select 1
      from public.media_assets a
      join public.projects p
        on p.id = a.project_id
      where p.slug = 'tuktuk-control'
        and a.owner_user_id = auth.uid()
        and a.storage_bucket = target_bucket
        and a.storage_path = target_path
        and a.asset_kind in (
          'identity_front',
          'identity_back'
        )
        and a.status in ('pending', 'available')
    );
$$;

revoke all on function
  app_private.marketplace_identity_path_is_prepared(text,text)
  from public, anon;

revoke all on function
  app_private.marketplace_identity_path_is_owned(text,text)
  from public, anon;

grant execute on function
  app_private.marketplace_identity_path_is_prepared(text,text)
  to authenticated;

grant execute on function
  app_private.marketplace_identity_path_is_owned(text,text)
  to authenticated;

drop policy if exists
  "identity documents prepared insert"
  on storage.objects;

create policy "identity documents prepared insert"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'marketplace-identity'
  and app_private.marketplace_identity_path_is_prepared(
    bucket_id,
    name
  )
);

drop policy if exists
  "identity documents owner select"
  on storage.objects;

create policy "identity documents owner select"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'marketplace-identity'
  and app_private.marketplace_identity_path_is_owned(
    bucket_id,
    name
  )
);

-- Preparación de imagen privada con clave de idempotencia.
create or replace function public.prepare_my_marketplace_identity_upload(
  target_side text,
  target_mime_type text,
  target_byte_size bigint,
  target_sha256 text,
  target_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  pid uuid;
  kind text;
  storage_key text;
  asset public.media_assets%rowtype;
begin
  if actor is null then
    raise exception 'AUTHENTICATION_REQUIRED'
      using errcode = '42501';
  end if;

  if target_side not in ('front', 'back')
     or target_mime_type <> 'image/jpeg'
     or target_byte_size is null
     or target_byte_size < 1
     or target_byte_size > 5242880
     or target_sha256 !~ '^[0-9a-fA-F]{64}$'
     or target_idempotency_key is null then
    raise exception 'INVALID_IDENTITY_UPLOAD'
      using errcode = '22023';
  end if;

  kind := 'identity_' || target_side;

  select id into strict pid
  from public.projects
  where slug = 'tuktuk-control';

  storage_key :=
    actor::text || '/' ||
    target_idempotency_key::text || '.jpg';

  select *
  into asset
  from public.media_assets
  where project_id = pid
    and storage_bucket = 'marketplace-identity'
    and storage_path = storage_key
  for update;

  if found then
    if asset.owner_user_id <> actor
       or asset.asset_kind <> kind
       or asset.mime_type <> 'image/jpeg'
       or asset.byte_size <> target_byte_size
       or asset.sha256 <> lower(target_sha256) then
      raise exception 'IDENTITY_UPLOAD_KEY_REUSED'
        using errcode = '22023';
    end if;
  else
    insert into public.media_assets (
      project_id,
      owner_user_id,
      asset_kind,
      storage_bucket,
      storage_path,
      mime_type,
      byte_size,
      sha256,
      status
    )
    values (
      pid,
      actor,
      kind,
      'marketplace-identity',
      storage_key,
      'image/jpeg',
      target_byte_size,
      lower(target_sha256),
      'pending'
    )
    returning * into asset;
  end if;

  return jsonb_build_object(
    'asset_id', asset.id,
    'storage_bucket', asset.storage_bucket,
    'storage_path', asset.storage_path,
    'status', asset.status
  );
end;
$$;

revoke all on function
  public.prepare_my_marketplace_identity_upload(
    text,text,bigint,text,uuid
  )
  from public, anon;

grant execute on function
  public.prepare_my_marketplace_identity_upload(
    text,text,bigint,text,uuid
  )
  to authenticated;

create or replace function public.finalize_my_marketplace_identity_upload(
  target_asset_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  asset public.media_assets%rowtype;
begin
  if actor is null then
    raise exception 'AUTHENTICATION_REQUIRED'
      using errcode = '42501';
  end if;

  select a.*
  into asset
  from public.media_assets a
  join public.projects p
    on p.id = a.project_id
  where p.slug = 'tuktuk-control'
    and a.id = target_asset_id
    and a.owner_user_id = actor
    and a.storage_bucket = 'marketplace-identity'
    and a.asset_kind in (
      'identity_front',
      'identity_back'
    )
  for update;

  if not found then
    raise exception 'IDENTITY_ASSET_NOT_FOUND'
      using errcode = 'P0002';
  end if;

  if asset.status = 'pending' then
    if not exists (
      select 1
      from storage.objects o
      where o.bucket_id = asset.storage_bucket
        and o.name = asset.storage_path
    ) then
      raise exception 'IDENTITY_IMAGE_NOT_UPLOADED'
        using errcode = 'P0002';
    end if;

    update public.media_assets
    set status = 'available'
    where id = asset.id
    returning * into asset;
  end if;

  if asset.status <> 'available' then
    raise exception 'IDENTITY_IMAGE_NOT_AVAILABLE'
      using errcode = '22023';
  end if;

  return jsonb_build_object(
    'asset_id', asset.id,
    'storage_bucket', asset.storage_bucket,
    'storage_path', asset.storage_path,
    'status', asset.status
  );
end;
$$;

revoke all on function
  public.finalize_my_marketplace_identity_upload(uuid)
  from public, anon;

grant execute on function
  public.finalize_my_marketplace_identity_upload(uuid)
  to authenticated;

-- Consulta exclusiva del propietario.
create or replace function public.get_my_marketplace_identity_documents()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  pid uuid;
  front_id uuid;
  back_id uuid;
begin
  if actor is null then
    raise exception 'AUTHENTICATION_REQUIRED'
      using errcode = '42501';
  end if;

  select id into strict pid
  from public.projects
  where slug = 'tuktuk-control';

  select
    d.identity_front_asset_id,
    d.identity_back_asset_id
  into front_id, back_id
  from public.driver_profiles d
  where d.project_id = pid
    and d.user_id = actor;

  return jsonb_build_object(
    'required', coalesce(
      (
        select d.identity_docs_required
        from public.driver_profiles d
        where d.project_id = pid and d.user_id = actor
      ),
      true
    ),
    'front', (
      select jsonb_build_object(
        'asset_id', a.id,
        'storage_bucket', a.storage_bucket,
        'storage_path', a.storage_path,
        'status', a.status
      )
      from public.media_assets a
      where a.project_id = pid
        and a.id = front_id
        and a.owner_user_id = actor
        and a.asset_kind = 'identity_front'
        and a.storage_bucket = 'marketplace-identity'
        and a.status = 'available'
    ),
    'back', (
      select jsonb_build_object(
        'asset_id', a.id,
        'storage_bucket', a.storage_bucket,
        'storage_path', a.storage_path,
        'status', a.status
      )
      from public.media_assets a
      where a.project_id = pid
        and a.id = back_id
        and a.owner_user_id = actor
        and a.asset_kind = 'identity_back'
        and a.storage_bucket = 'marketplace-identity'
        and a.status = 'available'
    )
  );
end;
$$;

revoke all on function
  public.get_my_marketplace_identity_documents()
  from public, anon;

grant execute on function
  public.get_my_marketplace_identity_documents()
  to authenticated;

-- Guarda cada cara de forma independiente.
create or replace function public.save_my_marketplace_identity_documents(
  target_front_asset_id uuid,
  target_back_asset_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  pid uuid;
begin
  if actor is null then
    raise exception 'AUTHENTICATION_REQUIRED'
      using errcode = '42501';
  end if;

  select id into strict pid
  from public.projects
  where slug = 'tuktuk-control';

  if target_front_asset_id is not null
     and not exists (
       select 1
       from public.media_assets a
       where a.project_id = pid
         and a.id = target_front_asset_id
         and a.owner_user_id = actor
         and a.asset_kind = 'identity_front'
         and a.storage_bucket = 'marketplace-identity'
         and a.status = 'available'
     ) then
    raise exception 'INVALID_IDENTITY_FRONT'
      using errcode = '22023';
  end if;

  if target_back_asset_id is not null
     and not exists (
       select 1
       from public.media_assets a
       where a.project_id = pid
         and a.id = target_back_asset_id
         and a.owner_user_id = actor
         and a.asset_kind = 'identity_back'
         and a.storage_bucket = 'marketplace-identity'
         and a.status = 'available'
     ) then
    raise exception 'INVALID_IDENTITY_BACK'
      using errcode = '22023';
  end if;

  update public.driver_profiles d
  set
    identity_front_asset_id = coalesce(
      target_front_asset_id,
      d.identity_front_asset_id
    ),
    identity_back_asset_id = coalesce(
      target_back_asset_id,
      d.identity_back_asset_id
    ),
    updated_at = now()
  where d.project_id = pid
    and d.user_id = actor
    and d.status <> 'suspended';

  if not found then
    raise exception 'DRIVER_PROFILE_NOT_AVAILABLE'
      using errcode = 'P0002';
  end if;

  return public.get_my_marketplace_identity_documents();
end;
$$;

revoke all on function
  public.save_my_marketplace_identity_documents(uuid,uuid)
  from public, anon;

grant execute on function
  public.save_my_marketplace_identity_documents(uuid,uuid)
  to authenticated;
-- El acceso al trabajo usa esta misma funcion. Los conductores previos
-- conservan su acceso; los nuevos necesitan ambas caras verificadas.
create or replace function app_private.marketplace_onboarding_requirements_complete(
  target_user_id uuid,
  target_vehicle_id text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select target_user_id is not null
     and target_vehicle_id is not null
     and exists (
       select 1
       from public.profiles p
       join public.driver_profiles d on d.user_id=p.id
       join public.projects project on project.id=d.project_id
        and project.slug='tuktuk-control'
       join public.media_assets dp on dp.project_id=d.project_id
        and dp.id=d.photo_asset_id and dp.owner_user_id=d.user_id
        and dp.status='available'
       join public.driver_vehicle_assignments a on a.project_id=d.project_id
        and a.driver_user_id=d.user_id and a.vehicle_id=target_vehicle_id
        and a.is_active
       join public.vehicles v on v.project_id=d.project_id and v.id=a.vehicle_id
        and v.deleted_at is null and v.marketplace_status<>'suspended'
       join public.media_assets vp on vp.project_id=v.project_id
        and vp.id=v.main_photo_asset_id and vp.owner_user_id=v.owner_user_id
        and vp.status='available'
       where d.user_id=target_user_id
         and d.status<>'suspended' and d.suspended_at is null
         and nullif(btrim(p.display_name),'') is not null
         and p.phone ~ '^[+][1-9][0-9]{7,14}$'
         and nullif(btrim(v.category_code),'') is not null
         and nullif(btrim(v.propulsion_code),'') is not null
         and nullif(btrim(v.brand),'') is not null
         and nullif(btrim(v.model),'') is not null
         and exists (
           select 1 from public.vehicle_services vs
           join public.service_types st on st.project_id=vs.project_id
            and st.code=vs.service_code and st.active
           where vs.project_id=v.project_id and vs.vehicle_id=v.id and vs.enabled
         )
         and (
           not exists (
             select 1 from public.vehicle_services vs
             where vs.project_id=v.project_id and vs.vehicle_id=v.id
               and vs.enabled and vs.service_code in ('passenger','tourism')
           ) or coalesce(v.passenger_capacity,0)>0
         )
         and (
           not exists (
             select 1 from public.vehicle_services vs
             where vs.project_id=v.project_id and vs.vehicle_id=v.id
               and vs.enabled and vs.service_code='cargo'
           ) or greatest(
             coalesce(v.cargo_capacity_kg,0),coalesce(v.cargo_volume_m3,0),
             coalesce(v.cargo_length_cm,0),coalesce(v.cargo_width_cm,0),
             coalesce(v.cargo_height_cm,0)
           )>0
         )
         and (
           d.identity_docs_required=false or (
             exists (
               select 1 from public.media_assets f
               where f.project_id=d.project_id and f.id=d.identity_front_asset_id
                 and f.owner_user_id=d.user_id and f.asset_kind='identity_front'
                 and f.storage_bucket='marketplace-identity' and f.status='available'
             ) and exists (
               select 1 from public.media_assets b
               where b.project_id=d.project_id and b.id=d.identity_back_asset_id
                 and b.owner_user_id=d.user_id and b.asset_kind='identity_back'
                 and b.storage_bucket='marketplace-identity' and b.status='available'
             )
           )
         )
     );
$$;