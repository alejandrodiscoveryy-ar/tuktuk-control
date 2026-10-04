-- TUKTUK 2.0
-- 001: commercial foundation
-- NO elimina legado. Hace el modelo nuevo compatible con datos existentes.

begin;

-- ---------------------------------------------------------------------------
-- 1. Gestión Comercial: promoción configurable y depósito legado neutralizado.
-- ---------------------------------------------------------------------------

alter table public.project_marketplace_financial_settings
  add column if not exists promotion_duration_days integer not null default 30,
  add column if not exists promotion_rule_version integer not null default 1,
  add column if not exists promotion_effective_at timestamptz;

alter table public.project_marketplace_financial_settings
  drop constraint if exists project_marketplace_financial_set_initial_minimum_deposit_check;

alter table public.project_marketplace_financial_settings
  add constraint project_marketplace_financial_settings_initial_minimum_deposit_legacy_check
  check (initial_minimum_deposit >= 0);

alter table public.project_marketplace_financial_settings
  drop constraint if exists project_marketplace_financial_settings_promotion_duration_days_check;

alter table public.project_marketplace_financial_settings
  add constraint project_marketplace_financial_settings_promotion_duration_days_check
  check (promotion_duration_days between 1 and 365);

alter table public.project_marketplace_financial_settings
  drop constraint if exists project_marketplace_financial_settings_promotion_rule_version_check;

alter table public.project_marketplace_financial_settings
  add constraint project_marketplace_financial_settings_promotion_rule_version_check
  check (promotion_rule_version >= 1);

update public.project_marketplace_financial_settings f
set initial_minimum_deposit = 0,
    promotion_duration_days = coalesce(
      (
        select case
          when p.trial_days between 1 and 365 then p.trial_days
          else 30
        end
        from public.projects p
        where p.id = f.project_id
      ),
      30
    ),
    promotion_effective_at = coalesce(promotion_effective_at, now()),
    updated_at = now()
where exists (
  select 1
  from public.projects p
  where p.id = f.project_id
    and p.slug = 'tuktuk-control'
);

comment on column public.project_marketplace_financial_settings.initial_minimum_deposit
  is 'LEGADO TUKTUK 1.x. En TUKTUK 2.0 debe permanecer en 0 y no autoriza/bloquea trabajo.';

comment on column public.project_marketplace_financial_settings.promotion_duration_days
  is 'Duración vigente de la promoción comercial para nuevos conductores. Se congela al iniciar.';

-- ---------------------------------------------------------------------------
-- 2. El registro técnico trial se conserva, pero pasa a representar promoción.
-- ---------------------------------------------------------------------------

alter table public.marketplace_work_trials
  add column if not exists duration_days_snapshot integer not null default 30,
  add column if not exists rule_version_snapshot integer not null default 1,
  add column if not exists activation_source text not null default 'legacy_explicit';

alter table public.marketplace_work_trials
  drop constraint if exists marketplace_work_trials_check;

alter table public.marketplace_work_trials
  drop constraint if exists marketplace_work_trials_duration_snapshot_check;

alter table public.marketplace_work_trials
  add constraint marketplace_work_trials_duration_snapshot_check
  check (
    duration_days_snapshot between 1 and 365
    and ends_at = started_at + (duration_days_snapshot * interval '1 day')
  );

alter table public.marketplace_work_trials
  drop constraint if exists marketplace_work_trials_activation_source_check;

alter table public.marketplace_work_trials
  add constraint marketplace_work_trials_activation_source_check
  check (activation_source in ('legacy_explicit','onboarding_auto','legacy_backfill'));

comment on table public.marketplace_work_trials
  is 'Nombre técnico legado. En TUKTUK 2.0 representa la promoción comercial inicial única del conductor.';

-- Job assignment no puede seguir exigiendo una duración fija de 30 días.
alter table public.job_assignments
  drop constraint if exists job_assignments_billing_mode_check;

