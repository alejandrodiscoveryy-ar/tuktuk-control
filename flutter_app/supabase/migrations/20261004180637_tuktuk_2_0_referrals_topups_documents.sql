-- TUKTUK 2.0
-- 003: referrals, topups, payment methods and financial documents

begin;

-- ---------------------------------------------------------------------------
-- 1. Referidos: wallet promocional por primer trabajo válido.
-- ---------------------------------------------------------------------------

update public.project_referral_settings s
set reward_mode='marketplace_wallet_credit',
    reward_amount=coalesce(s.reward_amount,100.00),
    reward_currency=coalesce(s.reward_currency,'CUP'),
    reward_rule_version=s.reward_rule_version+1,
    reward_effective_at=coalesce(s.reward_effective_at,now()),
    updated_at=now()
where exists(
  select 1
  from public.projects p
  where p.id=s.project_id and p.slug='tuktuk-control'
)
and s.reward_mode is distinct from 'marketplace_wallet_credit';

create or replace function app_private.maybe_award_marketplace_referral_reward(
  target_project_id uuid,
  target_referred_user_id uuid,
  target_job_id uuid
)
returns uuid
language plpgsql
security definer
set search_path=''
as $function$
declare
  s public.project_referral_settings%rowtype;
  rel public.referral_relationships%rowtype;
  first_q record;
  w public.wallets%rowtype;
  prior numeric;
  tx uuid;
  reward uuid;
begin
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'marketplace-referral:'||
      target_project_id::text||':'||target_referred_user_id::text,
      0
    )
  );

  select * into s
  from public.project_referral_settings
  where project_id=target_project_id
  for update;

  if not found
     or s.reward_mode<>'marketplace_wallet_credit'
     or not s.reward_enabled then
    return null;
  end if;

  select * into first_q
  from app_private.marketplace_referral_first_qualification(
    target_project_id,
    target_referred_user_id
  );

  if not found
     or first_q.job_id<>target_job_id
     or first_q.qualified_at<s.reward_effective_at then
    return null;
  end if;

  select * into rel
  from public.referral_relationships
  where project_id=target_project_id
    and referred_user_id=target_referred_user_id
    and not is_test
  for update;

  if not found
     or rel.referrer_user_id=rel.referred_user_id
     or rel.created_at>first_q.qualified_at then
    return null;
  end if;

  -- El primer trabajo válido es la condición comercial.
  -- No se exige depósito y no se premia por instalación/onboarding.
  if exists(
       select 1
       from public.referral_reward_ledger l
       where l.project_id=target_project_id
         and l.referred_user_id=target_referred_user_id
         and not l.is_test
         and l.status in ('earned','applied')
     )
     or exists(
       select 1
       from public.marketplace_legacy_referral_reward_transitions t
       where t.project_id=target_project_id
         and t.referred_user_id=target_referred_user_id
     )
     or exists(
       select 1
       from public.marketplace_referral_rewards r
       where r.project_id=target_project_id
         and r.referred_user_id=target_referred_user_id
     ) then
    return null;
  end if;

  insert into public.wallets(project_id,user_id,currency)
  select target_project_id,rel.referrer_user_id,f.wallet_currency
  from public.project_marketplace_financial_settings f
  where f.project_id=target_project_id
  on conflict do nothing;

  select * into w
  from public.wallets
  where project_id=target_project_id
    and user_id=rel.referrer_user_id
  for update;

  if not found or w.currency<>s.reward_currency then
    raise exception 'REFERRAL_WALLET_CURRENCY_MISMATCH'
      using errcode='22023';
  end if;

  prior:=app_private.marketplace_wallet_total_balance(
    target_project_id,
    rel.referrer_user_id
  );

  insert into public.wallet_transactions(
    project_id,user_id,currency,transaction_type,amount_delta,balance_after,
    source_type,source_id,idempotency_key,metadata
  )
  values(
    target_project_id,
    rel.referrer_user_id,
    s.reward_currency,
    'referral_credit',
    s.reward_amount,
    prior+s.reward_amount,
    'referral_reward',
    target_job_id::text,
    gen_random_uuid(),
    jsonb_build_object(
      'relationship_id',rel.id,
      'referrer_user_id',rel.referrer_user_id,
      'referred_user_id',target_referred_user_id,
      'qualification_job_id',target_job_id,
      'qualification_kind','first_valid_job',
      'reward_amount',s.reward_amount,
      'reward_currency',s.reward_currency,
      'reward_rule_version',s.reward_rule_version
    )
  )
  returning id into tx;

  insert into public.marketplace_referral_rewards(
    project_id,relationship_id,referrer_user_id,referred_user_id,
    qualification_job_id,qualification_kind,reward_amount_snapshot,
    reward_currency_snapshot,reward_rule_version_snapshot,
    wallet_transaction_id,qualified_at,
    license_months_snapshot,license_application_status
  )
  values(
    target_project_id,
    rel.id,
    rel.referrer_user_id,
    target_referred_user_id,
    target_job_id,
    'first_valid_job',
    s.reward_amount,
    s.reward_currency,
    s.reward_rule_version,
    tx,
    first_q.qualified_at,
    0,
    'not_applicable'
  )
  returning id into reward;

  update public.referral_relationships
  set qualified_at=coalesce(qualified_at,first_q.qualified_at),
      updated_at=now()
  where id=rel.id;

  return reward;
