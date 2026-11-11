\set ON_ERROR_STOP on
set role authenticated;
select pg_catalog.set_config(
  'request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', false
);

do $test$
declare
  u constant text := '11111111-1111-4111-8111-111111111111';
  t0 timestamptz := now() - interval '40 minutes';
  t1 timestamptz := now() - interval '30 minutes';
  t2 timestamptz := now() - interval '20 minutes';
  t_old timestamptz := now() - interval '25 minutes';
  t_legacy timestamptz := now() - interval '10 minutes';
  p0 jsonb;
  p1 jsonb;
  p2 jsonb;
  p_old jsonb;
  result jsonb;
  current_payload jsonb;
  current_version bigint;
begin
  p0 := jsonb_build_object('id','row1','userId',u,
    'vehicleId','vehicle-one','note','A',
    'updatedAt',t0::text);
  p1 := jsonb_set(p0, '{note}', '"B"'::jsonb);
  p2 := jsonb_set(p0, '{note}', '"C"'::jsonb);
  p_old := jsonb_set(p0, '{note}', '"OLDER"'::jsonb);

  -- Crear registro.
  result := public.sync_entities_push_cas(jsonb_build_array(
    jsonb_build_object('entity_type','dailyRecord','entity_id','row1',
      'vehicle_id','vehicle-one','device_id','phone-a',
      'payload',p0,'updated_at',t0)
  ));
  if (result->'accepted'->0->>'server_version')::int is distinct from 1 then
    raise exception 'CREATE_FAIL: %', result;
  end if;

  -- Primera modificación desde teléfono A.
  result := public.sync_entities_push_cas(jsonb_build_array(
    jsonb_build_object('entity_type','dailyRecord','entity_id','row1',
      'vehicle_id','vehicle-one','device_id','phone-a',
      'payload',p1,'previous_payload',p0,
      'expected_version',1,'updated_at',t1)
  ));
  if (result->'accepted'->0->>'server_version')::int is distinct from 2 then
    raise exception 'FIRST_WRITE_FAIL: %', result;
  end if;

  -- Teléfono B partió de la base antigua pero editó MÁS TARDE: debe ganar.
  result := public.sync_entities_push_cas(jsonb_build_array(
    jsonb_build_object('entity_type','dailyRecord','entity_id','row1',
      'vehicle_id','vehicle-one','device_id','phone-b',
      'payload',p2,'previous_payload',p0,
      'expected_version',1,'updated_at',t2)
  ));
  if (result->'accepted'->0->>'server_version')::int is distinct from 3 then
    raise exception 'LATER_EDIT_DID_NOT_WIN: %', result;
  end if;

  -- Edición más antigua: conservar versión nueva y devolverla al cliente.
  result := public.sync_entities_push_cas(jsonb_build_array(
    jsonb_build_object('entity_type','dailyRecord','entity_id','row1',
      'vehicle_id','vehicle-one','device_id','phone-c',
      'payload',p_old,'previous_payload',p0,
      'expected_version',1,'updated_at',t_old)
  ));
  if jsonb_array_length(result->'remote_wins') is distinct from 1 then
    raise exception 'OLDER_EDIT_DID_NOT_YIELD: %', result;
  end if;

  -- Reenvío tras pérdida del acuse: no crear otra modificación.
  result := public.sync_entities_push_cas(jsonb_build_array(
    jsonb_build_object('entity_type','dailyRecord','entity_id','row1',
      'vehicle_id','vehicle-one','device_id','phone-b',
      'payload',p2,'previous_payload',p0,
      'expected_version',1,'updated_at',t2)
  ));
  if (result->'accepted'->0->>'server_version')::int is distinct from 3 then
    raise exception 'IDEMPOTENCY_FAIL: %', result;
  end if;

  -- APK antigua con upsert SIN comparación: tampoco debe borrar lo nuevo.
  insert into public.sync_entities(
    user_id, vehicle_id, entity_type, entity_id,
    device_id, payload, updated_at
  ) values(u::uuid,'vehicle-one','dailyRecord','row1','legacy',p_old,t_old)
  on conflict(user_id,entity_type,entity_id) do update
    set payload=excluded.payload, device_id=excluded.device_id,
        updated_at=excluded.updated_at;
  select payload, server_version into current_payload,current_version
  from public.sync_entities where user_id=u::uuid and entity_id='row1';
  if current_payload->>'note' <> 'C' or current_version <> 3 then
    raise exception 'LEGACY_OLDER_OVERWROTE_NEWER: %, %',
      current_payload,current_version;
  end if;

  -- APK antigua que editó realmente MÁS TARDE: debe ganar también.
  insert into public.sync_entities(
    user_id, vehicle_id, entity_type, entity_id,
    device_id, payload, updated_at
  ) values(
    u::uuid,'vehicle-one','dailyRecord','row1','legacy',
    jsonb_set(p0,'{note}','"LEGACY_NEWER"'::jsonb),t_legacy
  )
  on conflict(user_id,entity_type,entity_id) do update
    set payload=excluded.payload, device_id=excluded.device_id,
        updated_at=excluded.updated_at;
  select payload, server_version into current_payload,current_version
  from public.sync_entities where user_id=u::uuid and entity_id='row1';
  if current_payload->>'note' <> 'LEGACY_NEWER' or current_version <> 4 then
    raise exception 'LEGACY_LATEST_FAILED: %, %', current_payload,current_version;
  end if;
end
$test$;

-- Nadie debe consultar los registros de otra cuenta mediante RLS.
select pg_catalog.set_config(
  'request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', false
);
do $test$
declare n int;
begin
  select count(*) into n from public.sync_entities;
  if n <> 0 then
    raise exception 'RLS_CROSS_ACCOUNT_READ: % rows', n;
  end if;
end
$test$;
reset role;
do $test$
declare n int;
begin
  select count(*) into n
  from app_private.sync_entities_history
  where entity_id = 'row1';
  if n < 4 then
    raise exception 'HISTORY_DID_NOT_KEEP_BOTH_VERSIONS: %', n;
  end if;
  if not exists(select 1 from app_private.sync_entities_history
      where entity_id='row1' and event_kind='older_edit_rejected') then
    raise exception 'OLD_LEGACY_NOT_ARCHIVED';
  end if;
  raise notice 'CAS_LAST_EDIT_WINS_AND_HISTORY_OK';
end
$test$;
