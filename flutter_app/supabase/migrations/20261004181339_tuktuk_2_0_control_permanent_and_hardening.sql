create or replace function app_private.has_control_write_entitlement(
  target_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path=''
as $function$
  select target_user_id is not null
     and exists (
       select 1
       from public.profiles p
       where p.id=target_user_id
     );
$function$;

comment on function app_private.has_control_write_entitlement(uuid)
  is 'TUKTUK 2.0: Control y Estadísticas son permanentes para todo usuario autenticado con perfil; no dependen de licencia, promoción, wallet ni estado Marketplace.';

create or replace function app_private.has_active_marketplace_suite(
  target_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path=''
as $function$
  select target_user_id is not null
    and exists (
      select 1
      from public.driver_profiles d
      join public.projects p
        on p.id=d.project_id
       and p.slug='tuktuk-control'
      where d.user_id=target_user_id
        and d.status='active'
        and d.activated_at is not null
        and d.suspended_at is null
        and exists (
          select 1
          from public.driver_vehicle_assignments a
          join public.vehicles v
            on v.project_id=a.project_id
           and v.id=a.vehicle_id
          where a.project_id=d.project_id
            and a.driver_user_id=d.user_id
            and a.is_active
            and v.deleted_at is null
            and v.marketplace_status='active'
            and app_private.marketplace_onboarding_requirements_complete(
              d.user_id,
              a.vehicle_id
            )
        )
    );
$function$;

comment on function app_private.has_active_marketplace_suite(uuid)
  is 'TUKTUK 2.0: estado operativo Marketplace. No exige depósito; la capacidad de aceptar un trabajo fuera de promoción depende del saldo para la comisión.';

update public.projects
set notify_license_expiry=false,
    auto_renew_verified_payments=false,
    description='Aplicación para control permanente de ingresos, gastos, kilometraje, voltaje y mantenimiento, integrada con TUKTUK Marketplace.',
    updated_at=now()
where slug='tuktuk-control';

create index if not exists marketplace_financial_documents_topup_fk_idx
  on public.marketplace_financial_documents(project_id,user_id,topup_id);

create index if not exists marketplace_financial_documents_correction_idx
  on public.marketplace_financial_documents(correction_of_document_id)
  where correction_of_document_id is not null;

create index if not exists marketplace_financial_documents_created_by_idx
  on public.marketplace_financial_documents(created_by);

create index if not exists marketplace_payment_methods_updated_by_idx
  on public.marketplace_payment_methods(updated_by)
  where updated_by is not null;

create index if not exists project_marketplace_billing_settings_updated_by_idx
  on public.project_marketplace_billing_settings(updated_by)
  where updated_by is not null;

create index if not exists marketplace_topup_reversals_ledger_idx
  on public.marketplace_topup_reversals(project_id,user_id,ledger_transaction_id);

create index if not exists marketplace_topup_reversals_document_idx
  on public.marketplace_topup_reversals(financial_document_id);

create index if not exists marketplace_topup_reversals_reversed_by_idx
  on public.marketplace_topup_reversals(reversed_by);

create index if not exists marketplace_driver_customer_ratings_driver_idx
  on public.marketplace_driver_customer_ratings(project_id,driver_user_id,created_at desc);

revoke all on function app_private.has_control_write_entitlement(uuid)
  from public,anon,authenticated;
revoke all on function app_private.has_active_marketplace_suite(uuid)
  from public,anon,authenticated;
