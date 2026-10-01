alter table public.driver_vehicle_assignments
  add column if not exists accepting_jobs boolean not null default true;

comment on column public.driver_vehicle_assignments.accepting_jobs is
  'Preferencia explicita del conductor: true=Trabajando, false=Descansando. Independiente del estado operativo libre/ocupado.';


create or replace function app_private.enforce_marketplace_accepting_jobs()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  if not new.accepting_jobs then
    new.is_available := false;
  end if;

  return new;
end;
$function$;


drop trigger if exists driver_vehicle_assignments_accepting_jobs_guard
on public.driver_vehicle_assignments;

create trigger driver_vehicle_assignments_accepting_jobs_guard
before insert or update of accepting_jobs, is_available
on public.driver_vehicle_assignments
for each row
execute function app_private.enforce_marketplace_accepting_jobs();


create or replace function public.get_my_marketplace_onboarding_v2()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  actor uuid := auth.uid();
  pid uuid;
  result jsonb;
  enriched_vehicles jsonb;
begin
  if actor is null then
    raise exception 'AUTHENTICATION_REQUIRED'
      using errcode = '42501';
  end if;

  select p.id
    into strict pid
  from public.projects p
  where p.slug = 'tuktuk-control';

  result := public.get_my_marketplace_onboarding();

  select coalesce(
    jsonb_agg(
      vehicle.item ||
      jsonb_build_object(
        'accepting_jobs',
        coalesce(assignment.accepting_jobs, true)
      )
      order by vehicle.ordinality
    ),
    '[]'::jsonb
  )
  into enriched_vehicles
  from jsonb_array_elements(
    coalesce(result -> 'vehicles', '[]'::jsonb)
  ) with ordinality as vehicle(item, ordinality)
  left join public.driver_vehicle_assignments assignment
    on assignment.project_id = pid
   and assignment.driver_user_id = actor
   and assignment.vehicle_id = vehicle.item ->> 'vehicle_id';

  return jsonb_set(
    result,
    '{vehicles}',
    enriched_vehicles,
    true
  );
end;
$function$;


revoke all
on function public.get_my_marketplace_onboarding_v2()
from public;

revoke all
on function public.get_my_marketplace_onboarding_v2()
from anon;

grant execute
on function public.get_my_marketplace_onboarding_v2()
to authenticated;


create or replace function public.set_my_marketplace_accepting_jobs(
  target_vehicle_id text,
  target_accepting_jobs boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  actor uuid := auth.uid();
  pid uuid;
  assignment public.driver_vehicle_assignments%rowtype;
  has_blocking_job boolean;
begin
  if actor is null then
    raise exception 'AUTHENTICATION_REQUIRED'
      using errcode = '42501';
  end if;

  if target_vehicle_id is null
     or nullif(btrim(target_vehicle_id), '') is null
     or target_accepting_jobs is null then
    raise exception 'INVALID_ACCEPTING_JOBS_REQUEST'
      using errcode = '22023';
  end if;

  select p.id
    into strict pid
  from public.projects p
  where p.slug = 'tuktuk-control';

  select a.*
    into assignment
  from public.driver_vehicle_assignments a
  join public.vehicles v
    on v.project_id = a.project_id
   and v.id = a.vehicle_id
  where a.project_id = pid
    and a.driver_user_id = actor
    and a.vehicle_id = target_vehicle_id
    and v.owner_user_id = actor
    and v.deleted_at is null
  for update of a;

  if not found then
    raise exception 'VEHICLE_NOT_FOUND_OR_NOT_OWNED'
      using errcode = '42501';
  end if;

  if target_accepting_jobs then

    if not exists (
      select 1
      from public.get_my_marketplace_work_access(target_vehicle_id) access
      where access.onboarding_complete
        and access.driver_active
        and access.suite_active
    ) then
      raise exception 'MARKETPLACE_WORK_ACCESS_DENIED'
        using errcode = '42501';
    end if;

    if not assignment.is_active
       or not exists (
         select 1
         from public.driver_profiles d
         where d.project_id = pid
           and d.user_id = actor
           and d.status = 'active'
           and d.activated_at is not null
           and d.suspended_at is null
       )
       or not app_private.marketplace_onboarding_requirements_complete(
         actor,
         target_vehicle_id
       )
       or not exists (
         select 1
         from public.vehicles v
         where v.project_id = pid
           and v.id = target_vehicle_id
           and v.owner_user_id = actor
           and v.marketplace_status = 'active'
           and v.deleted_at is null
       ) then

      raise exception 'MARKETPLACE_WORK_ACCESS_DENIED'
        using errcode = '42501';

    end if;
  end if;

  select exists (
    select 1
    from public.jobs j
    left join public.marketplace_incident_resolutions resolution
      on resolution.project_id = j.project_id
     and resolution.job_id = j.id
    where j.project_id = pid
      and j.assigned_driver_user_id = actor
      and j.assigned_vehicle_id = target_vehicle_id
      and j.test_deleted_at is null
      and (
        j.status in (
          'accepted',
          'en_route',
          'pickup',
          'in_progress',
          'completed'
        )
        or (
          j.status = 'incident'
          and resolution.id is null
        )
      )
  )
  into has_blocking_job;

  update public.driver_vehicle_assignments a
  set accepting_jobs = target_accepting_jobs,
      is_available = case
        when not target_accepting_jobs then false
        when has_blocking_job then false
        else true
      end,
      updated_at = now()
  where a.project_id = pid
    and a.driver_user_id = actor
    and a.vehicle_id = target_vehicle_id;

  insert into public.audit_events(
    project_id,
    actor_id,
    action,
    entity_type,
    entity_id,
    metadata
  )
  values(
    pid,
    actor,
    'marketplace_accepting_jobs_changed',
    'driver_vehicle_assignments',
    target_vehicle_id,
    jsonb_build_object(
      'accepting_jobs',
      target_accepting_jobs,
      'blocked_by_active_job',
      has_blocking_job
    )
  );

  return public.get_my_marketplace_onboarding_v2();
end;
$function$;


revoke all
on function public.set_my_marketplace_accepting_jobs(text, boolean)
from public;

revoke all
on function public.set_my_marketplace_accepting_jobs(text, boolean)
from anon;

grant execute
on function public.set_my_marketplace_accepting_jobs(text, boolean)
to authenticated;