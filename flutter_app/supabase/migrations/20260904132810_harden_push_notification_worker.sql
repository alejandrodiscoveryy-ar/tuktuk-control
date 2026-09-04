-- Safe, leased claiming and bounded retries for the TukTuk push outbox.
-- The existing Vault secret named tuktuk_push_dispatch_secret must also be
-- configured as the Edge Function secret TUKTUK_PUSH_DISPATCH_SECRET before
-- the hardened function is deployed.

alter table public.notification_outbox
  add column if not exists claim_id uuid,
  add column if not exists claimed_at timestamptz,
  add column if not exists attempt_count integer not null default 0,
  add column if not exists last_attempt_at timestamptz,
  add column if not exists next_attempt_at timestamptz;

alter table public.notification_outbox
  drop constraint if exists notification_outbox_delivery_status_check;

alter table public.notification_outbox
  add constraint notification_outbox_delivery_status_check
  check (delivery_status in ('pending', 'processing', 'sent', 'failed', 'skipped'));

alter table public.notification_outbox
  drop constraint if exists notification_outbox_attempt_count_check;

alter table public.notification_outbox
  add constraint notification_outbox_attempt_count_check
  check (attempt_count >= 0);

create index if not exists notification_outbox_claimable_idx
  on public.notification_outbox(project_id, delivery_status, next_attempt_at, created_at)
  where delivery_status in ('pending', 'processing');

create index if not exists push_device_tokens_enabled_platform_idx
  on public.push_device_tokens(project_id, user_id, platform)
  where enabled;

-- Preserve the existing ownership rules while allowing Postgres to evaluate
-- auth.uid() once per statement instead of once per row.
alter policy notification_outbox_own_select on public.notification_outbox
  using ((select auth.uid()) = user_id);

alter policy push_device_tokens_own_select on public.push_device_tokens
  using ((select auth.uid()) = user_id);

alter policy push_device_tokens_own_insert on public.push_device_tokens
  with check ((select auth.uid()) = user_id);

alter policy push_device_tokens_own_update on public.push_device_tokens
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

alter policy push_device_tokens_own_delete on public.push_device_tokens
  using ((select auth.uid()) = user_id);

create or replace function public.claim_push_notification_batch(
  target_project_id uuid,
  batch_limit integer default 100,
  lease_seconds integer default 300,
  max_attempts integer default 5,
  allowed_kinds text[] default array[
    'daily_exchange_rate',
    'exchange_rate_update',
    'app_announcement',
    'app_update'
  ]::text[]
)
returns setof public.notification_outbox
language plpgsql
security invoker
set search_path = ''
as $function$
begin
  if batch_limit < 1 or batch_limit > 500 then
    raise exception 'INVALID_BATCH_LIMIT' using errcode = '22023';
  end if;
  if lease_seconds < 30 or lease_seconds > 900 then
    raise exception 'INVALID_LEASE_SECONDS' using errcode = '22023';
  end if;
  if max_attempts < 1 or max_attempts > 20 then
    raise exception 'INVALID_MAX_ATTEMPTS' using errcode = '22023';
  end if;
  if allowed_kinds is null or cardinality(allowed_kinds) = 0 then
    raise exception 'INVALID_ALLOWED_KINDS' using errcode = '22023';
  end if;

  update public.notification_outbox as exhausted
  set delivery_status = 'failed',
      last_error = coalesce(exhausted.last_error, 'Worker lease expired after maximum attempts'),
      claim_id = null,
      claimed_at = null,
      next_attempt_at = null
  where exhausted.project_id = target_project_id
    and exhausted.delivery_status = 'processing'
    and exhausted.claimed_at < now() - make_interval(secs => lease_seconds)
    and exhausted.attempt_count >= max_attempts;

  return query
  with candidates as (
    select queued.id
    from public.notification_outbox as queued
    where queued.project_id = target_project_id
      and queued.kind = any(allowed_kinds)
      and queued.attempt_count < max_attempts
      and (
        (
          queued.delivery_status = 'pending'
          and (queued.next_attempt_at is null or queued.next_attempt_at <= now())
        )
        or (
          queued.delivery_status = 'processing'
          and queued.claimed_at < now() - make_interval(secs => lease_seconds)
        )
      )
    order by queued.created_at, queued.id
    for update skip locked
    limit batch_limit
  ), claimed as (
    update public.notification_outbox as queued
    set delivery_status = 'processing',
        claim_id = gen_random_uuid(),
        claimed_at = now(),
        last_attempt_at = now(),
        next_attempt_at = null,
        attempt_count = queued.attempt_count + 1
    from candidates
    where queued.id = candidates.id
    returning queued.*
  )
  select * from claimed;
end;
$function$;

comment on function public.claim_push_notification_batch(uuid, integer, integer, integer, text[])
  is 'Atomically leases push outbox rows with SKIP LOCKED; callable only by the backend service role.';

revoke all on function public.claim_push_notification_batch(uuid, integer, integer, integer, text[]) from public;
revoke all on function public.claim_push_notification_batch(uuid, integer, integer, integer, text[]) from anon;
revoke all on function public.claim_push_notification_batch(uuid, integer, integer, integer, text[]) from authenticated;
grant execute on function public.claim_push_notification_batch(uuid, integer, integer, integer, text[]) to service_role;

