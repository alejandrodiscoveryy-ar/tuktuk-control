-- TUKTUK 2.0
-- Step 2C-A: API autenticada de recargas para el conductor.
-- No cambia saldos, no confirma recargas y no modifica métodos existentes.

begin;

create or replace function public.list_my_marketplace_payment_methods()
returns table(
  code text,
  name text,
  confirmation_mode text,
  requires_reference boolean,
  sort_order integer
)
language plpgsql
stable
security definer
set search_path=''
as $function$
declare
  actor uuid:=auth.uid();
begin
  if actor is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501';
  end if;

  return query
  select
    m.code,
    m.name,
    m.confirmation_mode,
    m.requires_reference,
    m.sort_order
  from public.marketplace_payment_methods m
  join public.projects p
    on p.id=m.project_id
   and p.slug='tuktuk-control'
  where m.active
  order by m.sort_order,m.code;
end;
$function$;

create or replace function public.list_my_marketplace_topups(
  target_limit integer default 50,
  target_before_requested_at timestamptz default null,
  target_before_topup_id uuid default null
)
returns table(
  topup_id uuid,
  amount numeric,
  currency text,
  status text,
  method text,
  method_name text,
  reference text,
  requested_at timestamptz,
  confirmed_at timestamptz,
  rejected_at timestamptz,
  rejection_reason text
)
language plpgsql
stable
security definer
set search_path=''
as $function$
declare
  actor uuid:=auth.uid();
begin
  if actor is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501';
  end if;

  if (target_before_requested_at is null)<>(target_before_topup_id is null) then
    raise exception 'INVALID_PAGINATION_CURSOR' using errcode='22023';
  end if;

  return query
  select
    t.id,
    t.amount,
    t.currency,
    t.status,
    t.method,
    m.name,
    t.reference,
    t.requested_at,
    t.confirmed_at,
    t.rejected_at,
    t.rejection_reason
  from public.topups t
  join public.projects p
    on p.id=t.project_id
   and p.slug='tuktuk-control'
  join public.marketplace_payment_methods m
    on m.project_id=t.project_id
   and m.code=t.method
  where t.user_id=actor
    and (
      target_before_requested_at is null
      or (t.requested_at,t.id)<
         (target_before_requested_at,target_before_topup_id)
    )
  order by t.requested_at desc,t.id desc
  limit least(greatest(coalesce(target_limit,50),1),100);
end;
$function$;

revoke execute on function public.list_my_marketplace_payment_methods()
  from public,anon;
grant execute on function public.list_my_marketplace_payment_methods()
  to authenticated;

revoke execute on function public.list_my_marketplace_topups(integer,timestamptz,uuid)
  from public,anon;
grant execute on function public.list_my_marketplace_topups(integer,timestamptz,uuid)
  to authenticated;

commit;