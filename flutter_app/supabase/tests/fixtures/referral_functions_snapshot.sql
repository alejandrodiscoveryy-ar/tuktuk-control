-- Read-only production snapshot, 2026-09-07. TEST FIXTURE ONLY.
-- Not a migration: never apply to production or replace migration history.
CREATE OR REPLACE FUNCTION app_private.p0d_apply_earned_rewards(target_project_id uuid, target_referrer_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  target_license public.licenses%rowtype;
  reward public.referral_reward_ledger%rowtype;
  actor uuid;
  original_expiry timestamptz;
  running_expiry timestamptz;
  previous_expiry timestamptz;
  next_expiry timestamptz;
  reactivating boolean := false;
  applied_count integer := 0;
begin
  select license.* into target_license
  from public.licenses license
  where license.project_id = target_project_id
    and license.user_id = target_referrer_id
    and license.license_type <> 'admin'
    and license.expires_at is not null
    and license.status in ('active','expired')
  order by
    case
      when license.status = 'active' and license.expires_at > now() then 0
      when license.status = 'expired' then 1
      else 2
    end,
    license.expires_at desc,
    license.updated_at desc,
    license.id
  limit 1
  for update;

  if not found then return 0; end if;

  select coalesce(payment.recorded_by, project.owner_id) into actor
  from public.projects project
  left join public.payments payment on payment.id = target_license.last_payment_id
  where project.id = target_project_id;

  original_expiry := target_license.expires_at;
  reactivating := target_license.status = 'expired' or target_license.expires_at <= now();
  running_expiry := case
    when reactivating then now()
    else target_license.expires_at
  end;

  for reward in
    select ledger.*
    from public.referral_reward_ledger ledger
    join public.referral_relationships relationship
      on relationship.id = ledger.relationship_id
    where ledger.project_id = target_project_id
      and ledger.referrer_user_id = target_referrer_id
      and ledger.status = 'earned'
      and not ledger.is_test
      and not relationship.is_test
    order by ledger.created_at, ledger.id
    for update of ledger
  loop
    previous_expiry := case
      when applied_count = 0 and reactivating then original_expiry
      else running_expiry
    end;
    next_expiry := running_expiry + make_interval(days => reward.reward_days);

    update public.referral_reward_ledger
    set status = 'applied',
        applied_license_id = target_license.id,
        previous_expires_at = previous_expiry,
        new_expires_at = next_expiry,
        applied_at = now(),
        application_note = case
          when reactivating then 'Aplicada automáticamente reactivando licencia vencida'
          when target_license.license_type = 'trial' then 'Aplicada automáticamente a prueba activa'
          else 'Aplicada automáticamente a licencia activa'
        end,
        updated_at = now()
    where id = reward.id;

    insert into public.license_audit_log(
      project_id, license_id, action, detail, actor_id, metadata
    )
    values(
      target_project_id,
      target_license.id,
      case when reactivating then 'referral_reward_reactivated' else 'referral_reward_applied' end,
      case
        when reactivating then 'Días de referido aplicados reactivando licencia vencida'
        else 'Días de referido aplicados'
      end,
      actor,
      jsonb_build_object(
        'reward_id', reward.id,
        'referred_user_id', reward.referred_user_id,
        'reward_days', reward.reward_days,
        'license_type', target_license.license_type,
        'reactivated', reactivating,
        'previous_expires_at', previous_expiry,
        'new_expires_at', next_expiry
      )
    );

    running_expiry := next_expiry;
    applied_count := applied_count + 1;
  end loop;

  if applied_count > 0 then
    update public.licenses
    set status = 'active',
        expires_at = running_expiry,
        updated_at = now()
    where id = target_license.id;
  end if;

  return applied_count;
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_my_referrals(target_project_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare actor uuid;
begin
  actor:=auth.uid();
  if actor is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'relationship_id',r.id,
      'name',coalesce(nullif(p.display_name,''),'Usuario'),
      'status',case
        when l.status='applied' then 'rewarded'
        when l.status='earned' then 'qualified'
        when r.qualified_at is not null then 'qualified'
        else 'registered'
      end,
      'reward_days',coalesce(l.reward_days,r.reward_days),
      'created_at',r.created_at,
      'qualified_at',r.qualified_at
    ) order by r.created_at desc)
    from public.referral_relationships r
    join public.profiles p on p.id=r.referred_user_id
    left join public.referral_reward_ledger l on l.relationship_id=r.id and not l.is_test
    where r.project_id=target_project_id and r.referrer_user_id=actor and not r.is_test
  ),'[]'::jsonb);
end;
$function$;

