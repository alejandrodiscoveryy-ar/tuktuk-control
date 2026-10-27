-- TUKTUK / PR106. SOLO DEFINICION VERSIONADA; NO SE APLICA POR ESTE SCRIPT.
-- Mantiene las RPC v1 y los perfiles antiguos: el campo comienza NULL.
alter table public.driver_profiles
  add column if not exists identity_document_type text;

-- Los conductores existentes se eximen del NUEVO tipo sin quitar la
-- exigencia de ambas fotografias que ya tuvieran en su perfil.
-- La columna se crea nullable, se marca false SOLO a filas existentes y,
-- finalmente, pasa a true por defecto para altas posteriores.
-- Reejecutar esta migracion no cambia false/true ya asignados.
alter table public.driver_profiles
  add column if not exists identity_document_type_required boolean;
update public.driver_profiles
set identity_document_type_required = false
where identity_document_type_required is null;
alter table public.driver_profiles
  alter column identity_document_type_required set default true;
alter table public.driver_profiles
  alter column identity_document_type_required set not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'driver_identity_document_type_check'
      and conrelid = 'public.driver_profiles'::regclass
  ) then
    alter table public.driver_profiles
      add constraint driver_identity_document_type_check
      check (identity_document_type is null or
             identity_document_type in ('national_id', 'driver_license'));
  end if;
end;
$$;

-- Anade la propiedad al RPC de lectura existente sin modificar su firma.

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
    'document_type', (
      select d.identity_document_type
      from public.driver_profiles d
      where d.project_id = pid and d.user_id = actor
    ),
    'document_type_required', coalesce(
      (
        select d.identity_document_type_required
        from public.driver_profiles d
        where d.project_id = pid and d.user_id = actor
      ),
      true
    ),
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
-- Borrador privado separado: no hay que cambiar el contrato de borradores v1.
create or replace function public.save_my_marketplace_identity_document_type_draft(
  target_document_type text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  pid uuid;
  result jsonb;
begin
  if actor is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode = '42501';
  end if;
  if target_document_type is null or
     target_document_type not in ('national_id','driver_license') then
    raise exception 'INVALID_IDENTITY_DOCUMENT_TYPE' using errcode = '22023';
  end if;
  select id into strict pid from public.projects where slug = 'tuktuk-control';
  if exists (
    select 1 from public.driver_profiles d
    where d.project_id = pid and d.user_id = actor and d.status = 'suspended'
  ) then
    raise exception 'DRIVER_SUSPENDED' using errcode = '42501';
  end if;
  insert into public.marketplace_registration_drafts(project_id,user_id,scope,fields)
    values (pid,actor,'driver',
            jsonb_build_object('identity_document_type', target_document_type))
  on conflict (project_id,user_id,scope)
    do update set fields = public.marketplace_registration_drafts.fields || excluded.fields,
                  updated_at = now()
  returning fields into result;
  return result;
end;
$$;
revoke all on function public.save_my_marketplace_identity_document_type_draft(text)
  from public, anon;
grant execute on function public.save_my_marketplace_identity_document_type_draft(text)
  to authenticated;

-- Nueva RPC opt-in: clientes antiguos siguen usando save_my_marketplace_identity_documents.
-- Valida el usuario, tipo y propiedad de ambas fotos reutilizando la RPC v1.
-- El cambio entre tipos exige fotos NUEVAS para evitar clasificar las viejas
-- como si pertenecieran a un documento distinto.
create or replace function public.save_my_marketplace_identity_documents_v2(
  target_front_asset_id uuid,
  target_back_asset_id uuid,
  target_document_type text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  pid uuid;
  old_type text;
  old_front uuid;
  old_back uuid;
  docs_required boolean;
  saved jsonb;
begin
  if actor is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode = '42501';
  end if;
  if target_document_type is null or
     target_document_type not in ('national_id','driver_license') then
    raise exception 'INVALID_IDENTITY_DOCUMENT_TYPE' using errcode = '22023';
  end if;
  select id into strict pid from public.projects where slug = 'tuktuk-control';

  select d.identity_document_type, d.identity_front_asset_id,
         d.identity_back_asset_id, d.identity_docs_required
    into old_type, old_front, old_back, docs_required
  from public.driver_profiles d
  where d.project_id = pid and d.user_id = actor
    and d.status <> 'suspended'
  for update;
  if not found then
    raise exception 'DRIVER_PROFILE_NOT_AVAILABLE' using errcode = 'P0002';
  end if;
  if old_type is not null and old_type <> target_document_type
     and (old_front is not null or old_back is not null) then
    if target_front_asset_id is null or target_back_asset_id is null
       or target_front_asset_id is not distinct from old_front
       or target_back_asset_id is not distinct from old_back then
      raise exception 'DOCUMENT_PHOTOS_MUST_BE_REPLACED' using errcode = '22023';
    end if;
  end if;

  -- Si alguna foto nueva no pertenece a la cuenta, la RPC v1 revierte la transaccion.
  saved := public.save_my_marketplace_identity_documents(
    target_front_asset_id, target_back_asset_id);
  if docs_required and (saved->'front' is null or saved->'front' = 'null'::jsonb
      or saved->'back' is null or saved->'back' = 'null'::jsonb) then
    raise exception 'IDENTITY_DOCUMENT_BOTH_SIDES_REQUIRED' using errcode = '22023';
  end if;
  update public.driver_profiles d
  set identity_document_type = target_document_type, updated_at = now()
  where d.project_id = pid and d.user_id = actor and d.status <> 'suspended';
  return public.get_my_marketplace_identity_documents();
end;
$$;
revoke all on function public.save_my_marketplace_identity_documents_v2(uuid,uuid,text)
  from public, anon;
grant execute on function public.save_my_marketplace_identity_documents_v2(uuid,uuid,text)
  to authenticated;

-- GATE_PR106_DOCUMENT_TYPE_REQUIRED
-- Exime del tipo a perfiles ya existentes al migrar; las fotos conservan
-- el requisito anterior. Las altas posteriores deben elegir el tipo.
-- Misma firma original: preserva los llamadores de Trabajos.
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
             (d.identity_document_type_required = false or
              d.identity_document_type in ('national_id', 'driver_license')) and
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