create or replace function public.admin_send_mobile_announcement(
  target_project_id uuid,
  target_category text,
  target_title text,
  target_body text,
  target_release_version text default null,
  target_action_url text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  actor uuid;
  broadcast_id uuid := gen_random_uuid();
  queued_users integer := 0;
  notice_kind text;
  notification_day date;
  timezone_name text := 'America/Havana';
  dispatch_request_id bigint;
  dispatch_triggered boolean := false;
  dispatch_secret text;
begin
  actor := app_private.require_project_permission(target_project_id, 'settings.manage');

  if target_category not in ('general', 'app_update') then
    raise exception 'INVALID_ANNOUNCEMENT_CATEGORY' using errcode = '22023';
  end if;
  if nullif(btrim(target_title), '') is null or length(btrim(target_title)) > 100 then
    raise exception 'INVALID_ANNOUNCEMENT_TITLE' using errcode = '22023';
  end if;
  if nullif(btrim(target_body), '') is null or length(btrim(target_body)) > 500 then
    raise exception 'INVALID_ANNOUNCEMENT_BODY' using errcode = '22023';
  end if;
  if target_release_version is not null and length(btrim(target_release_version)) > 40 then
    raise exception 'INVALID_RELEASE_VERSION' using errcode = '22023';
  end if;
  if target_action_url is not null and length(btrim(target_action_url)) > 500 then
    raise exception 'INVALID_ACTION_URL' using errcode = '22023';
  end if;

  select coalesce(settings.daily_rate_notification_timezone, timezone_name)
  into timezone_name
  from public.project_exchange_settings as settings
  where settings.project_id = target_project_id;

  timezone_name := coalesce(timezone_name, 'America/Havana');
  notification_day := timezone(timezone_name, now())::date;
  notice_kind := case when target_category = 'app_update' then 'app_update' else 'app_announcement' end;

  insert into public.notification_outbox(
    project_id, user_id, kind, notification_date, dedupe_key, title, body, data
  )
  select distinct
    target_project_id,
    license.user_id,
    notice_kind,
    notification_day,
    'announcement:' || broadcast_id::text,
    btrim(target_title),
    btrim(target_body),
    jsonb_strip_nulls(jsonb_build_object(
      'announcement_id', broadcast_id,
      'category', target_category,
      'target_platform', 'android',
      'release_version', nullif(btrim(coalesce(target_release_version, '')), ''),
      'action_url', nullif(btrim(coalesce(target_action_url, '')), ''),
      'created_by', actor,
      'created_at', now()
    ))
  from public.licenses as license
  where license.project_id = target_project_id
    and license.status = 'active'
    and (license.expires_at is null or license.expires_at > now())
    and exists (
      select 1
      from public.push_device_tokens as token
      where token.project_id = license.project_id
        and token.user_id = license.user_id
        and token.enabled
        and token.platform = 'android'
    )
  on conflict (project_id, user_id, kind, dedupe_key) do nothing;

  get diagnostics queued_users = row_count;

  if queued_users > 0 then
    begin
      select secret.decrypted_secret
      into dispatch_secret
      from vault.decrypted_secrets as secret
      where secret.name = 'tuktuk_push_dispatch_secret'
      limit 1;

      if nullif(dispatch_secret, '') is not null then
        select net.http_post(
          url := 'https://vvxvnywzgtqhlaqpxyqh.supabase.co/functions/v1/send-push-notifications',
          body := jsonb_build_object('limit', 100),
          headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'x-tuktuk-dispatch-secret', dispatch_secret
          ),
          timeout_milliseconds := 5000
        ) into dispatch_request_id;
        dispatch_triggered := dispatch_request_id is not null;
      end if;
    exception when others then
      dispatch_request_id := null;
      dispatch_triggered := false;
    end;
  end if;

  insert into public.audit_events(project_id, actor_id, action, entity_type, entity_id, metadata)
  values(
    target_project_id,
    actor,
    'send',
    'push_announcement',
    broadcast_id::text,
    jsonb_strip_nulls(jsonb_build_object(
      'category', target_category,
      'title', btrim(target_title),
      'release_version', nullif(btrim(coalesce(target_release_version, '')), ''),
      'action_url', nullif(btrim(coalesce(target_action_url, '')), ''),
      'target_platform', 'android',
      'queued_users', queued_users,
      'dispatch_triggered', dispatch_triggered,
      'dispatch_request_id', dispatch_request_id
    ))
  );

  return jsonb_build_object(
    'ok', true,
    'broadcast_id', broadcast_id,
    'kind', notice_kind,
    'target_platform', 'android',
    'queued_users', queued_users,
    'dispatch_triggered', dispatch_triggered,
    'dispatch_request_id', dispatch_request_id
  );
end;
$function$;

do $block$
declare
  existing_job_id bigint;
begin
  select jobid into existing_job_id from cron.job where jobname = 'tuktuk-push-dispatch';
  if existing_job_id is not null then
    perform cron.unschedule(existing_job_id);
  end if;
end;
$block$;

select cron.schedule(
  'tuktuk-push-dispatch',
  '*/5 * * * *',
  $cron$
    select net.http_post(
      url := 'https://vvxvnywzgtqhlaqpxyqh.supabase.co/functions/v1/send-push-notifications',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-tuktuk-dispatch-secret', (
          select decrypted_secret
          from vault.decrypted_secrets
          where name = 'tuktuk_push_dispatch_secret'
          limit 1
        )
      ),
      body := jsonb_build_object('limit', 100),
      timeout_milliseconds := 5000
    );
  $cron$
);
