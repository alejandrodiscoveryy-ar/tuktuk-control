-- TUKTUK 2.0
-- 002: automatic promotion + access without mandatory initial deposit

begin;

-- ---------------------------------------------------------------------------
-- 1. Helper único e idempotente para iniciar automáticamente la promoción.
-- ---------------------------------------------------------------------------

create or replace function app_private.maybe_start_marketplace_promotion(
  target_user_id uuid,
  target_vehicle_id text,
  target_idempotency_key uuid default null
)
returns public.marketplace_work_trials
language plpgsql
security definer
set search_path=''
as $function$
declare
  pid uuid;
  existing public.marketplace_work_trials%rowtype;
  settings public.project_marketplace_financial_settings%rowtype;
  started timestamptz;
  generated_key uuid;
begin
  if target_user_id is null or target_vehicle_id is null then
    return null;
  end if;

  select p.id into pid
  from public.projects p
  where p.slug='tuktuk-control';

  if pid is null then
    raise exception 'TUKTUK_PROJECT_NOT_FOUND';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'tuktuk-promotion:' || pid::text || ':' || target_user_id::text,
      0
    )
  );

  select *
    into existing
  from public.marketplace_work_trials t
  where t.project_id=pid and t.user_id=target_user_id
  for update;

  if found then
    return existing;
  end if;

  if not app_private.marketplace_onboarding_requirements_complete(
    target_user_id,
    target_vehicle_id
  ) then
    return null;
  end if;

  select *
    into settings
  from public.project_marketplace_financial_settings f
  where f.project_id=pid
  for update;

  if not found then
    raise exception 'MARKETPLACE_FINANCIAL_SETTINGS_NOT_FOUND'
      using errcode='P0002';
  end if;

  if settings.promotion_duration_days not between 1 and 365 then
    raise exception 'INVALID_MARKETPLACE_PROMOTION_DURATION'
      using errcode='22023';
  end if;

  generated_key := coalesce(target_idempotency_key,gen_random_uuid());
  started := now();

  insert into public.marketplace_work_trials(
    project_id,user_id,started_vehicle_id,start_idempotency_key,
    started_at,ends_at,duration_days_snapshot,rule_version_snapshot,
    activation_source
  )
  values(
    pid,target_user_id,target_vehicle_id,generated_key,
    started,
    started + (settings.promotion_duration_days * interval '1 day'),
    settings.promotion_duration_days,
    settings.promotion_rule_version,
    'onboarding_auto'
  )
  returning * into existing;

  update public.driver_profiles
  set status='active',
      activated_at=coalesce(activated_at,started),
      updated_at=now()
  where project_id=pid
    and user_id=target_user_id
    and status<>'suspended'
    and suspended_at is null;

  update public.vehicles
  set marketplace_status='active',
      updated_at=now()
  where project_id=pid
    and id=target_vehicle_id
    and deleted_at is null
    and marketplace_status<>'suspended';

  insert into public.wallets(project_id,user_id,currency)
  values(pid,target_user_id,settings.wallet_currency)
  on conflict (project_id,user_id) do nothing;

  return existing;
end;
$function$;

revoke all on function app_private.maybe_start_marketplace_promotion(uuid,text,uuid)
  from public,anon,authenticated;

create or replace function app_private.maybe_start_marketplace_promotion_for_any_vehicle(
  target_user_id uuid
)
returns public.marketplace_work_trials
language plpgsql
security definer
set search_path=''
as $function$
declare
  pid uuid;
  vehicle_id text;
  result public.marketplace_work_trials%rowtype;
begin
  select p.id into pid
  from public.projects p
  where p.slug='tuktuk-control';

  if pid is null or target_user_id is null then
    return null;
  end if;

  select t.* into result
  from public.marketplace_work_trials t
  where t.project_id=pid and t.user_id=target_user_id;

  if found then
    return result;
  end if;

  select a.vehicle_id
    into vehicle_id
  from public.driver_vehicle_assignments a
  where a.project_id=pid
    and a.driver_user_id=target_user_id
    and a.is_active
    and app_private.marketplace_onboarding_requirements_complete(
      target_user_id,
      a.vehicle_id
    )
  order by a.created_at,a.vehicle_id
  limit 1;

  if vehicle_id is null then
    return null;
  end if;

  return app_private.maybe_start_marketplace_promotion(
    target_user_id,
    vehicle_id,
    null
  );
