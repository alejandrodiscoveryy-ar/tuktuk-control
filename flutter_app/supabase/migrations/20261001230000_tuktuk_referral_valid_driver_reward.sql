begin;

alter table public.project_referral_settings
  add column if not exists registration_valid_driver_reward_effective_at timestamptz;

do $migration$
declare
  pid uuid;
begin
  select id into pid
  from public.projects
  where slug = 'tuktuk-control';

  if pid is null then
    raise exception 'TUKTUK_PROJECT_NOT_FOUND';
  end if;

  update public.project_referral_settings s
  set reward_rule_version = case
        when s.registration_valid_driver_reward_effective_at is null
          then coalesce(s.reward_rule_version, 1) + 1
        else s.reward_rule_version
      end,
      registration_valid_driver_reward_effective_at =
        coalesce(s.registration_valid_driver_reward_effective_at, now()),
      updated_at = now()
  where s.project_id = pid
    and s.reward_mode = 'registration_wallet_license';

  if not found then
    raise exception 'TUKTUK_REFERRAL_SETTINGS_NOT_FOUND';
  end if;
end;
$migration$;

alter table public.marketplace_referral_rewards
  drop constraint if exists marketplace_referral_rewards_qualification_kind_check,
  drop constraint if exists marketplace_referral_rewards_registration_shape_check;

alter table public.marketplace_referral_rewards
  add constraint marketplace_referral_rewards_qualification_kind_check
  check (
    qualification_kind = any(array[
      'first_valid_job'::text,
      'registration_code_claim'::text,
      'legacy_transition'::text,
      'valid_driver_profile'::text
    ])
  ),
  add constraint marketplace_referral_rewards_registration_shape_check
  check (
    (
      qualification_kind =
        any(array['registration_code_claim'::text, 'legacy_transition'::text])
      and qualification_job_id is null
      and license_months_snapshot = 3
      and license_application_status = any(array[
        'applied'::text,
        'pending_no_license'::text,
        'pending_ineligible_license'::text,
        'pending_indefinite'::text
      ])
    )
    or (
      qualification_kind = 'first_valid_job'::text
      and license_months_snapshot = 0
    )
    or (
      qualification_kind = 'valid_driver_profile'::text
      and qualification_job_id is null
      and license_months_snapshot = 0
      and license_id is null
      and license_application_status = 'not_applicable'::text
      and previous_license_expires_at is null
      and new_license_expires_at is null
      and license_applied_at is null
    )
  );

