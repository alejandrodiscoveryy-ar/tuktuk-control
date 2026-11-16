-- Optional vehicle color. Additive and compatible with older clients.
-- Apply before deploying the new driver WebApp. Existing colors remain NULL.
BEGIN;
ALTER TABLE public.vehicles ADD COLUMN IF NOT EXISTS color text;
ALTER TABLE public.vehicles ADD CONSTRAINT marketplace_vehicle_color_length_check
  CHECK (color IS NULL OR (char_length(btrim(color)) BETWEEN 1 AND 40));

CREATE OR REPLACE FUNCTION public.get_my_marketplace_onboarding()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare actor uuid:=auth.uid(); pid uuid;
begin
 if actor is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501'; end if; select id into pid from public.projects where slug='tuktuk-control';
 return jsonb_build_object('server_time',now(),'display_name',(select p.display_name from public.profiles p where p.id=actor),'phone',(select p.phone from public.profiles p where p.id=actor),'driver_profile_exists',exists(select 1 from public.driver_profiles d where d.project_id=pid and d.user_id=actor),'driver_status',(select d.status from public.driver_profiles d where d.project_id=pid and d.user_id=actor),'driver_photo_asset_id',(select d.photo_asset_id from public.driver_profiles d where d.project_id=pid and d.user_id=actor),'driver_suspended',exists(select 1 from public.driver_profiles d where d.project_id=pid and d.user_id=actor and d.status='suspended'), 'vehicles',coalesce((select jsonb_agg(jsonb_build_object('vehicle_id',v.id,'name',v.name,'registration',v.registration,'category_code',v.category_code,'propulsion_code',v.propulsion_code,'category_other_description',v.category_other_description,'brand',v.brand,'model',v.model,'year',v.year,'passenger_capacity',v.passenger_capacity,'cargo_capacity_kg',v.cargo_capacity_kg,'cargo_volume_m3',v.cargo_volume_m3,'cargo_length_cm',v.cargo_length_cm,'cargo_width_cm',v.cargo_width_cm,'cargo_height_cm',v.cargo_height_cm,'body_type',v.body_type,'color',v.color,'main_photo_asset_id',v.main_photo_asset_id,'marketplace_status',v.marketplace_status,'is_active',a.is_active,'is_available',a.is_available,'services',coalesce((select jsonb_agg(s.service_code order by s.service_code) from public.vehicle_services s where s.project_id=pid and s.vehicle_id=v.id and s.enabled),'[]'::jsonb),'onboarding_complete',app_private.marketplace_onboarding_requirements_complete(actor,v.id)) order by v.created_at,v.id) from public.vehicles v left join public.driver_vehicle_assignments a on a.project_id=v.project_id and a.vehicle_id=v.id and a.driver_user_id=actor where v.project_id=pid and v.owner_user_id=actor and v.deleted_at is null and v.id=(select vv.id from public.vehicles vv left join public.driver_vehicle_assignments aa on aa.project_id=vv.project_id and aa.vehicle_id=vv.id and aa.driver_user_id=actor where vv.project_id=pid and vv.owner_user_id=actor and vv.deleted_at is null order by case when vv.marketplace_status='active' and coalesce(aa.is_active,false) then 0 else 1 end,case when vv.marketplace_status='active' then 0 else 1 end,case when vv.id like 'marketplace-'||actor::text||'-%' then 0 else 1 end,vv.created_at,vv.id limit 1)),'[]'::jsonb),'vehicle_categories',(select coalesce(jsonb_agg(jsonb_build_object('code',c.code,'name',c.name,'sort_order',c.sort_order) order by c.sort_order,c.code),'[]'::jsonb) from public.vehicle_categories c where c.project_id=pid and c.active),'propulsion_types',(select coalesce(jsonb_agg(jsonb_build_object('code',p.code,'name',p.name,'sort_order',p.sort_order) order by p.sort_order,p.code),'[]'::jsonb) from public.propulsion_types p where p.project_id=pid and p.active),'service_types',(select coalesce(jsonb_agg(jsonb_build_object('code',s.code,'name',s.name,'sort_order',s.sort_order) order by s.sort_order,s.code),'[]'::jsonb) from public.service_types s where s.project_id=pid and s.active),'assets',(select coalesce(jsonb_agg(jsonb_build_object('asset_id',a.id,'asset_kind',a.asset_kind,'storage_bucket',a.storage_bucket,'storage_path',a.storage_path,'status',a.status) order by a.created_at desc),'[]'::jsonb) from public.media_assets a where a.project_id=pid and a.owner_user_id=actor));
end;
$function$;