end;
$function$;

create or replace function public.get_my_referral_program(
  target_project_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $function$
declare
  actor uuid:=auth.uid();
  result jsonb;
  current_mode text;
  rewarded_count_value bigint;
begin
  if actor is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501';
  end if;

  result:=public.get_my_referral_program_legacy(target_project_id);

  select reward_mode into current_mode
  from public.project_referral_settings
  where project_id=target_project_id;

  if current_mode='marketplace_wallet_credit'
     and exists(
       select 1 from public.projects
       where id=target_project_id and slug='tuktuk-control'
     ) then

    select count(*) into rewarded_count_value
    from public.marketplace_referral_rewards r
    where r.project_id=target_project_id
      and r.referrer_user_id=actor;

    result:=jsonb_set(
      result,
      '{qualification_mode}',
      '"first_valid_job"'::jsonb,
      true
    );

    result:=jsonb_set(result,'{license_months}','0'::jsonb,true);
    result:=jsonb_set(result,'{reward_months}','0'::jsonb,true);
    result:=jsonb_set(
      result,
      '{rewarded_count}',
      to_jsonb(rewarded_count_value),
      true
    );
  end if;

  return result;
end;
$function$;

revoke execute on function public.get_my_referral_program(uuid)
  from public,anon;
grant execute on function public.get_my_referral_program(uuid)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Catálogo configurable de métodos de recarga.
-- ---------------------------------------------------------------------------

create table if not exists public.marketplace_payment_methods(
  project_id uuid not null references public.projects(id) on delete restrict,
  code text not null,
  name text not null,
  active boolean not null default true,
  confirmation_mode text not null default 'manual'
    check (confirmation_mode in ('manual','automatic')),
  requires_reference boolean not null default false,
  sort_order integer not null default 100,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null,
  primary key(project_id,code),
  check (code ~ '^[a-z][a-z0-9_]{1,31}$'),
  check (nullif(btrim(name),'') is not null)
);

alter table public.marketplace_payment_methods enable row level security;
revoke all on table public.marketplace_payment_methods
  from public,anon,authenticated;

insert into public.marketplace_payment_methods(
  project_id,code,name,active,confirmation_mode,requires_reference,sort_order
)
select p.id,x.code,x.name,x.active,'manual',x.requires_reference,x.sort_order
from public.projects p
cross join (
  values
    ('cash','Efectivo',true,false,10),
    ('transfer','Transferencia',true,true,20),
    ('other','Otro',true,true,90),
    ('card','Tarjeta',false,true,100),
    ('paypal','PayPal',false,true,110)
) as x(code,name,active,requires_reference,sort_order)
where p.slug='tuktuk-control'
on conflict (project_id,code) do nothing;

alter table public.topups
  drop constraint if exists topups_method_check;

do $$
begin
  if not exists(
    select 1
    from pg_constraint
    where conname='topups_project_id_method_fkey'
      and conrelid='public.topups'::regclass
  ) then
    alter table public.topups
      add constraint topups_project_id_method_fkey
      foreign key(project_id,method)
      references public.marketplace_payment_methods(project_id,code)
      on delete restrict;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 3. Configuración y documentos financieros técnicos de recarga.
-- ---------------------------------------------------------------------------

create table if not exists public.project_marketplace_billing_settings(
  project_id uuid primary key references public.projects(id) on delete restrict,
  issuer_display_name text not null,
  issuer_tax_id text,
  issuer_address text,
  document_prefix text not null default 'TTK',
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (nullif(btrim(issuer_display_name),'') is not null),
  check (document_prefix ~ '^[A-Z0-9]{2,10}$')
);

alter table public.project_marketplace_billing_settings enable row level security;
revoke all on table public.project_marketplace_billing_settings
  from public,anon,authenticated;

insert into public.project_marketplace_billing_settings(
  project_id,issuer_display_name,document_prefix
)
select p.id,p.name,'TTK'
from public.projects p
where p.slug='tuktuk-control'
on conflict (project_id) do nothing;

create table if not exists public.marketplace_financial_document_sequences(
  project_id uuid not null references public.projects(id) on delete restrict,
  calendar_year integer not null,
  last_number bigint not null default 0,
  primary key(project_id,calendar_year),
  check (calendar_year between 2020 and 9999),
  check (last_number>=0)
);

alter table public.marketplace_financial_document_sequences enable row level security;
revoke all on table public.marketplace_financial_document_sequences
  from public,anon,authenticated;

create table if not exists public.marketplace_financial_documents(
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete restrict,
  user_id uuid not null references public.profiles(id) on delete restrict,
  topup_id uuid not null,
  document_type text not null
    check (document_type in ('topup_receipt','credit_note')),
  document_number text not null,
  amount numeric(14,2) not null check (amount>0),
  currency text not null check (currency='CUP'),
  concept text not null,
  payment_method text not null,
  payment_reference text,
  issuer_snapshot jsonb not null,
  correction_of_document_id uuid,
  idempotency_key uuid not null,
  issued_at timestamptz not null default now(),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  unique(project_id,document_number),
  unique(project_id,idempotency_key),
  foreign key(project_id,user_id,topup_id)
    references public.topups(project_id,user_id,id)
    on delete restrict,
  foreign key(correction_of_document_id)
    references public.marketplace_financial_documents(id)
    on delete restrict,
  check (jsonb_typeof(issuer_snapshot)='object')
);

create unique index if not exists marketplace_financial_documents_topup_receipt_uq
  on public.marketplace_financial_documents(project_id,topup_id)
  where document_type='topup_receipt';

create unique index if not exists marketplace_financial_documents_topup_credit_note_uq
  on public.marketplace_financial_documents(project_id,topup_id)
  where document_type='credit_note';

create index if not exists marketplace_financial_documents_user_issued_idx
  on public.marketplace_financial_documents(project_id,user_id,issued_at desc,id desc);

alter table public.marketplace_financial_documents enable row level security;
revoke all on table public.marketplace_financial_documents
  from public,anon,authenticated;

create or replace function app_private.prevent_marketplace_financial_document_mutation()
returns trigger
language plpgsql
security definer
set search_path=''
as $function$
begin
  raise exception 'MARKETPLACE_FINANCIAL_DOCUMENT_IMMUTABLE'
    using errcode='42501';
end;
$function$;

drop trigger if exists marketplace_financial_documents_immutable
  on public.marketplace_financial_documents;

create trigger marketplace_financial_documents_immutable
before update or delete on public.marketplace_financial_documents
for each row
execute function app_private.prevent_marketplace_financial_document_mutation();

create or replace function app_private.next_marketplace_financial_document_number(
  target_project_id uuid,
  target_issued_at timestamptz
)
returns text
language plpgsql
security definer
set search_path=''
as $function$
declare
  yr integer;
  next_no bigint;
  prefix text;
begin
  yr:=extract(year from target_issued_at)::integer;

  select b.document_prefix into prefix
  from public.project_marketplace_billing_settings b
  where b.project_id=target_project_id;

  if prefix is null then
    raise exception 'MARKETPLACE_BILLING_SETTINGS_NOT_FOUND'
      using errcode='P0002';
  end if;

  insert into public.marketplace_financial_document_sequences(
    project_id,calendar_year,last_number
  )
  values(target_project_id,yr,0)
  on conflict do nothing;

  select s.last_number into next_no
  from public.marketplace_financial_document_sequences s
  where s.project_id=target_project_id
    and s.calendar_year=yr
  for update;

  next_no:=next_no+1;

  update public.marketplace_financial_document_sequences
  set last_number=next_no
  where project_id=target_project_id
    and calendar_year=yr;

  return prefix||'-'||yr::text||'-'||lpad(next_no::text,6,'0');
end;
$function$;

revoke all on function app_private.next_marketplace_financial_document_number(uuid,timestamptz)
  from public,anon,authenticated;

create or replace function app_private.issue_marketplace_topup_receipt(
  target_project_id uuid,
  target_topup_id uuid,
  target_actor uuid,
  target_idempotency_key uuid
)
returns public.marketplace_financial_documents
language plpgsql
security definer
set search_path=''
as $function$
declare
  t public.topups%rowtype;
  b public.project_marketplace_billing_settings%rowtype;
  existing public.marketplace_financial_documents%rowtype;
  result public.marketplace_financial_documents%rowtype;
  issued timestamptz:=now();
  number text;
begin
  select * into existing
  from public.marketplace_financial_documents d
  where d.project_id=target_project_id
    and d.topup_id=target_topup_id
    and d.document_type='topup_receipt';

  if found then
    return existing;
  end if;

  select * into t
  from public.topups
  where project_id=target_project_id
    and id=target_topup_id
  for share;

  if not found or t.status not in ('confirmed','reconciled') then
    raise exception 'TOPUP_NOT_CONFIRMED_FOR_DOCUMENT'
      using errcode='22023';
  end if;

  select * into b
  from public.project_marketplace_billing_settings
  where project_id=target_project_id;

  if not found then
    raise exception 'MARKETPLACE_BILLING_SETTINGS_NOT_FOUND'
      using errcode='P0002';
  end if;

  number:=app_private.next_marketplace_financial_document_number(
    target_project_id,
    issued
  );

  insert into public.marketplace_financial_documents(
    project_id,user_id,topup_id,document_type,document_number,
    amount,currency,concept,payment_method,payment_reference,
    issuer_snapshot,idempotency_key,issued_at,created_by
  )
  values(
    target_project_id,
    t.user_id,
    t.id,
    'topup_receipt',
    number,
    t.amount,
    t.currency,
    'Recarga de billetera TUKTUK',
    t.method,
    t.reference,
    jsonb_build_object(
      'issuer_display_name',b.issuer_display_name,
      'issuer_tax_id',b.issuer_tax_id,
      'issuer_address',b.issuer_address,
      'project_id',b.project_id,
      'technical_financial_document',true
    ),
    target_idempotency_key,
    issued,
    target_actor
  )
  returning * into result;

  return result;
end;
$function$;

revoke all on function app_private.issue_marketplace_topup_receipt(uuid,uuid,uuid,uuid)
  from public,anon,authenticated;

-- ---------------------------------------------------------------------------
-- 4. Solicitudes de recarga: cualquier importe positivo, sin depósito mínimo.
-- ---------------------------------------------------------------------------

create or replace function app_private.create_marketplace_topup_request(
  target_project_id uuid,
  target_user_id uuid,
  target_amount numeric,
  target_method text,
  target_reference text,
  target_notes text,
  target_request_idempotency_key uuid,
  target_actor uuid
)
returns public.topups
language plpgsql
security definer
set search_path=''
as $function$
declare
  wallet_record public.wallets%rowtype;
  setting_record public.project_marketplace_financial_settings%rowtype;
  method_record public.marketplace_payment_methods%rowtype;
  result public.topups%rowtype;
  normalized_reference text;
  normalized_notes text;
begin
  if target_amount is null or target_amount<=0 then
    raise exception 'TOPUP_AMOUNT_MUST_BE_POSITIVE'
      using errcode='22023';
  end if;

  if target_request_idempotency_key is null then
    raise exception 'IDEMPOTENCY_KEY_REQUIRED'
      using errcode='22023';
  end if;

  normalized_reference:=nullif(btrim(target_reference),'');
  normalized_notes:=nullif(btrim(target_notes),'');

  if not exists(select 1 from public.profiles where id=target_user_id) then
    raise exception 'PROFILE_NOT_FOUND' using errcode='P0002';
  end if;

  select * into setting_record
  from public.project_marketplace_financial_settings
  where project_id=target_project_id;

  if not found then
    raise exception 'MARKETPLACE_FINANCIAL_SETTINGS_NOT_FOUND'
      using errcode='P0002';
  end if;

  select * into method_record
  from public.marketplace_payment_methods
  where project_id=target_project_id
    and code=target_method
    and active;

  if not found then
    raise exception 'INVALID_TOPUP_METHOD' using errcode='22023';
  end if;

  if method_record.requires_reference and normalized_reference is null then
    raise exception 'TOPUP_REFERENCE_REQUIRED' using errcode='22023';
  end if;

  insert into public.wallets(project_id,user_id,currency)
  values(target_project_id,target_user_id,setting_record.wallet_currency)
  on conflict (project_id,user_id) do nothing;

  select * into wallet_record
  from public.wallets
  where project_id=target_project_id and user_id=target_user_id
  for update;

  select * into result
  from public.topups
  where project_id=target_project_id
    and user_id=target_user_id
    and request_idempotency_key=target_request_idempotency_key;

  if found then
    if result.amount<>target_amount
       or result.method<>target_method
       or result.reference is distinct from normalized_reference
       or result.notes is distinct from normalized_notes then
      raise exception 'IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_REQUEST'
        using errcode='22023';
    end if;
    return result;
  end if;

  insert into public.topups(
    project_id,user_id,amount,currency,method,reference,notes,
    request_idempotency_key,requested_by,
    initial_minimum_snapshot,was_initial_candidate
  )
  values(
    target_project_id,target_user_id,target_amount,
    setting_record.wallet_currency,target_method,
    normalized_reference,normalized_notes,
    target_request_idempotency_key,target_actor,
    null,false
  )
  returning * into result;

  return result;
end;
$function$;

-- ---------------------------------------------------------------------------
-- 5. Confirmación: crédito + ledger + documento en una sola transacción.
-- ---------------------------------------------------------------------------

create or replace function public.admin_confirm_marketplace_topup(
  target_project_id uuid,
  target_topup_id uuid,
  target_confirmation_idempotency_key uuid
)
returns public.topups
language plpgsql
security definer
set search_path=''
as $function$
declare
  actor uuid;
  topup_record public.topups%rowtype;
  wallet_record public.wallets%rowtype;
  transaction_id uuid;
  prior_balance numeric;
  receipt public.marketplace_financial_documents%rowtype;
begin
  actor:=app_private.require_project_permission(
    target_project_id,
    'payments.manage'
  );

  if target_confirmation_idempotency_key is null then
    raise exception 'IDEMPOTENCY_KEY_REQUIRED' using errcode='22023';
  end if;

  select * into topup_record
  from public.topups
  where id=target_topup_id and project_id=target_project_id
  for update;

  if not found then
    raise exception 'TOPUP_NOT_FOUND' using errcode='P0002';
  end if;

  select * into wallet_record
  from public.wallets
  where project_id=topup_record.project_id
    and user_id=topup_record.user_id
  for update;

  if not found then
    raise exception 'WALLET_NOT_FOUND' using errcode='P0002';
  end if;

  if topup_record.status in ('confirmed','reconciled') then
    if topup_record.confirmation_idempotency_key
       is distinct from target_confirmation_idempotency_key then
      raise exception 'IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_OPERATION'
        using errcode='22023';
    end if;

    perform app_private.issue_marketplace_topup_receipt(
      target_project_id,
      topup_record.id,
      coalesce(topup_record.confirmed_by,actor),
      target_confirmation_idempotency_key
    );

    return topup_record;
  end if;

  if topup_record.status='rejected' then
    raise exception 'REJECTED_TOPUP_CANNOT_BE_CONFIRMED'
      using errcode='22023';
  end if;

  prior_balance:=app_private.marketplace_wallet_total_balance(
    target_project_id,
    topup_record.user_id
  );

  insert into public.wallet_transactions(
    project_id,user_id,currency,transaction_type,amount_delta,balance_after,
    source_type,source_id,idempotency_key,actor_id,metadata
  )
  values(
    target_project_id,
    topup_record.user_id,
    topup_record.currency,
    'topup',
    topup_record.amount,
    prior_balance+topup_record.amount,
    'topup',
    topup_record.id::text,
    target_confirmation_idempotency_key,
    actor,
    jsonb_build_object('topup_id',topup_record.id)
  )
  returning id into transaction_id;

  update public.topups
  set status='confirmed',
      confirmation_idempotency_key=target_confirmation_idempotency_key,
      ledger_transaction_id=transaction_id,
      confirmed_by=actor,
      confirmed_at=now(),
      updated_at=now()
  where id=topup_record.id and project_id=target_project_id
  returning * into topup_record;

  receipt:=app_private.issue_marketplace_topup_receipt(
    target_project_id,
    topup_record.id,
    actor,
    target_confirmation_idempotency_key
  );

  return topup_record;
end;
$function$;

-- ---------------------------------------------------------------------------
-- 6. RPCs de documentos y métodos.
-- ---------------------------------------------------------------------------

create or replace function public.get_my_marketplace_financial_documents(
  target_limit integer default 50
)
returns setof public.marketplace_financial_documents
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
  select d.*
  from public.marketplace_financial_documents d
  join public.projects p
    on p.id=d.project_id and p.slug='tuktuk-control'
  where d.user_id=actor
  order by d.issued_at desc,d.id desc
  limit least(greatest(coalesce(target_limit,50),1),100);
end;
$function$;

create or replace function public.admin_list_marketplace_financial_documents(
  target_project_id uuid,
  target_user_id uuid default null,
  target_limit integer default 100
)
returns setof public.marketplace_financial_documents
language plpgsql
stable
security definer
set search_path=''
as $function$
begin
  perform app_private.require_project_permission(
    target_project_id,
    'payments.manage'
  );

  return query
  select d.*
  from public.marketplace_financial_documents d
  where d.project_id=target_project_id
    and (target_user_id is null or d.user_id=target_user_id)
  order by d.issued_at desc,d.id desc
  limit least(greatest(coalesce(target_limit,100),1),200);
end;
$function$;

create or replace function public.admin_list_marketplace_payment_methods(
  target_project_id uuid
)
returns setof public.marketplace_payment_methods
language plpgsql
stable
security definer
set search_path=''
as $function$
begin
  perform app_private.require_project_permission(
    target_project_id,
    'settings.view'
  );

  return query
  select m.*
  from public.marketplace_payment_methods m
  where m.project_id=target_project_id
  order by m.sort_order,m.code;
end;
$function$;

create or replace function public.admin_upsert_marketplace_payment_method(
  target_project_id uuid,
  target_code text,
  target_name text,
  target_active boolean,
  target_confirmation_mode text,
  target_requires_reference boolean,
  target_sort_order integer
)
returns public.marketplace_payment_methods
language plpgsql
security definer
set search_path=''
as $function$
declare
  actor uuid;
  result public.marketplace_payment_methods%rowtype;
begin
  actor:=app_private.require_project_permission(
    target_project_id,
    'settings.manage'
  );

  if target_code !~ '^[a-z][a-z0-9_]{1,31}$'
     or nullif(btrim(target_name),'') is null
     or target_confirmation_mode not in ('manual','automatic') then
    raise exception 'INVALID_MARKETPLACE_PAYMENT_METHOD'
      using errcode='22023';
  end if;

  insert into public.marketplace_payment_methods(
    project_id,code,name,active,confirmation_mode,
    requires_reference,sort_order,updated_by
  )
  values(
    target_project_id,target_code,btrim(target_name),
    coalesce(target_active,false),target_confirmation_mode,
    coalesce(target_requires_reference,false),
    coalesce(target_sort_order,100),
    actor
  )
  on conflict(project_id,code) do update
  set name=excluded.name,
      active=excluded.active,
      confirmation_mode=excluded.confirmation_mode,
      requires_reference=excluded.requires_reference,
      sort_order=excluded.sort_order,
      updated_by=actor,
      updated_at=now()
  returning * into result;

  return result;
end;
$function$;

create or replace function public.admin_get_marketplace_billing_settings(
  target_project_id uuid
)
returns public.project_marketplace_billing_settings
language plpgsql
stable
security definer
set search_path=''
as $function$
declare
  result public.project_marketplace_billing_settings%rowtype;
begin
  perform app_private.require_project_permission(
    target_project_id,
    'payments.manage'
  );

  select * into result
  from public.project_marketplace_billing_settings
  where project_id=target_project_id;

  return result;
end;
$function$;

create or replace function public.admin_set_marketplace_billing_settings(
  target_project_id uuid,
  target_issuer_display_name text,
  target_issuer_tax_id text,
  target_issuer_address text,
  target_document_prefix text
)
returns public.project_marketplace_billing_settings
language plpgsql
security definer
set search_path=''
as $function$
declare
  actor uuid;
  result public.project_marketplace_billing_settings%rowtype;
begin
  actor:=app_private.require_project_permission(
    target_project_id,
    'payments.manage'
  );

  if nullif(btrim(target_issuer_display_name),'') is null
     or upper(btrim(target_document_prefix)) !~ '^[A-Z0-9]{2,10}$' then
    raise exception 'INVALID_MARKETPLACE_BILLING_SETTINGS'
      using errcode='22023';
  end if;

  insert into public.project_marketplace_billing_settings(
    project_id,issuer_display_name,issuer_tax_id,issuer_address,
    document_prefix,updated_by
  )
  values(
    target_project_id,
    btrim(target_issuer_display_name),
    nullif(btrim(target_issuer_tax_id),''),
    nullif(btrim(target_issuer_address),''),
    upper(btrim(target_document_prefix)),
    actor
  )
  on conflict(project_id) do update
  set issuer_display_name=excluded.issuer_display_name,
      issuer_tax_id=excluded.issuer_tax_id,
      issuer_address=excluded.issuer_address,
      document_prefix=excluded.document_prefix,
      updated_by=actor,
      updated_at=now()
  returning * into result;

  return result;
end;
$function$;

-- Grants explícitos de la API nueva.
revoke execute on function public.get_my_marketplace_financial_documents(integer)
  from public,anon;
grant execute on function public.get_my_marketplace_financial_documents(integer)
  to authenticated;

revoke execute on function public.admin_list_marketplace_financial_documents(uuid,uuid,integer)
  from public,anon;
revoke execute on function public.admin_list_marketplace_payment_methods(uuid)
  from public,anon;
revoke execute on function public.admin_upsert_marketplace_payment_method(uuid,text,text,boolean,text,boolean,integer)
  from public,anon;
revoke execute on function public.admin_get_marketplace_billing_settings(uuid)
  from public,anon;
revoke execute on function public.admin_set_marketplace_billing_settings(uuid,text,text,text,text)
  from public,anon;

grant execute on function public.admin_list_marketplace_financial_documents(uuid,uuid,integer)
  to authenticated;
grant execute on function public.admin_list_marketplace_payment_methods(uuid)
  to authenticated;
grant execute on function public.admin_upsert_marketplace_payment_method(uuid,text,text,boolean,text,boolean,integer)
  to authenticated;
grant execute on function public.admin_get_marketplace_billing_settings(uuid)
  to authenticated;
grant execute on function public.admin_set_marketplace_billing_settings(uuid,text,text,text,text)
  to authenticated;