create or replace function app_private.tuktuk_referred_driver_is_valid(
  target_project_id uuid,
  target_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select
    target_project_id is not null
    and target_user_id is not null
    and exists (
      select 1
      from public.driver_profiles d
      where d.project_id = target_project_id
        and d.user_id = target_user_id
        and d.status = 'active'
        and d.activated_at is not null
        and d.suspended_at is null
        and exists (
          select 1
          from public.driver_vehicle_assignments a
          join public.vehicles v
            on v.project_id = a.project_id
           and v.id = a.vehicle_id
          where a.project_id = d.project_id
            and a.driver_user_id = d.user_id
            and a.is_active
            and v.deleted_at is null
            and v.marketplace_status = 'active'
            and app_private.marketplace_onboarding_requirements_complete(
              d.user_id,
              a.vehicle_id
            )
        )
    );
$function$;

create or replace function app_private.award_tuktuk_valid_driver_referral_reward(
  target_project_id uuid,
  target_relationship_id uuid,
  target_referred_user_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
set "TimeZone" = 'UTC'
as $function$
declare
  settings public.project_referral_settings%rowtype;
  relationship public.referral_relationships%rowtype;
  wallet public.wallets%rowtype;
  prior_balance numeric;
  transaction_id uuid;
  reward_id uuid;
  now_at timestamptz := now();
begin
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'tuktuk-valid-driver-referral:'
      || target_project_id::text
      || ':'
      || target_referred_user_id::text,
      0
    )
  );

  if not exists (
    select 1
    from public.projects p
    where p.id = target_project_id
      and p.slug = 'tuktuk-control'
  ) then
    return null;
  end if;

  if auth.uid() is distinct from target_referred_user_id then
    raise exception 'REFERRED_USER_AUTH_MISMATCH'
      using errcode = '42501';
  end if;

  select *
    into settings
  from public.project_referral_settings
  where project_id = target_project_id
  for update;

  if not found
     or settings.reward_mode <> 'registration_wallet_license'
     or not settings.reward_enabled
     or settings.reward_amount <> 100.00
     or settings.reward_currency <> 'CUP'
     or settings.registration_valid_driver_reward_effective_at is null then
    return null;
  end if;

  select *
    into relationship
  from public.referral_relationships r
  where r.id = target_relationship_id
    and r.project_id = target_project_id
    and r.referred_user_id = target_referred_user_id
    and not r.is_test
  for update;

  if not found
     or relationship.referrer_user_id = target_referred_user_id
     or relationship.created_at <
        settings.registration_valid_driver_reward_effective_at then
    return null;
  end if;

  if not app_private.tuktuk_referred_driver_is_valid(
    target_project_id,
    target_referred_user_id
  ) then
    return null;
  end if;

  select r.id
    into reward_id
  from public.marketplace_referral_rewards r
  where r.project_id = target_project_id
    and r.referred_user_id = target_referred_user_id;

  if reward_id is not null then
    return reward_id;
  end if;

  if exists (
       select 1
       from public.marketplace_legacy_referral_entitlements e
       where e.project_id = target_project_id
         and e.relationship_id = target_relationship_id
     )
     or exists (
       select 1
       from public.referral_reward_ledger l
       where l.project_id = target_project_id
         and l.referred_user_id = target_referred_user_id
         and not l.is_test
         and l.status in ('earned', 'applied')
     )
     or exists (
       select 1
       from public.marketplace_legacy_referral_reward_transitions t
       where t.project_id = target_project_id
         and t.referred_user_id = target_referred_user_id
     ) then
    return null;
  end if;

  insert into public.wallets(project_id, user_id, currency)
  select
    target_project_id,
    relationship.referrer_user_id,
    f.wallet_currency
  from public.project_marketplace_financial_settings f
  where f.project_id = target_project_id
  on conflict do nothing;

  select *
    into wallet
  from public.wallets
  where project_id = target_project_id
    and user_id = relationship.referrer_user_id
  for update;

  if not found or wallet.currency <> settings.reward_currency then
    return null;
  end if;

  prior_balance :=
    app_private.marketplace_wallet_total_balance(
      target_project_id,
      relationship.referrer_user_id
    );

  insert into public.wallet_transactions(
    project_id,
    user_id,
    currency,
    transaction_type,
    amount_delta,
    balance_after,
    source_type,
    source_id,
    idempotency_key,
    metadata
  )
  values(
    target_project_id,
    relationship.referrer_user_id,
    settings.reward_currency,
    'referral_credit',
    settings.reward_amount,
    prior_balance + settings.reward_amount,
    'referral_reward',
    target_relationship_id::text,
    gen_random_uuid(),
    jsonb_build_object(
      'relationship_id', target_relationship_id,
      'referrer_user_id', relationship.referrer_user_id,
      'referred_user_id', target_referred_user_id,
      'qualification_kind', 'valid_driver_profile',
      'reward_amount', settings.reward_amount,
      'reward_currency', settings.reward_currency,
      'reward_rule_version', settings.reward_rule_version
    )
  )
  returning id into transaction_id;

  insert into public.marketplace_referral_rewards(
    project_id,
    relationship_id,
    referrer_user_id,
    referred_user_id,
    qualification_job_id,
    qualification_kind,
    reward_amount_snapshot,
    reward_currency_snapshot,
    reward_rule_version_snapshot,
    wallet_transaction_id,
    qualified_at,
    license_months_snapshot,
    license_application_status
  )
  values(
    target_project_id,
    target_relationship_id,
    relationship.referrer_user_id,
    target_referred_user_id,
    null,
    'valid_driver_profile',
    settings.reward_amount,
    settings.reward_currency,
    settings.reward_rule_version,
    transaction_id,
    now_at,
    0,
    'not_applicable'
  )
  returning id into reward_id;

  update public.referral_relationships
  set qualified_at = coalesce(qualified_at, now_at),
      updated_at = now_at
  where id = target_relationship_id;

  return reward_id;
