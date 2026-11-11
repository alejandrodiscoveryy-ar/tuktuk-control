-- TUKTUK Conductor: CAS para la WebApp nueva y conservación de versiones antiguas.
-- No modifica tablas de carreras Marketplace ni requiere actualizar las APK existentes.
-- IMPORTANTE: no desplegar la WebApp que usa esta RPC antes de esta migración.

alter table public.sync_entities
  add column if not exists server_version bigint not null default 1,
  add column if not exists server_seq bigint not null default 0;

-- Los registros heredados comienzan en secuencia 0, sin UPDATE masivo ni
-- disparar lógica de negocio existente sobre sus vehículos.
create table if not exists app_private.sync_user_sequence (
  user_id uuid primary key references auth.users(id) on delete cascade,
  last_seq bigint not null default 0
);
revoke all on app_private.sync_user_sequence from public, anon, authenticated;
create index if not exists sync_entities_user_seq_idx
  on public.sync_entities(user_id, server_seq, entity_type, entity_id);

-- Fila bloqueada por usuario: confirma los cambios en el orden del cursor
-- aun si se editan registros distintos desde dos dispositivos simultáneos.
create or replace function app_private.sync_entities_set_sequence()
returns trigger language plpgsql security definer set search_path = ''
as $sync_sequence$
begin
  insert into app_private.sync_user_sequence(user_id,last_seq)
    values (new.user_id,1)
  on conflict(user_id) do update
    set last_seq = app_private.sync_user_sequence.last_seq + 1
  returning last_seq into new.server_seq;
  return new;
end;
$sync_sequence$;
revoke all on function app_private.sync_entities_set_sequence()
  from public, anon, authenticated;
drop trigger if exists zz_sync_entities_set_sequence on public.sync_entities;
create trigger zz_sync_entities_set_sequence
before insert or update on public.sync_entities
for each row execute function app_private.sync_entities_set_sequence();

create or replace function app_private.sync_entities_bump_version()
returns trigger
language plpgsql
security definer
set search_path = ''
as $sync_body$
begin
  -- También protege escrituras directas de APK existentes.
  -- La fecha de EDICIÓN, no el momento de sincronizar, decide.
  if new.updated_at > pg_catalog.clock_timestamp() + interval '10 minutes' then
    raise exception 'DEVICE_CLOCK_TOO_FAR_AHEAD' using errcode = '22023';
  end if;

  if tg_op = 'INSERT' then
    new.server_version := 1;
  else
    if new.updated_at <= old.updated_at and (
      public.sync_entity_business_payload(new.entity_type, new.payload)
        is distinct from
      public.sync_entity_business_payload(old.entity_type, old.payload)
      or new.vehicle_id is distinct from old.vehicle_id
      or new.deleted_at is distinct from old.deleted_at
    ) then
      -- Una APK antigua cree que el upsert se completó; conservar su
      -- intento rechazado para poder recuperarlo sin borrar la versión nueva.
      insert into app_private.sync_entities_history(
        user_id, entity_type, entity_id, vehicle_id, server_version,
        device_id, payload, updated_at, deleted_at, event_kind
      ) values (
        new.user_id, new.entity_type, new.entity_id, new.vehicle_id,
        old.server_version, new.device_id, new.payload, new.updated_at,
        new.deleted_at, 'older_edit_rejected'
      );
      return null;
    end if;
    new.server_version := old.server_version + 1;
  end if;
  return new;
end;
$sync_body$;
revoke all on function app_private.sync_entities_bump_version() from public, anon, authenticated;

drop trigger if exists zz_sync_entities_bump_version on public.sync_entities;
create trigger zz_sync_entities_bump_version
before insert or update on public.sync_entities
for each row execute function app_private.sync_entities_bump_version();

-- Las APK heredadas siguen realizando upsert directo. Conservar la versión
-- previa permite investigar y recuperar cualquier sobrescritura legada.
create table if not exists app_private.sync_entities_history (
  id bigint generated always as identity primary key,
  user_id uuid not null,
  entity_type text not null,
  entity_id text not null,
  vehicle_id text not null,
  server_version bigint not null,
  device_id text not null,
  payload jsonb not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  event_kind text not null default 'superseded',
  captured_at timestamptz not null default clock_timestamp()
);
create index if not exists sync_entities_history_owner_entity_idx
  on app_private.sync_entities_history(user_id, entity_type, entity_id, id desc);
revoke all on app_private.sync_entities_history from public, anon, authenticated;

create or replace function app_private.sync_entities_preserve_previous()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.payload is distinct from new.payload
    or old.deleted_at is distinct from new.deleted_at
    or old.vehicle_id is distinct from new.vehicle_id then
    insert into app_private.sync_entities_history(
      user_id, entity_type, entity_id, vehicle_id, server_version,
      device_id, payload, updated_at, deleted_at, event_kind
    ) values(
      old.user_id, old.entity_type, old.entity_id, old.vehicle_id,
      old.server_version, old.device_id, old.payload, old.updated_at,
      old.deleted_at, 'superseded'
    );
  end if;
  return null;
end;
$$;
revoke all on function app_private.sync_entities_preserve_previous() from public, anon, authenticated;
drop trigger if exists zz_sync_entities_preserve_previous on public.sync_entities;
create trigger zz_sync_entities_preserve_previous
after update on public.sync_entities
for each row execute function app_private.sync_entities_preserve_previous();

-- Comparación semántica: ignorar únicamente los metadatos que pueden cambiar
-- sin alterar el contenido del registro, igual que la política de Flutter.
create or replace function public.sync_entity_business_payload(
  p_type text, p_payload jsonb
)
returns jsonb
language sql immutable
set search_path = ''
as $$
  select case
    when p_type = 'settings' then
      pg_catalog.jsonb_build_object(
        'maintenanceIntervalKm', (p_payload->>'maintenanceIntervalKm')::numeric,
        'preferredCurrency', p_payload->>'preferredCurrency',
        'preferredLanguage', p_payload->>'preferredLanguage',
        'preferredTheme', p_payload->>'preferredTheme',
        'profileDisplayName',
          coalesce(
            p_payload->>'profileDisplayName',
            (select value #>> '{}' from pg_catalog.jsonb_each(p_payload)
              where key like 'profileDisplayName:%' order by key limit 1)
          )
      )
    when p_type = 'vehicle' then
      p_payload - 'syncStatus' - 'updatedAt' - 'deviceId' - 'vehicleId'
    else
      p_payload - 'syncStatus' - 'updatedAt' - 'deviceId'
  end;
$$;
revoke all on function public.sync_entity_business_payload(text,jsonb) from public, anon;
grant execute on function public.sync_entity_business_payload(text,jsonb) to authenticated;

-- Comparar y modificar en una única sentencia UPDATE/INSERT evita perder
-- cambios entre la lectura de un teléfono y la escritura de otro.
create or replace function public.sync_entities_push_cas(p_rows jsonb)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
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
$$;
revoke all on function public.sync_entities_push_cas(jsonb) from public, anon;
grant execute on function public.sync_entities_push_cas(jsonb) to authenticated;