CREATE OR REPLACE FUNCTION app_private.p1_register_referral(target_project_id uuid, target_referred_user_id uuid, target_code text, target_source text, target_actor uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  campaign public.referral_campaigns%rowtype;
  referrer_id uuid;
  existing public.referral_relationships%rowtype;
  relationship_id uuid;
  reward_id uuid;
begin
  if target_actor is null or target_referred_user_id is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501';
  end if;

  if not exists(select 1 from public.profiles p where p.id=target_referred_user_id) then
    raise exception 'REFERRED_USER_NOT_FOUND' using errcode='P0002';
  end if;

  campaign:=app_private.p1_current_referral_campaign(target_project_id);
  if campaign.id is null then
    raise exception 'REFERRAL_PROGRAM_NOT_ACTIVE' using errcode='22023';
  end if;

  referrer_id:=app_private.p0d_resolve_referral_code(target_project_id,target_code);
  if referrer_id is null then
    raise exception 'REFERRAL_CODE_NOT_FOUND' using errcode='P0002';
  end if;

  if referrer_id=target_referred_user_id then
    raise exception 'SELF_REFERRAL_NOT_ALLOWED' using errcode='22023';
  end if;

  select * into existing
  from public.referral_relationships r
  where r.project_id=target_project_id
    and r.referred_user_id=target_referred_user_id
    and not r.is_test
  for update;

  if found then
    if existing.referrer_user_id<>referrer_id then
      raise exception 'REFERRAL_RELATIONSHIP_LOCKED' using errcode='22023';
    end if;
    return existing.id;
  end if;

  if exists(
    select 1 from public.payments p
    where p.project_id=target_project_id
      and p.user_id=target_referred_user_id
      and p.status='paid'
      and not p.is_test
  ) then
    raise exception 'REFERRAL_RELATIONSHIP_LOCKED' using errcode='22023';
  end if;

  insert into public.referral_relationships(
    project_id,referrer_user_id,referred_user_id,referral_code,source,is_test,
    created_by,updated_by,campaign_id,qualification_mode,reward_days,qualified_at
  ) values (
    target_project_id,referrer_id,target_referred_user_id,upper(btrim(target_code)),
    coalesce(nullif(btrim(target_source),''),'referral_link'),false,
    target_actor,target_actor,campaign.id,campaign.qualification_mode,campaign.reward_days,
    case when campaign.qualification_mode='registration' then now() else null end
  ) returning id into relationship_id;

  if campaign.qualification_mode='registration' then
    insert into public.referral_reward_ledger(
      project_id,relationship_id,referrer_user_id,referred_user_id,
      qualifying_payment_id,reward_days,status,is_test,created_by,note
    ) values (
      target_project_id,relationship_id,referrer_id,target_referred_user_id,
      null,campaign.reward_days,'earned',false,target_actor,
      'Recompensa obtenida por registro durante la campaña '||campaign.name
    )
    on conflict(project_id,referred_user_id) where not is_test do nothing
    returning id into reward_id;

    perform app_private.p0d_apply_earned_rewards(target_project_id,referrer_id);
  end if;

  return relationship_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.claim_referral_code(target_project_id uuid, target_code text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare actor uuid;
begin
  actor:=auth.uid();
  if actor is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501'; end if;
  return app_private.p1_register_referral(
    target_project_id,actor,target_code,'referral_link',actor
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_my_referral_program(target_project_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  actor uuid;
  own_code text;
  share_base text;
  campaign public.referral_campaigns%rowtype;
begin
  actor := auth.uid();
  if actor is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501';
  end if;
  if not exists(select 1 from public.profiles p where p.id=actor) then
    raise exception 'PROFILE_NOT_FOUND' using errcode='P0002';
  end if;

  own_code := app_private.p0d_ensure_referral_code(target_project_id, actor);
  select s.share_base_url into share_base
  from public.project_referral_settings s
  where s.project_id=target_project_id;
  campaign := app_private.p1_current_referral_campaign(target_project_id);

  return jsonb_build_object(
    'enabled', campaign.id is not null,
    'campaign_id', campaign.id,
    'campaign_name', campaign.name,
    'qualification_mode', campaign.qualification_mode,
    'reward_days', campaign.reward_days,
    'code', own_code,
    'link', case when share_base is null then null else share_base || case when position('?' in share_base)>0 then '&' else '?' end || 'ref=' || own_code end,
    'referred_count', (select count(*) from public.referral_relationships r where r.project_id=target_project_id and r.referrer_user_id=actor and not r.is_test),
    'qualified_count', (select count(*) from public.referral_relationships r where r.project_id=target_project_id and r.referrer_user_id=actor and not r.is_test and r.qualified_at is not null),
    -- "Obtenidas" representa todas las recompensas legítimamente ganadas,
    -- tanto si siguen pendientes como si ya fueron aplicadas.
    'earned_rewards', (select count(*) from public.referral_reward_ledger l where l.project_id=target_project_id and l.referrer_user_id=actor and l.status in ('earned','applied') and not l.is_test),
    'applied_rewards', (select count(*) from public.referral_reward_ledger l where l.project_id=target_project_id and l.referrer_user_id=actor and l.status='applied' and not l.is_test),
    'earned_days', (select coalesce(sum(l.reward_days),0) from public.referral_reward_ledger l where l.project_id=target_project_id and l.referrer_user_id=actor and l.status in ('earned','applied') and not l.is_test),
    'applied_days', (select coalesce(sum(l.reward_days),0) from public.referral_reward_ledger l where l.project_id=target_project_id and l.referrer_user_id=actor and l.status='applied' and not l.is_test)
  );
end;
$function$;

