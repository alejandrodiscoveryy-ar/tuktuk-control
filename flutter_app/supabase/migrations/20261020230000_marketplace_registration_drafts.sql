-- Borradores privados por cuenta y vehículo; NO cambia activación de conductores.
create table if not exists public.marketplace_registration_drafts (
  project_id uuid not null references public.projects(id),
  user_id uuid not null references auth.users(id) on delete cascade,
  scope text not null check (scope = 'driver' or scope like 'vehicle:%'),
  fields jsonb not null default '{}'::jsonb check (jsonb_typeof(fields) = 'object'),
  updated_at timestamptz not null default now(),
  primary key (project_id, user_id, scope)
);
alter table public.marketplace_registration_drafts enable row level security;
revoke all on public.marketplace_registration_drafts from public, anon, authenticated;
-- Únicamente RPC security definer verificadas; no exponer datos en vistas.

create or replace function public.get_my_marketplace_registration_drafts()
returns jsonb language plpgsql stable security definer set search_path = ''
as $fn$
declare
  actor uuid := auth.uid();
  pid uuid;
  result jsonb;
begin
  if actor is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode = '42501';
  end if;
  select id into strict pid from public.projects where slug = 'tuktuk-control';
  select coalesce(jsonb_object_agg(d.scope, d.fields), '{}'::jsonb)
    into result
  from public.marketplace_registration_drafts d
  where d.project_id = pid and d.user_id = actor;
  return result;
end;
$fn$;

create or replace function public.save_my_marketplace_registration_draft_field(
  target_vehicle_id text, target_field text, target_value jsonb)
returns jsonb language plpgsql security definer set search_path = ''
as $fn$
declare
  actor uuid := auth.uid();
  pid uuid;
  scope_key text;
  val text;
  media_kind text;
  type_name text;
  result jsonb;