end;
$function$;

revoke all on function app_private.maybe_start_marketplace_promotion_for_any_vehicle(uuid)
  from public,anon,authenticated;

-- ---------------------------------------------------------------------------
-- 2. Onboarding de conductor: si con este paso queda completo, iniciar promo.
-- ---------------------------------------------------------------------------

create or replace function public.save_my_marketplace_driver_onboarding(
  target_display_name text,
  target_phone text,
  target_photo_asset_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $function$
declare
  actor uuid:=auth.uid();
  pid uuid;
  photo uuid:=target_photo_asset_id;
  d public.driver_profiles%rowtype;
  driver_exists boolean;
begin
  if actor is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501';
  end if;

  if nullif(btrim(target_display_name),'') is null
     or nullif(btrim(target_phone),'') !~ '^\\+[1-9][0-9]{7,14}$' then
    raise exception 'INVALID_DRIVER_PROFILE' using errcode='22023';
  end if;

  select id into pid
  from public.projects
  where slug='tuktuk-control';

  if not exists(select 1 from public.profiles where id=actor) then
    raise exception 'PROFILE_NOT_FOUND' using errcode='P0002';
  end if;

  if photo is not null and not exists(
    select 1
    from public.media_assets a
    where a.project_id=pid
      and a.id=photo
      and a.owner_user_id=actor
      and a.asset_kind='driver_photo'
      and a.status='available'
  ) then
    raise exception 'INVALID_DRIVER_PHOTO' using errcode='22023';
  end if;

  select * into d
  from public.driver_profiles
  where project_id=pid and user_id=actor
  for update;

  driver_exists:=found;

  if driver_exists and d.status='suspended' then
    raise exception 'DRIVER_SUSPENDED' using errcode='42501';
  end if;

  update public.profiles
  set display_name=btrim(target_display_name),
      phone=btrim(target_phone)
  where id=actor;

  if not driver_exists then
    insert into public.driver_profiles(project_id,user_id,status,photo_asset_id)
    values(pid,actor,'incomplete',photo);
  else
    update public.driver_profiles
    set photo_asset_id=coalesce(photo,d.photo_asset_id),
        updated_at=now()
    where project_id=pid and user_id=actor;
  end if;

  perform app_private.maybe_start_marketplace_promotion_for_any_vehicle(actor);

  return public.get_my_marketplace_onboarding();
end;
$function$;

-- ---------------------------------------------------------------------------
-- 3. Onboarding de vehículo: la última pieza completa activa conductor/promo.
-- ---------------------------------------------------------------------------

create or replace function public.save_my_marketplace_vehicle_onboarding(
  target_vehicle_id text,
  target_category_code text,
  target_propulsion_code text,
  target_category_other_description text,
  target_brand text,
  target_model text,
  target_year integer,
  target_passenger_capacity integer,
  target_cargo_capacity_kg numeric,
  target_cargo_volume_m3 numeric,
  target_cargo_length_cm numeric,
  target_cargo_width_cm numeric,
  target_cargo_height_cm numeric,
  target_body_type text,
  target_main_photo_asset_id uuid,
  target_service_codes text[]
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $function$
declare
  actor uuid:=auth.uid();
  pid uuid;
  v public.vehicles%rowtype;
  normalized_services text[]:=coalesce(target_service_codes,'{}'::text[]);
begin
  if actor is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501';
  end if;

  select id into pid
  from public.projects
  where slug='tuktuk-control';

  select * into v
  from public.vehicles
  where project_id=pid
    and id=target_vehicle_id
    and owner_user_id=actor
  for update;

  if not found then
    raise exception 'VEHICLE_NOT_FOUND_OR_NOT_OWNED' using errcode='42501';
  end if;

  if target_category_code is null
     or not exists(
       select 1
       from public.vehicle_categories c
       where c.project_id=pid
         and c.code=target_category_code
         and c.active
     )
     or target_propulsion_code is null
     or not exists(
       select 1
       from public.propulsion_types p
       where p.project_id=pid
         and p.code=target_propulsion_code
         and p.active
     ) then
    raise exception 'INVALID_VEHICLE_CATALOG_VALUE' using errcode='22023';
  end if;

  if target_category_code='other'
     and nullif(btrim(target_category_other_description),'') is null then
    raise exception 'OTHER_CATEGORY_DESCRIPTION_REQUIRED' using errcode='22023';
  end if;

  if (target_brand is not null and nullif(btrim(target_brand),'') is null)
     or (target_model is not null and nullif(btrim(target_model),'') is null)
     or coalesce(target_year,0)<0
     or coalesce(target_passenger_capacity,0)<0
     or coalesce(target_cargo_capacity_kg,0)<0
     or coalesce(target_cargo_volume_m3,0)<0
     or coalesce(target_cargo_length_cm,0)<0
     or coalesce(target_cargo_width_cm,0)<0
     or coalesce(target_cargo_height_cm,0)<0 then
    raise exception 'INVALID_VEHICLE_ONBOARDING' using errcode='22023';
  end if;

  if cardinality(normalized_services)<>(
       select count(distinct x) from unnest(normalized_services) x
     )
     or exists(
       select 1
       from unnest(normalized_services) x
       left join public.service_types s
         on s.project_id=pid and s.code=x and s.active
       where s.code is null
     ) then
    raise exception 'INVALID_VEHICLE_SERVICES' using errcode='22023';
  end if;

  if target_main_photo_asset_id is not null
     and not exists(
       select 1
       from public.media_assets a
       where a.project_id=pid
         and a.id=target_main_photo_asset_id
         and a.owner_user_id=actor
         and a.asset_kind='vehicle_photo'
         and a.status='available'
     ) then
    raise exception 'INVALID_VEHICLE_PHOTO' using errcode='22023';
  end if;

  insert into public.driver_profiles(project_id,user_id,status)
  values(pid,actor,'incomplete')
  on conflict do nothing;

  update public.vehicles
  set category_code=target_category_code,
      propulsion_code=target_propulsion_code,
      category_other_description=nullif(btrim(target_category_other_description),''),
      brand=nullif(btrim(target_brand),''),
      model=nullif(btrim(target_model),''),
      year=target_year,
      passenger_capacity=target_passenger_capacity,
      cargo_capacity_kg=target_cargo_capacity_kg,
      cargo_volume_m3=target_cargo_volume_m3,
      cargo_length_cm=target_cargo_length_cm,
      cargo_width_cm=target_cargo_width_cm,
      cargo_height_cm=target_cargo_height_cm,
      body_type=nullif(btrim(target_body_type),''),
      main_photo_asset_id=target_main_photo_asset_id,
      marketplace_status=case
        when marketplace_status='active' then 'active'
        when marketplace_status='suspended' then 'suspended'
        else 'pending_activation'
      end,
      updated_at=now()
  where project_id=pid
    and id=target_vehicle_id
    and owner_user_id=actor;

  insert into public.driver_vehicle_assignments(project_id,driver_user_id,vehicle_id)
  values(pid,actor,target_vehicle_id)
  on conflict do nothing;

  delete from public.vehicle_services
  where project_id=pid and vehicle_id=target_vehicle_id;

  insert into public.vehicle_services(project_id,vehicle_id,service_code,enabled)
  select pid,target_vehicle_id,x,true
  from unnest(normalized_services) x;

  perform app_private.maybe_start_marketplace_promotion(
    actor,
    target_vehicle_id,
    null
  );

  return public.get_my_marketplace_onboarding();
end;
$function$;

-- ---------------------------------------------------------------------------
-- 4. RPC antigua: queda como wrapper compatible, ya no como botón de negocio.
-- ---------------------------------------------------------------------------

create or replace function public.start_my_marketplace_work_trial(
  target_vehicle_id text,
  target_idempotency_key uuid
)
returns public.marketplace_work_trials
language plpgsql
security definer
set search_path=''
as $function$
declare
  actor uuid:=auth.uid();
  result public.marketplace_work_trials%rowtype;
begin
  if actor is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501';
  end if;

  if target_idempotency_key is null then
    raise exception 'IDEMPOTENCY_KEY_REQUIRED' using errcode='22023';
  end if;

  result:=app_private.maybe_start_marketplace_promotion(
    actor,
    target_vehicle_id,
    target_idempotency_key
  );

  if result.user_id is null then
    raise exception 'MARKETPLACE_ONBOARDING_INCOMPLETE'
      using errcode='22023';
  end if;

  return result;
end;
$function$;

comment on function public.start_my_marketplace_work_trial(text,uuid)
  is 'Compatibilidad TUKTUK 1.x. TUKTUK 2.0 inicia la promoción automáticamente al completar onboarding.';

-- ---------------------------------------------------------------------------
-- 5. Acceso: Control/Trabajos ya no dependen del depósito inicial.
-- ---------------------------------------------------------------------------

create or replace function public.get_my_marketplace_work_access(
  target_vehicle_id text
)
returns table(
  server_time timestamptz,
  vehicle_id text,
  onboarding_complete boolean,
  driver_active boolean,
  vehicle_available boolean,
  trial_started boolean,
  trial_active boolean,
  trial_started_at timestamptz,
  trial_ends_at timestamptz,
  initial_deposit_confirmed boolean,
  suite_active boolean,
  can_start_trial boolean,
  can_accept_new_job boolean,
  next_billing_mode text
)
language plpgsql
security definer
set search_path=''
as $function$
declare
  actor uuid:=auth.uid();
  pid uuid;
  dp public.driver_profiles%rowtype;
  dva public.driver_vehicle_assignments%rowtype;
  v public.vehicles%rowtype;
  promo public.marketplace_work_trials%rowtype;
  complete boolean;
  active boolean;
  available boolean;
  legacy_deposit boolean;
  test_mode boolean;
  test_force boolean;
begin
  if actor is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501';
  end if;

  select p.id into pid
  from public.projects p
  where p.slug='tuktuk-control';

  select d.* into dp
  from public.driver_profiles d
  where d.project_id=pid and d.user_id=actor;

  select a.* into dva
  from public.driver_vehicle_assignments a
  where a.project_id=pid
    and a.driver_user_id=actor
    and a.vehicle_id=target_vehicle_id;

  select veh.* into v
  from public.vehicles veh
  where veh.project_id=pid and veh.id=target_vehicle_id;

  select t.* into promo
  from public.marketplace_work_trials t
  where t.project_id=pid and t.user_id=actor;

  complete:=coalesce(
    app_private.marketplace_onboarding_requirements_complete(actor,target_vehicle_id),
    false
  );

  active:=dp.user_id is not null
    and dp.status='active'
    and dp.activated_at is not null
    and dp.suspended_at is null;

  available:=coalesce(
    dva.is_active
    and dva.is_available
    and v.marketplace_status='active'
    and v.deleted_at is null,
    false
  );

  -- Se conserva el dato legado para compatibilidad de clientes antiguos,
  -- pero no participa en ninguna decisión de acceso.
  legacy_deposit:=coalesce(
    app_private.has_confirmed_marketplace_initial_deposit(actor),
    false
  );

  select
    coalesce(m.enabled,false),
    coalesce(m.enabled and m.force_wallet_commission,false)
  into test_mode,test_force
  from (select 1) seed
  left join public.marketplace_test_mode m
    on m.project_id=pid
   and m.target_driver_user_id=actor;

  return query
  select
    now(),
    target_vehicle_id,
    complete,
    active,
    available,
    promo.user_id is not null,
    coalesce(
      promo.started_at<=now()
      and now()<promo.ends_at
      and active
      and not test_force,
      false
    ),
    promo.started_at,
    promo.ends_at,
    legacy_deposit,
    coalesce(active and complete,false),
    false,
    coalesce(complete and active and available,false),
    case
      when test_force then 'wallet_commission'
      when promo.user_id is not null
       and promo.started_at<=now()
       and now()<promo.ends_at
       and active
        then 'trial_free'
      when active and complete then 'wallet_commission'
      else null
    end;
end;
$function$;

-- ---------------------------------------------------------------------------
-- 6. Aceptación: fuera de promo solo importa saldo disponible suficiente.
-- ---------------------------------------------------------------------------

create or replace function public.accept_job(
  target_job_id uuid,
  target_vehicle_id text,
  target_idempotency_key uuid
)
returns public.jobs
language plpgsql
security definer
set search_path=''
as $function$
declare
  actor uuid:=auth.uid();
  pid uuid;
  j public.jobs%rowtype;
  e public.job_events%rowtype;
  a public.driver_vehicle_assignments%rowtype;
  t public.marketplace_work_trials%rowtype;
  trial_active boolean;
  force_test_commission boolean;
  amount numeric(14,2);
  reservation_id uuid;
  total numeric;
  reserved numeric;
  wallet_currency text;
begin
  if actor is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501';
  end if;

  if target_idempotency_key is null then
    raise exception 'IDEMPOTENCY_KEY_REQUIRED' using errcode='22023';
  end if;

  select id into pid
  from public.projects
  where slug='tuktuk-control';

  select * into j
  from public.jobs
  where project_id=pid and id=target_job_id
  for update;

  if not found then
    raise exception 'JOB_NOT_FOUND';
  end if;

  if j.test_deleted_at is not null then
    raise exception 'JOB_NOT_AVAILABLE';
  end if;

  if j.is_test and j.test_driver_user_id is distinct from actor then
    raise exception 'JOB_NOT_AVAILABLE';
  end if;

  select * into e
  from public.job_events
  where project_id=pid
    and operation_idempotency_key=target_idempotency_key;

  if found then
    if e.job_id=j.id and e.actor_user_id=actor and e.action='accept'
       and (
         (
           e.metadata->>'billing_mode'='trial_free'
           and exists(
             select 1
             from public.job_assignments x
             where x.project_id=pid
               and x.job_id=j.id
               and x.driver_user_id=actor
               and x.vehicle_id=target_vehicle_id
               and x.acceptance_idempotency_key=target_idempotency_key
               and x.billing_mode='trial_free'
               and x.commission_amount_snapshot=0
           )
           and not exists(
             select 1 from public.commission_reservations r
             where r.project_id=pid and r.job_id=j.id
           )
         )
         or
         (
           e.metadata->>'billing_mode'='wallet_commission'
           and exists(
             select 1
             from public.job_assignments x
             join public.commission_reservations r
               on r.project_id=x.project_id
              and r.job_id=x.job_id
              and r.user_id=actor
              and r.amount=x.commission_amount_snapshot
             where x.project_id=pid
               and x.job_id=j.id
               and x.driver_user_id=actor
               and x.vehicle_id=target_vehicle_id
               and x.acceptance_idempotency_key=target_idempotency_key
               and x.billing_mode='wallet_commission'
           )
         )
       ) then
      return j;
    end if;

    raise exception 'IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_OPERATION'
      using errcode='22023';
  end if;

  if j.status<>'published'
     or not app_private.marketplace_job_transition_allowed('published','accepted','driver')
     or (j.expires_at is not null and j.expires_at<=now())
     or j.assigned_driver_user_id is not null
     or j.assigned_vehicle_id is not null then
    raise exception 'JOB_NOT_AVAILABLE';
  end if;

  force_test_commission:=
    j.is_test and j.test_force_wallet_commission and j.test_driver_user_id=actor;

  trial_active:=
    app_private.has_active_marketplace_work_trial(actor)
    and not force_test_commission;

  if not exists(
    select 1
    from public.driver_profiles d
    where d.project_id=pid
      and d.user_id=actor
      and d.status='active'
      and d.activated_at is not null
      and d.suspended_at is null
  ) then
    raise exception 'DRIVER_NOT_ACTIVE';
  end if;

  if not app_private.marketplace_onboarding_requirements_complete(
    actor,
    target_vehicle_id
  ) then
    raise exception 'MARKETPLACE_ONBOARDING_INCOMPLETE'
      using errcode='22023';
  end if;

  select * into a
  from public.driver_vehicle_assignments
  where project_id=pid
    and driver_user_id=actor
    and vehicle_id=target_vehicle_id
  for update;

  if not found or not a.is_active or not a.is_available then
    raise exception 'VEHICLE_ASSIGNMENT_NOT_AVAILABLE';
  end if;

  if not exists(
    select 1
    from public.vehicles v
    join public.service_requests r
      on r.project_id=j.project_id and r.id=j.service_request_id
    where v.project_id=pid
      and v.id=target_vehicle_id
      and v.deleted_at is null
      and v.marketplace_status='active'
      and (
        coalesce(r.vehicle_category_code,j.pricing_vehicle_category_code) is null
        or v.category_code=coalesce(
          r.vehicle_category_code,
          j.pricing_vehicle_category_code
        )
      )
      and (r.passenger_count is null or v.passenger_capacity>=r.passenger_count)
      and (r.cargo_weight_kg is null or v.cargo_capacity_kg>=r.cargo_weight_kg)
      and (r.cargo_volume_m3 is null or v.cargo_volume_m3>=r.cargo_volume_m3)
      and (r.cargo_length_cm is null or v.cargo_length_cm>=r.cargo_length_cm)
      and (r.cargo_width_cm is null or v.cargo_width_cm>=r.cargo_width_cm)
      and (r.cargo_height_cm is null or v.cargo_height_cm>=r.cargo_height_cm)
      and (
        r.required_body_type is null
        or lower(btrim(v.body_type))=lower(btrim(r.required_body_type))
      )
  ) then
    raise exception 'VEHICLE_INCOMPATIBLE_WITH_SERVICE_REQUEST';
  end if;

  if not exists(
    select 1
    from public.vehicle_services s
    where s.project_id=pid
      and s.vehicle_id=target_vehicle_id
      and s.service_code=j.service_code
      and s.enabled
  ) then
    raise exception 'VEHICLE_SERVICE_NOT_ENABLED';
  end if;

  if trial_active then
    select * into t
    from public.marketplace_work_trials
    where project_id=pid and user_id=actor;

    insert into public.job_assignments(
      project_id,job_id,driver_user_id,vehicle_id,acceptance_idempotency_key,
      billing_mode,commission_amount_snapshot,
      trial_started_at_snapshot,trial_ends_at_snapshot
    )
    values(
      pid,j.id,actor,target_vehicle_id,target_idempotency_key,
      'trial_free',0,t.started_at,t.ends_at
    );
  else
    select f.wallet_currency into wallet_currency
    from public.project_marketplace_financial_settings f
    where f.project_id=pid;

    insert into public.wallets(project_id,user_id,currency)
    values(pid,actor,wallet_currency)
    on conflict (project_id,user_id) do nothing;

    perform 1
    from public.wallets
    where project_id=pid and user_id=actor
    for update;

    amount:=round(j.final_price*j.commission_rate_snapshot,2);

    if amount<=0 then
      raise exception 'INVALID_COMMISSION_AMOUNT';
    end if;

    total:=app_private.marketplace_wallet_total_balance(pid,actor);
    reserved:=app_private.marketplace_wallet_reserved_balance(pid,actor);

    if total-reserved<amount then
      raise exception 'INSUFFICIENT_MARKETPLACE_WALLET_BALANCE'
        using errcode='22023';
    end if;

    insert into public.job_assignments(
      project_id,job_id,driver_user_id,vehicle_id,acceptance_idempotency_key,
      billing_mode,commission_amount_snapshot
    )
    values(
      pid,j.id,actor,target_vehicle_id,target_idempotency_key,
      'wallet_commission',amount
    );

    insert into public.commission_reservations(
      project_id,job_id,user_id,
      final_price_snapshot,commission_rate_snapshot,amount
    )
    values(
      pid,j.id,actor,
      j.final_price,j.commission_rate_snapshot,amount
    )
    returning id into reservation_id;
  end if;

  update public.jobs
  set status='accepted',
      assigned_driver_user_id=actor,
      assigned_vehicle_id=target_vehicle_id,
      state_version=state_version+1
  where project_id=pid and id=j.id
  returning * into j;

  update public.driver_vehicle_assignments
  set is_available=false
  where project_id=pid
    and driver_user_id=actor
    and vehicle_id=target_vehicle_id;

  insert into public.job_events(
    project_id,job_id,from_status,to_status,action,actor_kind,actor_user_id,
    operation_idempotency_key,metadata
  )
  values(
    pid,j.id,'published','accepted','accept','driver',actor,
    target_idempotency_key,
    jsonb_build_object(
      'vehicle_id',target_vehicle_id,
      'billing_mode',case when trial_active then 'trial_free' else 'wallet_commission' end,
      'commission_amount',coalesce(amount,0),
      'trial_ends_at',case when trial_active then t.ends_at else null end,
      'reservation_id',reservation_id,
      'test_mode',j.is_test
    )
  );

  return j;
end;
$function$;

-- ---------------------------------------------------------------------------
-- 7. Gestión Comercial 2.0.
-- ---------------------------------------------------------------------------

create or replace function public.admin_get_marketplace_commercial_settings(
  target_project_id uuid
)
returns table(
  wallet_currency text,
  promotion_duration_days integer,
  promotion_rule_version integer,
  commission_rate numeric,
  updated_at timestamptz,
  updated_by uuid
)
language plpgsql
security definer
set search_path=''
as $function$
begin
  perform app_private.require_project_permission(
    target_project_id,
    'settings.view'
  );

  return query
  select
    s.wallet_currency,
    s.promotion_duration_days,
    s.promotion_rule_version,
    s.commission_rate,
    s.updated_at,
    s.updated_by
  from public.project_marketplace_financial_settings s
  where s.project_id=target_project_id;
end;
$function$;

create or replace function public.admin_set_marketplace_commercial_settings(
  target_project_id uuid,
  target_promotion_duration_days integer,
  target_commission_rate numeric
)
returns public.project_marketplace_financial_settings
language plpgsql
security definer
set search_path=''
as $function$
declare
  actor uuid;
  current_row public.project_marketplace_financial_settings%rowtype;
  result public.project_marketplace_financial_settings%rowtype;
  promotion_changed boolean;
begin
  actor:=app_private.require_project_permission(
    target_project_id,
    'settings.manage'
  );

  if target_promotion_duration_days is null
     or target_promotion_duration_days not between 1 and 365 then
    raise exception 'INVALID_MARKETPLACE_PROMOTION_DURATION'
      using errcode='22023';
  end if;

  if target_commission_rate is null
     or target_commission_rate<=0
     or target_commission_rate>1 then
    raise exception 'INVALID_COMMISSION_RATE'
      using errcode='22023';
  end if;

  select * into current_row
  from public.project_marketplace_financial_settings
  where project_id=target_project_id
  for update;

  if not found then
    raise exception 'MARKETPLACE_FINANCIAL_SETTINGS_NOT_FOUND'
      using errcode='P0002';
  end if;

  promotion_changed:=
    current_row.promotion_duration_days is distinct from target_promotion_duration_days;

  update public.project_marketplace_financial_settings
  set initial_minimum_deposit=0,
      promotion_duration_days=target_promotion_duration_days,
      promotion_rule_version=case
        when promotion_changed then current_row.promotion_rule_version+1
        else current_row.promotion_rule_version
      end,
      promotion_effective_at=case
        when promotion_changed then now()
        else current_row.promotion_effective_at
      end,
      commission_rate=target_commission_rate,
      updated_by=actor,
      updated_at=now()
  where project_id=target_project_id
  returning * into result;

  return result;
end;
$function$;

-- Wrapper legado: jamás vuelve a activar un depósito obligatorio.
create or replace function public.admin_set_marketplace_financial_settings(
  target_project_id uuid,
  target_initial_minimum_deposit numeric,
  target_commission_rate numeric
)
returns public.project_marketplace_financial_settings
language plpgsql
security definer
set search_path=''
as $function$
declare
  actor uuid;
  result public.project_marketplace_financial_settings%rowtype;
begin
  actor:=app_private.require_project_permission(
    target_project_id,
    'settings.manage'
  );

  if target_commission_rate is null
     or target_commission_rate<=0
     or target_commission_rate>1 then
    raise exception 'INVALID_COMMISSION_RATE'
      using errcode='22023';
  end if;

  update public.project_marketplace_financial_settings
  set initial_minimum_deposit=0,
      commission_rate=target_commission_rate,
      updated_by=actor,
      updated_at=now()
  where project_id=target_project_id
  returning * into result;

  if not found then
    raise exception 'MARKETPLACE_FINANCIAL_SETTINGS_NOT_FOUND'
      using errcode='P0002';
  end if;

  return result;
end;
$function$;

revoke execute on function public.admin_get_marketplace_commercial_settings(uuid)
  from public,anon;
revoke execute on function public.admin_set_marketplace_commercial_settings(uuid,integer,numeric)
  from public,anon;
grant execute on function public.admin_get_marketplace_commercial_settings(uuid)
  to authenticated;
grant execute on function public.admin_set_marketplace_commercial_settings(uuid,integer,numeric)
  to authenticated;
