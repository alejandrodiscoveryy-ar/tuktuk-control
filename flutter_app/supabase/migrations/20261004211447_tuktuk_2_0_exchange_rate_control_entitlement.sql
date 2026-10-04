create or replace function public.get_my_project_exchange_rate(target_project_id uuid)
returns table(
  base_currency text,
  charge_currency text,
  rate numeric,
  rate_source text,
  rate_updated_at timestamptz,
  is_referential boolean
)
language plpgsql
stable
security definer
set search_path to ''
as $function$
declare
  actor uuid := auth.uid();
  project_slug text;
begin
  if actor is null then
    raise exception 'AUTH_REQUIRED' using errcode='42501';
  end if;

  select p.slug
    into project_slug
  from public.projects p
  where p.id = target_project_id;

  if project_slug is distinct from 'tuktuk-control' then
    raise exception 'PROJECT_NOT_SUPPORTED' using errcode='42501';
  end if;

  if not app_private.has_control_write_entitlement(actor) then
    raise exception 'CONTROL_ACCESS_REQUIRED' using errcode='42501';
  end if;

  return query
  select
    s.base_currency,
    s.charge_currency,
    s.current_rate,
    s.rate_source,
    s.rate_updated_at,
    true
  from public.project_exchange_settings s
  where s.project_id = target_project_id;
end;
$function$;

revoke all on function public.get_my_project_exchange_rate(uuid) from public;
revoke all on function public.get_my_project_exchange_rate(uuid) from anon;
grant execute on function public.get_my_project_exchange_rate(uuid) to authenticated;
