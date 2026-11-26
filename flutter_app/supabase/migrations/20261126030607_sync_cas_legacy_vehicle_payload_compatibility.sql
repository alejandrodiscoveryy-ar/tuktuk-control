-- Migration applied to production 2026-11-26; retain CAS and RLS.
CREATE OR REPLACE FUNCTION public.sync_entities_push_cas(p_rows jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_user uuid := auth.uid();
  v_row jsonb;
  v_type text;
  v_id text;
  v_vehicle text;
  v_device text;
  v_payload jsonb;
  v_previous jsonb;
  v_expected bigint;
  v_updated timestamptz;
  v_deleted timestamptz;
  v_version bigint;
  v_remote record;
  v_op_id text;
  v_accepted jsonb := '[]'::jsonb;
  v_conflicts jsonb := '[]'::jsonb;
  v_remote_wins jsonb := '[]'::jsonb;
  v_auto_winner text;
begin
  if v_user is null then
    raise exception 'AUTH_REQUIRED' using errcode = '42501';
  end if;
  if p_rows is null or pg_catalog.jsonb_typeof(p_rows) <> 'array'
    or pg_catalog.jsonb_array_length(p_rows) > 500 then
    raise exception 'INVALID_BATCH' using errcode = '22023';
  end if;

  for v_row in select value from pg_catalog.jsonb_array_elements(p_rows) loop
    v_type := v_row->>'entity_type';
    v_id := v_row->>'entity_id';
    v_vehicle := v_row->>'vehicle_id';
    v_device := coalesce(v_row->>'device_id', '');
    v_payload := v_row->'payload';
    -- Legacy VehicleProfile uses its own id as vehicleId. Normalize only
    -- absent vehicleId, and only when both outer identifiers agree.
    -- Explicit mismatches still fail the existing ownership checks below.
    if v_type = 'vehicle'
      and v_id is not null and v_id = v_vehicle
      and pg_catalog.jsonb_typeof(v_payload) = 'object'
      and not (v_payload ? 'vehicleId') then
      v_payload := v_payload || pg_catalog.jsonb_build_object('vehicleId', v_vehicle);
    end if;
    v_previous := v_row->'previous_payload';
    if v_previous = 'null'::jsonb then v_previous := null; end if;
    v_expected := (v_row->>'expected_version')::bigint;
    v_updated := (v_row->>'updated_at')::timestamptz;
    v_deleted := (v_row->>'deleted_at')::timestamptz;
    v_op_id := coalesce(v_type, '') || ':' || coalesce(v_id, '');
    v_version := null;
    if v_type not in ('dailyRecord', 'maintenance', 'vehicle', 'settings')
      or v_id is null or pg_catalog.length(v_id) > 200 or v_id = ''
      or v_vehicle is null or pg_catalog.length(v_vehicle) > 200 or v_vehicle = ''
      or v_updated is null
      or pg_catalog.jsonb_typeof(v_payload) <> 'object'
      or v_payload->>'userId' is distinct from v_user::text
      or v_payload->>'vehicleId' is distinct from v_vehicle
      or v_payload->>'id' is distinct from v_id
      or (v_expected is not null and v_expected < 0) then
      raise exception 'INVALID_ENTITY' using errcode = '22023';
    end if;

    if v_previous is null then
      insert into public.sync_entities(
        user_id, vehicle_id, entity_type, entity_id,
        device_id, payload, updated_at, deleted_at
      ) values(
        v_user, v_vehicle, v_type, v_id,
        v_device, v_payload, v_updated, v_deleted
      ) on conflict (user_id, entity_type, entity_id) do nothing
        returning server_version into v_version;
    else
      update public.sync_entities
      set vehicle_id = v_vehicle,
          device_id = v_device, payload = v_payload,
          updated_at = v_updated, deleted_at = v_deleted
      where user_id = v_user and entity_type = v_type and entity_id = v_id
        and (v_expected is null or server_version = v_expected)
        and public.sync_entity_business_payload(v_type, payload) =
            public.sync_entity_business_payload(v_type, v_previous)
      returning server_version into v_version;
    end if;

    if v_version is not null then
      v_accepted := v_accepted || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('id', v_op_id, 'server_version', v_version)
      );
      continue;
    end if;

    select payload, vehicle_id, device_id, updated_at, deleted_at, server_version
      into v_remote
      from public.sync_entities
      where user_id = v_user and entity_type = v_type and entity_id = v_id;

    -- Reintento idéntico: el acuse perdido no duplica la escritura.
    if found and v_remote.vehicle_id = v_vehicle
      and public.sync_entity_business_payload(v_type,v_remote.payload) =
          public.sync_entity_business_payload(v_type,v_payload) then
      v_accepted := v_accepted || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'id', v_op_id, 'server_version', v_remote.server_version
        )
      );
      continue;
    end if;

    -- Última MODIFICACIÓN real (no último dispositivo en sincronizar).
    -- Las fechas de teléfono en el futuro no pueden ganar automáticamente.
    -- Sin base previa, nunca desplazar una fila existente por un blind insert.
    -- El UPDATE condicional cierra la carrera entre comparar y sobrescribir.
    if found and v_previous is not null
      and v_updated > v_remote.updated_at
      and v_updated <= pg_catalog.clock_timestamp() + interval '10 minutes' then
      update public.sync_entities
      set vehicle_id = v_vehicle, device_id = v_device,
          payload = v_payload, updated_at = v_updated, deleted_at = v_deleted
      where user_id = v_user and entity_type = v_type and entity_id = v_id
        and updated_at < v_updated
        and server_version = v_remote.server_version
      returning server_version into v_version;
      if v_version is not null then
        v_accepted := v_accepted || pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object('id', v_op_id, 'server_version', v_version)
        );
        continue;
      end if;
      -- Un tercero pudo actualizar durante el intento: volver a leer.
      select payload, vehicle_id, device_id, updated_at, deleted_at, server_version
        into v_remote
        from public.sync_entities
        where user_id = v_user and entity_type = v_type and entity_id = v_id;
    end if;

    -- Gana el servidor. El cliente guarda su copia local ANTES de confirmar
    -- la operación y aplica la remota sin pedirle decisión al conductor.
    if found then
      v_remote_wins := v_remote_wins || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'id', v_op_id,
          'server_version', v_remote.server_version,
          'remote_payload', v_remote.payload,
          'remote_vehicle_id', v_remote.vehicle_id,
          'remote_device_id', v_remote.device_id,
          'remote_updated_at', v_remote.updated_at,
          'remote_deleted_at', v_remote.deleted_at
        )
      );
    else
      v_conflicts := v_conflicts || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('id', v_op_id, 'server_version', null)
      );
    end if;
  end loop;

  return pg_catalog.jsonb_build_object(
    'accepted', v_accepted,
    'remote_wins', v_remote_wins,
    'conflicts', v_conflicts
  );
end;
$function$;