end;
$function$;

do $migration$
begin
  if to_regprocedure(
    'app_private.award_tuktuk_registration_referral_reward_legacy(uuid,uuid,uuid)'
  ) is null then
    alter function
      app_private.award_tuktuk_registration_referral_reward(uuid,uuid,uuid)
      rename to award_tuktuk_registration_referral_reward_legacy;
  end if;
end;
$migration$;

create or replace function app_private.award_tuktuk_registration_referral_reward(
  target_project_id uuid,
  target_relationship_id uuid,
  target_referred_user_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
set "TimeZone" = 'UTC'
as $function$
declare
  cutoff timestamptz;
  relationship_created_at timestamptz;
begin
  select s.registration_valid_driver_reward_effective_at
    into cutoff
  from public.project_referral_settings s
  where s.project_id = target_project_id;

  select r.created_at
    into relationship_created_at
  from public.referral_relationships r
  where r.id = target_relationship_id
    and r.project_id = target_project_id
    and r.referred_user_id = target_referred_user_id
    and not r.is_test;

  if relationship_created_at is null then
    return null;
  end if;

  if cutoff is null or relationship_created_at < cutoff then
    return app_private.award_tuktuk_registration_referral_reward_legacy(
      target_project_id,
      target_relationship_id,
      target_referred_user_id
    );
  end if;

  return app_private.award_tuktuk_valid_driver_referral_reward(
    target_project_id,
    target_relationship_id,
    target_referred_user_id
  );
end;
$function$;

create or replace function app_private.maybe_award_tuktuk_valid_driver_referral(
  target_project_id uuid,
  target_referred_user_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  relationship_id uuid;
begin
  if auth.uid() is distinct from target_referred_user_id then
    return null;
  end if;

  select r.id
    into relationship_id
  from public.referral_relationships r
  join public.project_referral_settings s
    on s.project_id = r.project_id
  where r.project_id = target_project_id
    and r.referred_user_id = target_referred_user_id
    and not r.is_test
    and s.registration_valid_driver_reward_effective_at is not null
    and r.created_at >=
        s.registration_valid_driver_reward_effective_at
  order by r.created_at
  limit 1;

  if relationship_id is null then
    return null;
  end if;

  return app_private.award_tuktuk_valid_driver_referral_reward(
    target_project_id,
    relationship_id,
    target_referred_user_id
  );
end;
$function$;

do $migration$
begin
  if to_regprocedure('public.get_my_referral_program_legacy(uuid)') is null then
    alter function public.get_my_referral_program(uuid)
      rename to get_my_referral_program_legacy;
  end if;
end;
$migration$;

create or replace function public.get_my_referral_program(
  target_project_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  actor uuid := auth.uid();
  result jsonb;
  current_mode text;
  rewarded_count_value bigint;
begin
  if actor is null then
    raise exception 'AUTHENTICATION_REQUIRED'
      using errcode = '42501';
  end if;

  result := public.get_my_referral_program_legacy(target_project_id);

  select reward_mode
    into current_mode
  from public.project_referral_settings
  where project_id = target_project_id;

  if current_mode = 'registration_wallet_license'
     and exists (
       select 1
       from public.projects
       where id = target_project_id
         and slug = 'tuktuk-control'
     ) then

    select count(*)
      into rewarded_count_value
    from public.marketplace_referral_rewards r
    where r.project_id = target_project_id
      and r.referrer_user_id = actor;

    result :=
      jsonb_set(result, '{qualification_mode}', '"valid_driver_profile"', true);

    result :=
      jsonb_set(result, '{license_months}', '0'::jsonb, true);

    result :=
      jsonb_set(result, '{reward_months}', '0'::jsonb, true);

    result :=
      jsonb_set(
        result,
        '{rewarded_count}',
        to_jsonb(rewarded_count_value),
        true
      );
  end if;

  return result;
end;
$function$;

create or replace function public.start_my_marketplace_work_trial(
  target_vehicle_id text,
  target_idempotency_key uuid
)
returns public.marketplace_work_trials
language plpgsql
security definer
set search_path = ''
as $function$
declare
  actor uuid := auth.uid();
  pid uuid;
  trial public.marketplace_work_trials%rowtype;
  started timestamptz;
begin
  if actor is null then
    raise exception 'AUTHENTICATION_REQUIRED'
      using errcode = '42501';
  end if;

  if target_idempotency_key is null then
    raise exception 'IDEMPOTENCY_KEY_REQUIRED'
      using errcode = '22023';
  end if;

  select id into pid
  from public.projects
  where slug = 'tuktuk-control';

  if pid is null then
    raise exception 'TUKTUK_PROJECT_NOT_FOUND';
  end if;

  perform 1
  from public.driver_profiles
  where project_id = pid
    and user_id = actor
  for update;

  if not found then
    raise exception 'DRIVER_PROFILE_NOT_FOUND'
      using errcode = 'P0002';
  end if;

  if exists (
    select 1
    from public.driver_profiles
    where project_id = pid
      and user_id = actor
      and (
        status = 'suspended'
        or suspended_at is not null
      )
  ) then
    raise exception 'DRIVER_SUSPENDED'
      using errcode = '42501';
  end if;

  select *
    into trial
  from public.marketplace_work_trials
  where project_id = pid
    and user_id = actor
  for update;

  if found then
    if trial.start_idempotency_key = target_idempotency_key
       and trial.started_vehicle_id = target_vehicle_id then
      perform app_private.maybe_award_tuktuk_valid_driver_referral(
        pid,
        actor
      );
      return trial;
    end if;

    raise exception 'WORK_TRIAL_ALREADY_STARTED'
      using errcode = '22023';
  end if;

  perform 1
  from public.driver_vehicle_assignments
  where project_id = pid
    and driver_user_id = actor
    and vehicle_id = target_vehicle_id
  for update;

  if not found then
    raise exception 'VEHICLE_ASSIGNMENT_NOT_FOUND'
      using errcode = 'P0002';
  end if;

  perform 1
  from public.vehicles
  where project_id = pid
    and id = target_vehicle_id
  for update;

  if not found then
    raise exception 'VEHICLE_NOT_FOUND'
      using errcode = 'P0002';
  end if;

  if not app_private.marketplace_onboarding_requirements_complete(
    actor,
    target_vehicle_id
  ) then
    raise exception 'MARKETPLACE_ONBOARDING_INCOMPLETE'
      using errcode = '22023';
  end if;

  started := now();

  insert into public.marketplace_work_trials(
    project_id,
    user_id,
    started_vehicle_id,
    start_idempotency_key,
    started_at,
    ends_at
  )
  values(
    pid,
    actor,
    target_vehicle_id,
    target_idempotency_key,
    started,
    started + interval '30 days'
  )
  returning * into trial;

  update public.driver_profiles
  set status = 'active',
      activated_at = coalesce(activated_at, started)
  where project_id = pid
    and user_id = actor;

  update public.vehicles
  set marketplace_status = 'active'
  where project_id = pid
    and id = target_vehicle_id;

  perform app_private.maybe_award_tuktuk_valid_driver_referral(
    pid,
    actor
  );

  return trial;
end;
$function$;

commit;