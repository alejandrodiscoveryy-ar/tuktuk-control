-- TUKTUK / PR106. SOLO DEFINICION VERSIONADA; NO SE APLICA POR ESTE SCRIPT.
-- Mantiene las RPC v1 y los perfiles antiguos: el campo comienza NULL.
alter table public.driver_profiles
  add column if not exists identity_document_type text;

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