alter table public.job_assignments
  add constraint job_assignments_billing_mode_check
  check (
    (
      billing_mode = 'wallet_commission'
      and commission_amount_snapshot > 0
      and trial_started_at_snapshot is null
      and trial_ends_at_snapshot is null
    )
    or
    (
      billing_mode = 'trial_free'
      and commission_amount_snapshot = 0
      and trial_started_at_snapshot is not null
      and trial_ends_at_snapshot is not null
      and trial_ends_at_snapshot > trial_started_at_snapshot
      and accepted_at >= trial_started_at_snapshot
      and accepted_at < trial_ends_at_snapshot
    )
  );

-- ---------------------------------------------------------------------------
-- 3. Catálogos: Bicicleta + propulsión humana/sin motor.
-- ---------------------------------------------------------------------------

insert into public.vehicle_categories(project_id,code,name,active,sort_order)
select p.id,'bicycle','Bicicleta',true,25
from public.projects p
where p.slug='tuktuk-control'
on conflict (project_id,code) do update
set name=excluded.name,
    active=true,
    sort_order=excluded.sort_order,
    updated_at=now();

insert into public.propulsion_types(project_id,code,name,active,sort_order)
select p.id,'human','Humana / sin motor',true,40
from public.projects p
where p.slug='tuktuk-control'
on conflict (project_id,code) do update
set name=excluded.name,
    active=true,
    sort_order=excluded.sort_order,
    updated_at=now();

-- ---------------------------------------------------------------------------
-- 4. Compatibilidad de conductores existentes: crear wallet si falta.
-- ---------------------------------------------------------------------------

insert into public.wallets(project_id,user_id,currency)
select d.project_id,d.user_id,f.wallet_currency
from public.driver_profiles d
join public.projects p
  on p.id=d.project_id and p.slug='tuktuk-control'
join public.project_marketplace_financial_settings f
  on f.project_id=d.project_id
where d.status='active'
  and d.suspended_at is null
on conflict (project_id,user_id) do nothing;

-- Si existiera un conductor activo/completo sin registro promocional por el
-- flujo antiguo, se congela desde su activated_at (no se regalan días nuevos).
do $$
declare
  r record;
  duration_days integer;
  rule_version integer;
  start_at timestamptz;
begin
  select f.promotion_duration_days,f.promotion_rule_version
    into duration_days,rule_version
  from public.project_marketplace_financial_settings f
  join public.projects p on p.id=f.project_id and p.slug='tuktuk-control';

  for r in
    select d.project_id,d.user_id,d.activated_at,a.vehicle_id
    from public.driver_profiles d
    join public.projects p
      on p.id=d.project_id and p.slug='tuktuk-control'
    join lateral (
      select x.vehicle_id
      from public.driver_vehicle_assignments x
      where x.project_id=d.project_id
        and x.driver_user_id=d.user_id
        and x.is_active
        and app_private.marketplace_onboarding_requirements_complete(d.user_id,x.vehicle_id)
      order by x.created_at,x.vehicle_id
      limit 1
    ) a on true
    where d.status='active'
      and d.suspended_at is null
      and d.activated_at is not null
      and not exists (
        select 1
        from public.marketplace_work_trials t
        where t.project_id=d.project_id and t.user_id=d.user_id
      )
  loop
    start_at := coalesce(r.activated_at,now());

    insert into public.marketplace_work_trials(
      project_id,user_id,started_vehicle_id,start_idempotency_key,
      started_at,ends_at,duration_days_snapshot,rule_version_snapshot,
      activation_source
    )
    values(
      r.project_id,r.user_id,r.vehicle_id,gen_random_uuid(),
      start_at,start_at + (duration_days * interval '1 day'),
      duration_days,rule_version,'legacy_backfill'
    );

    update public.vehicles
    set marketplace_status='active',
        updated_at=now()
    where project_id=r.project_id
      and id=r.vehicle_id
      and deleted_at is null
      and marketplace_status<>'suspended';
  end loop;
end $$;