begin
  if actor is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode = '42501';
  end if;
  select id into strict pid from public.projects where slug = 'tuktuk-control';
  if exists(select 1 from public.driver_profiles d where d.project_id = pid
       and d.user_id = actor and d.status = 'suspended') then
    raise exception 'DRIVER_SUSPENDED' using errcode = '42501';
  end if;
  if target_field is null or target_value is null then
    raise exception 'INVALID_DRAFT_FIELD' using errcode = '22023';
  end if;
  if target_vehicle_id is null then
    scope_key := 'driver';
    if target_field not in ('name','phone','driver_photo_id',
        'identity_front_id','identity_back_id') then
      raise exception 'INVALID_DRIVER_DRAFT_FIELD' using errcode = '22023';
    end if;
  else
    if not exists(select 1 from public.vehicles v where v.id = target_vehicle_id
         and v.project_id = pid and v.owner_user_id = actor
         and v.deleted_at is null and v.marketplace_status <> 'suspended') then
      raise exception 'VEHICLE_NOT_OWNED' using errcode = '42501';
    end if;
    scope_key := 'vehicle:' || target_vehicle_id;
    if char_length(scope_key) > 160 or target_field not in (
        'category','other_category','propulsion','brand','model',
        'year','passengers','cargo_kg','body_type','registration',
        'services','vehicle_photo_id') then
      raise exception 'INVALID_VEHICLE_DRAFT_FIELD' using errcode = '22023';
    end if;
  end if;

  type_name := jsonb_typeof(target_value);
  if target_field = 'services' then
    if type_name <> 'array' or jsonb_array_length(target_value) > 25 or exists (
      select 1 from jsonb_array_elements_text(target_value) s(code)
      where not exists(select 1 from public.service_types c where c.project_id = pid
            and c.code = s.code and c.active)) then
      raise exception 'INVALID_SERVICES_DRAFT' using errcode = '22023';
    end if;
  else
    if type_name <> 'string' then
      raise exception 'INVALID_DRAFT_VALUE_TYPE' using errcode = '22023';
    end if;
    val := target_value #>> '{}';
    if char_length(val) > 160 then
      raise exception 'DRAFT_VALUE_TOO_LONG' using errcode = '22023';
    end if;
    if target_field = 'name' and (char_length(btrim(val)) < 2 or char_length(val) > 100) then
      raise exception 'INVALID_DRAFT_NAME' using errcode = '22023';
    elsif target_field = 'phone' and val !~ '^\+[1-9][0-9]{7,14}$' then
      raise exception 'INVALID_DRAFT_PHONE' using errcode = '22023';
    elsif target_field in ('brand','model') and (char_length(btrim(val)) < 1 or char_length(val) > 80) then
      raise exception 'INVALID_DRAFT_VEHICLE_NAME' using errcode = '22023';
    elsif target_field in ('category','propulsion') and not exists (
      select 1 from public.vehicle_categories c
      where target_field = 'category' and c.project_id=pid and c.code=val and c.active
      union all
      select 1 from public.propulsion_types p
      where target_field = 'propulsion' and p.project_id=pid and p.code=val and p.active
    ) then
      raise exception 'INVALID_DRAFT_CATALOG' using errcode = '22023';
    elsif target_field = 'registration' and char_length(val) > 32 then
      raise exception 'INVALID_DRAFT_REGISTRATION' using errcode = '22023';
    elsif target_field in ('year','passengers','cargo_kg') and val <> '' then
      if val !~ '^[0-9]+(\.[0-9]+)?$' then
        raise exception 'INVALID_DRAFT_NUMBER' using errcode = '22023';
      end if;
      if (target_field = 'year' and (val::numeric < 1900 or val::numeric > 2200))
        or (target_field = 'passengers' and (val::numeric < 1 or val::numeric > 100 or val::numeric <> trunc(val::numeric)))
        or (target_field = 'cargo_kg' and (val::numeric < 0 or val::numeric > 100000)) then
        raise exception 'INVALID_DRAFT_RANGE' using errcode = '22023';
      end if;
    end if;
    if target_field in ('driver_photo_id','vehicle_photo_id',
        'identity_front_id','identity_back_id') then
      if val !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F-]{27,}$' then
        raise exception 'INVALID_DRAFT_ASSET' using errcode = '22023';
      end if;
      media_kind := case target_field
        when 'driver_photo_id' then 'driver_photo'
        when 'vehicle_photo_id' then 'vehicle_photo'
        when 'identity_front_id' then 'identity_front'
        else 'identity_back' end;
      if not exists(select 1 from public.media_assets a
        where a.id=val::uuid and a.project_id=pid and a.owner_user_id=actor
        and a.asset_kind=media_kind and a.status='available'
        and (media_kind not in ('identity_front','identity_back')
          or a.storage_bucket='marketplace-identity')) then
        raise exception 'DRAFT_ASSET_NOT_OWNED' using errcode = '42501';
      end if;
    end if;
  end if;

  insert into public.marketplace_registration_drafts(project_id,user_id,scope,fields)
    values (pid,actor,scope_key,jsonb_build_object(target_field,target_value))
  on conflict (project_id,user_id,scope)
    do update set fields = public.marketplace_registration_drafts.fields || excluded.fields,
                  updated_at = now()
  returning fields into result;
  return result;
end;
$fn$;

create or replace function public.clear_my_marketplace_registration_drafts(target_vehicle_id text)
returns void language plpgsql security definer set search_path = ''
as $fn$
declare actor uuid := auth.uid(); pid uuid;
begin
  if actor is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501'; end if;
  select id into strict pid from public.projects where slug = 'tuktuk-control';
  delete from public.marketplace_registration_drafts
  where project_id=pid and user_id=actor
    and (scope='driver' or
       (target_vehicle_id is not null and scope='vehicle:'||target_vehicle_id));
end;
$fn$;

revoke all on function public.get_my_marketplace_registration_drafts() from public;
revoke all on function public.save_my_marketplace_registration_draft_field(text,text,jsonb) from public;
revoke all on function public.clear_my_marketplace_registration_drafts(text) from public;
grant execute on function public.get_my_marketplace_registration_drafts() to authenticated;
grant execute on function public.save_my_marketplace_registration_draft_field(text,text,jsonb) to authenticated;
grant execute on function public.clear_my_marketplace_registration_drafts(text) to authenticated;