CREATE OR REPLACE FUNCTION public.save_my_marketplace_registration_draft_field(target_vehicle_id text, target_field text, target_value jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
        'year','passengers','cargo_kg','body_type','registration','color',
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
    elsif target_field = 'color' and char_length(val) > 40 then
      raise exception 'INVALID_DRAFT_COLOR' using errcode = '22023';
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
$function$;

CREATE OR REPLACE FUNCTION public.save_my_marketplace_vehicle_profile_v2(target_vehicle_id text, target_category_code text, target_propulsion_code text, target_category_other_description text, target_brand text, target_model text, target_year integer, target_passenger_capacity integer, target_cargo_capacity_kg numeric, target_cargo_volume_m3 numeric, target_cargo_length_cm numeric, target_cargo_width_cm numeric, target_cargo_height_cm numeric, target_body_type text, target_main_photo_asset_id uuid, target_service_codes text[], target_vehicle_name text, target_registration text, target_color text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  actor uuid := auth.uid();
  pid uuid;
  normalized_name text := nullif(btrim(target_vehicle_name), '');
  normalized_registration text := nullif(btrim(target_registration), '');
  existing_vehicle public.vehicles%rowtype;
  sync_timestamp timestamptz;
  normalized_color text := nullif(btrim(target_color), '');
BEGIN
  IF actor IS NULL THEN
    RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING errcode = '42501';
  END IF;
  IF normalized_name IS NULL
     OR char_length(normalized_name) < 2
     OR char_length(normalized_name) > 80
     OR char_length(coalesce(normalized_registration, '')) > 32
     OR char_length(coalesce(normalized_color, '')) > 40 THEN
    RAISE EXCEPTION 'INVALID_VEHICLE_IDENTITY' USING errcode = '22023';
  END IF;
  SELECT p.id INTO STRICT pid
    FROM public.projects p WHERE p.slug = 'tuktuk-control';
  SELECT * INTO existing_vehicle
    FROM public.vehicles v
    WHERE v.project_id = pid
      AND v.id = target_vehicle_id
      AND v.owner_user_id = actor
    FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'VEHICLE_NOT_FOUND_OR_NOT_OWNED' USING errcode = '42501';
  END IF;
  IF existing_vehicle.deleted_at IS NOT NULL
     OR existing_vehicle.marketplace_status = 'suspended' THEN
    RAISE EXCEPTION 'VEHICLE_UNAVAILABLE_FOR_ONBOARDING' USING errcode = '42501';
  END IF;

  -- Todas las validaciones y operaciones suceden dentro de una transaccion.
  PERFORM public.save_my_marketplace_vehicle_onboarding(
    target_vehicle_id => target_vehicle_id,
    target_category_code => target_category_code,
    target_propulsion_code => target_propulsion_code,
    target_category_other_description => target_category_other_description,
    target_brand => target_brand,
    target_model => target_model,
    target_year => target_year,
    target_passenger_capacity => target_passenger_capacity,
    target_cargo_capacity_kg => target_cargo_capacity_kg,
    target_cargo_volume_m3 => target_cargo_volume_m3,
    target_cargo_length_cm => target_cargo_length_cm,
    target_cargo_width_cm => target_cargo_width_cm,
    target_cargo_height_cm => target_cargo_height_cm,
    target_body_type => target_body_type,
    target_main_photo_asset_id => target_main_photo_asset_id,
    target_service_codes => target_service_codes
  );

  UPDATE public.vehicles
    SET name = normalized_name,
        registration = normalized_registration,
        color = normalized_color
    WHERE project_id = pid AND id = target_vehicle_id AND owner_user_id = actor;

  -- No crear una entidad artificial para vehiculos exclusivos de Marketplace.
  -- Para los vehiculos de Control existentes, actualizar su entidad sincronizada.
  sync_timestamp := clock_timestamp();
  UPDATE public.sync_entities
    SET payload = jsonb_set(
                    jsonb_set(payload, '{name}', to_jsonb(normalized_name), true),
                    '{registration}', to_jsonb(coalesce(normalized_registration, '')), true
                  ) || jsonb_build_object('updatedAt', sync_timestamp),
        updated_at = sync_timestamp
    WHERE user_id = actor
      AND entity_type = 'vehicle'
      AND entity_id = target_vehicle_id
      AND deleted_at IS NULL;

  RETURN public.get_my_marketplace_onboarding();
END;
$function$;

REVOKE ALL ON FUNCTION public.save_my_marketplace_vehicle_profile_v2(text, text, text, text, text, text, integer, integer, numeric, numeric, numeric, numeric, numeric, text, uuid, text[], text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.save_my_marketplace_vehicle_profile_v2(text, text, text, text, text, text, integer, integer, numeric, numeric, numeric, numeric, numeric, text, uuid, text[], text, text, text) TO authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
