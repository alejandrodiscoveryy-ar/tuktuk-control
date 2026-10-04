-- TUKTUK 2.0
-- 004: topup compensating reversal + hardening/indexes

begin;

-- ---------------------------------------------------------------------------
-- 1. Reverso de recarga como asiento compensatorio, sin editar el original.
-- ---------------------------------------------------------------------------

alter table public.wallet_transactions
  drop constraint if exists wallet_transactions_transaction_type_check;

alter table public.wallet_transactions
  add constraint wallet_transactions_transaction_type_check
  check (
    transaction_type = any(
      array[
        'topup'::text,
        'commission'::text,
        'adjustment'::text,
        'reversal'::text,
        'referral_credit'::text,
        'topup_reversal'::text
      ]
    )
  );

alter table public.wallet_transactions
  drop constraint if exists wallet_transactions_source_sign_check;

alter table public.wallet_transactions
  add constraint wallet_transactions_source_sign_check
  check (
    (
      transaction_type='topup'
      and real_delta>0
      and promotional_delta=0
      and reversed_ledger_id is null
    )
    or
    (
      transaction_type='referral_credit'
      and real_delta=0
      and promotional_delta>0
      and reversed_ledger_id is null
    )
    or
    (
      transaction_type='commission'
      and real_delta<=0
      and promotional_delta<=0
      and reversed_ledger_id is null
    )
    or
    (
      transaction_type='reversal'
      and real_delta>=0
      and promotional_delta>=0
      and reversed_ledger_id is not null
    )
    or
    (
      transaction_type='topup_reversal'
      and real_delta<0
      and promotional_delta=0
      and reversed_ledger_id is not null
    )
  );

create table if not exists public.marketplace_topup_reversals(
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete restrict,
  topup_id uuid not null,
  user_id uuid not null references public.profiles(id) on delete restrict,
  amount numeric(14,2) not null check (amount>0),
  currency text not null check (currency='CUP'),
  ledger_transaction_id uuid not null,
  financial_document_id uuid not null
    references public.marketplace_financial_documents(id) on delete restrict,
  idempotency_key uuid not null,
  reason text not null,
  reversed_by uuid not null references auth.users(id) on delete restrict,
  reversed_at timestamptz not null default now(),
  unique(project_id,topup_id),
  unique(project_id,idempotency_key),
  foreign key(project_id,user_id,topup_id)
    references public.topups(project_id,user_id,id) on delete restrict,
  foreign key(project_id,user_id,ledger_transaction_id)
    references public.wallet_transactions(project_id,user_id,id)
    on delete restrict,
  check (nullif(btrim(reason),'') is not null)
);

alter table public.marketplace_topup_reversals enable row level security;
revoke all on table public.marketplace_topup_reversals
  from public,anon,authenticated;

create or replace function app_private.prevent_marketplace_topup_reversal_mutation()
returns trigger
language plpgsql
security definer
set search_path=''
as $function$
begin
  raise exception 'MARKETPLACE_TOPUP_REVERSAL_IMMUTABLE'
    using errcode='42501';
end;
$function$;

drop trigger if exists marketplace_topup_reversals_immutable
  on public.marketplace_topup_reversals;

create trigger marketplace_topup_reversals_immutable
before update or delete on public.marketplace_topup_reversals
for each row
execute function app_private.prevent_marketplace_topup_reversal_mutation();

-- Extiende el clasificador existente manteniendo la atribución promo/real actual.
create or replace function app_private.marketplace_classify_wallet_transaction()
returns trigger
language plpgsql
security definer
set search_path=''
as $function$
declare
  wallet_currency text;
  real_before numeric;
  promo_before numeric;
  total_before numeric;
  debit numeric;
  original_tx public.wallet_transactions%rowtype;
  active_reservation public.commission_reservations%rowtype;
  other_real_reserved numeric;
  other_promo_reserved numeric;
  topup_record public.topups%rowtype;
begin
  select w.currency into wallet_currency
  from public.wallets w
  where w.project_id=new.project_id
    and w.user_id=new.user_id
  for update;

  if not found then
    raise exception 'WALLET_SOURCE_WALLET_NOT_FOUND' using errcode='22023';
  end if;

  if new.currency<>wallet_currency or new.currency<>'CUP' then
    raise exception 'WALLET_SOURCE_CURRENCY_MISMATCH' using errcode='22023';
  end if;

  if new.real_delta<>0
     or new.promotional_delta<>0
     or new.reversed_ledger_id is not null then
    raise exception 'WALLET_SOURCE_FIELDS_SERVER_ONLY' using errcode='42501';
  end if;

  select
    coalesce(sum(t.real_delta),0),
    coalesce(sum(t.promotional_delta),0),
    coalesce(sum(t.amount_delta),0)
  into real_before,promo_before,total_before
  from public.wallet_transactions t
  where t.project_id=new.project_id
    and t.user_id=new.user_id;

  if real_before<0
     or promo_before<0
     or real_before+promo_before<>total_before then
    raise exception 'WALLET_SOURCE_PREVIOUS_BALANCE_CORRUPT'
      using errcode='22023';
  end if;

  if new.balance_after<>total_before+new.amount_delta then
    raise exception 'WALLET_SOURCE_LEDGER_BALANCE_MISMATCH'
      using errcode='22023';
  end if;

  if new.transaction_type='topup' then
    if new.amount_delta<=0 or new.source_type<>'topup' then
      raise exception 'WALLET_SOURCE_INVALID_TOPUP' using errcode='22023';
    end if;

    select * into topup_record
    from public.topups t
    where t.project_id=new.project_id
      and t.user_id=new.user_id
      and t.id::text=new.source_id
      and t.status='requested'
      and t.amount=new.amount_delta
      and t.currency=new.currency;

    if not found then
      raise exception 'WALLET_SOURCE_TOPUP_NOT_VERIFIED'
        using errcode='22023';
    end if;

    new.real_delta:=new.amount_delta;

  elsif new.transaction_type='referral_credit' then
    if new.amount_delta<=0
       or new.source_type not in ('referral_reward','legacy_referral_transition') then
      raise exception 'WALLET_SOURCE_INVALID_PROMOTIONAL_CREDIT'
        using errcode='22023';
    end if;

    new.promotional_delta:=new.amount_delta;

  elsif new.transaction_type='commission' then
    if new.amount_delta>=0 or new.source_type<>'job_commission' then
      raise exception 'WALLET_SOURCE_INVALID_COMMISSION'
        using errcode='22023';
    end if;

    debit:=-new.amount_delta;

    select * into active_reservation
    from public.commission_reservations r
    where r.project_id=new.project_id
      and r.user_id=new.user_id
      and r.job_id::text=new.source_id
      and r.status='open'
      and r.amount=debit;

    if not found then
      raise exception 'WALLET_SOURCE_RESERVATION_NOT_FOUND'
        using errcode='22023';
    end if;

    if active_reservation.real_reserved_amount<0
       or active_reservation.promotional_reserved_amount<0
       or active_reservation.real_reserved_amount
          +active_reservation.promotional_reserved_amount<>debit then
      raise exception 'WALLET_SOURCE_RESERVATION_SPLIT_INVALID'
        using errcode='22023';
    end if;

    select
      coalesce(sum(r.real_reserved_amount),0),
      coalesce(sum(r.promotional_reserved_amount),0)
    into other_real_reserved,other_promo_reserved
    from public.commission_reservations r
    where r.project_id=new.project_id
      and r.user_id=new.user_id
      and r.status='open'
      and r.id<>active_reservation.id;

    if real_before-active_reservation.real_reserved_amount<other_real_reserved
       or promo_before-active_reservation.promotional_reserved_amount<other_promo_reserved then
      raise exception 'WALLET_SOURCE_OTHER_RESERVATIONS_UNFUNDED'
        using errcode='22023';
    end if;

    new.real_delta:=-active_reservation.real_reserved_amount;
    new.promotional_delta:=-active_reservation.promotional_reserved_amount;

  elsif new.transaction_type='reversal' then
    if new.amount_delta<=0
       or new.source_type<>'job_commission_reversal'
       or nullif(new.metadata->>'original_ledger_transaction_id','') is null then
      raise exception 'WALLET_SOURCE_REVERSAL_REFERENCE_REQUIRED'
        using errcode='22023';
    end if;

    select * into original_tx
    from public.wallet_transactions t
    where t.id=(new.metadata->>'original_ledger_transaction_id')::uuid
      and t.project_id=new.project_id
      and t.user_id=new.user_id
      and t.transaction_type='commission'
      and t.source_type='job_commission'
      and t.source_id=new.source_id;

    if not found or new.amount_delta<>-original_tx.amount_delta then
      raise exception 'WALLET_SOURCE_REVERSAL_MISMATCH'
        using errcode='22023';
    end if;

    new.reversed_ledger_id:=original_tx.id;
    new.real_delta:=-original_tx.real_delta;
    new.promotional_delta:=-original_tx.promotional_delta;

  elsif new.transaction_type='topup_reversal' then
    if new.amount_delta>=0
       or new.source_type<>'topup_reversal'
       or nullif(new.metadata->>'original_ledger_transaction_id','') is null then
      raise exception 'WALLET_SOURCE_TOPUP_REVERSAL_REFERENCE_REQUIRED'
        using errcode='22023';
    end if;

    select * into original_tx
    from public.wallet_transactions t
    where t.id=(new.metadata->>'original_ledger_transaction_id')::uuid
      and t.project_id=new.project_id
      and t.user_id=new.user_id
      and t.transaction_type='topup'
      and t.source_type='topup'
      and t.source_id=new.source_id;

    if not found or new.amount_delta<>-original_tx.amount_delta then
      raise exception 'WALLET_SOURCE_TOPUP_REVERSAL_MISMATCH'
        using errcode='22023';
    end if;

    if real_before + new.amount_delta < 0 then
      raise exception 'INSUFFICIENT_REAL_BALANCE_FOR_TOPUP_REVERSAL'
        using errcode='22023';
    end if;

    new.reversed_ledger_id:=original_tx.id;
    new.real_delta:=new.amount_delta;
    new.promotional_delta:=0;

  else
    raise exception 'WALLET_SOURCE_UNCLASSIFIED_TRANSACTION'
      using errcode='22023';
  end if;

  if new.real_delta+new.promotional_delta<>new.amount_delta
     or real_before+new.real_delta<0
     or promo_before+new.promotional_delta<0 then
    raise exception 'WALLET_SOURCE_NEGATIVE_OR_UNBALANCED'
      using errcode='22023';
  end if;

  return new;
end;
$function$;

create or replace function app_private.issue_marketplace_topup_credit_note(
  target_project_id uuid,
  target_topup_id uuid,
  target_actor uuid,
  target_idempotency_key uuid,
  target_reason text
)
returns public.marketplace_financial_documents
language plpgsql
security definer
set search_path=''
as $function$
declare
  t public.topups%rowtype;
  b public.project_marketplace_billing_settings%rowtype;
  original_doc public.marketplace_financial_documents%rowtype;
  existing public.marketplace_financial_documents%rowtype;
  result public.marketplace_financial_documents%rowtype;
  issued timestamptz:=now();
  number text;
begin
  if nullif(btrim(target_reason),'') is null then
    raise exception 'REVERSAL_REASON_REQUIRED' using errcode='22023';
  end if;

  select * into existing
  from public.marketplace_financial_documents d
  where d.project_id=target_project_id
    and d.topup_id=target_topup_id
    and d.document_type='credit_note';

  if found then
    return existing;
  end if;

  select * into t
  from public.topups
  where project_id=target_project_id and id=target_topup_id;

  if not found or t.status not in ('confirmed','reconciled') then
    raise exception 'TOPUP_NOT_CONFIRMED_FOR_CREDIT_NOTE'
      using errcode='22023';
  end if;

  select * into original_doc
  from public.marketplace_financial_documents d
  where d.project_id=target_project_id
    and d.topup_id=target_topup_id
    and d.document_type='topup_receipt';

  if not found then
    raise exception 'ORIGINAL_TOPUP_DOCUMENT_NOT_FOUND'
      using errcode='P0002';
  end if;

  select * into b
  from public.project_marketplace_billing_settings
  where project_id=target_project_id;

  number:=app_private.next_marketplace_financial_document_number(
    target_project_id,
    issued
  );

  insert into public.marketplace_financial_documents(
    project_id,user_id,topup_id,document_type,document_number,
    amount,currency,concept,payment_method,payment_reference,
    issuer_snapshot,correction_of_document_id,
    idempotency_key,issued_at,created_by
  )
  values(
    target_project_id,
    t.user_id,
    t.id,
    'credit_note',
    number,
    t.amount,
    t.currency,
    'Corrección de recarga TUKTUK: '||btrim(target_reason),
    t.method,
    t.reference,
    jsonb_build_object(
      'issuer_display_name',b.issuer_display_name,
      'issuer_tax_id',b.issuer_tax_id,
      'issuer_address',b.issuer_address,
      'project_id',b.project_id,
      'technical_financial_document',true
    ),
    original_doc.id,
    target_idempotency_key,
    issued,
    target_actor
  )
  returning * into result;

  return result;
end;
$function$;

revoke all on function app_private.issue_marketplace_topup_credit_note(uuid,uuid,uuid,uuid,text)
  from public,anon,authenticated;

create or replace function public.admin_reverse_marketplace_topup(
  target_project_id uuid,
  target_topup_id uuid,
  target_reason text,
  target_idempotency_key uuid
)
returns public.marketplace_topup_reversals
language plpgsql
security definer
set search_path=''
as $function$
declare
  actor uuid;
  t public.topups%rowtype;
  existing public.marketplace_topup_reversals%rowtype;
  original_tx public.wallet_transactions%rowtype;
  reversal_tx uuid;
  prior_balance numeric;
  credit_note public.marketplace_financial_documents%rowtype;
  result public.marketplace_topup_reversals%rowtype;
begin
  actor:=app_private.require_project_permission(
    target_project_id,
    'payments.manage'
  );

  if target_idempotency_key is null then
    raise exception 'IDEMPOTENCY_KEY_REQUIRED' using errcode='22023';
  end if;

  if nullif(btrim(target_reason),'') is null then
    raise exception 'REVERSAL_REASON_REQUIRED' using errcode='22023';
  end if;

  select * into existing
  from public.marketplace_topup_reversals
  where project_id=target_project_id and topup_id=target_topup_id;

  if found then
    if existing.idempotency_key<>target_idempotency_key then
      raise exception 'TOPUP_ALREADY_REVERSED' using errcode='22023';
    end if;
    return existing;
  end if;

  select * into t
  from public.topups
  where project_id=target_project_id and id=target_topup_id
  for update;

  if not found then
    raise exception 'TOPUP_NOT_FOUND' using errcode='P0002';
  end if;

  if t.status not in ('confirmed','reconciled')
     or t.ledger_transaction_id is null then
    raise exception 'TOPUP_NOT_REVERSIBLE' using errcode='22023';
  end if;

  perform 1
  from public.wallets
  where project_id=target_project_id and user_id=t.user_id
  for update;

  select * into original_tx
  from public.wallet_transactions
  where project_id=target_project_id
    and user_id=t.user_id
    and id=t.ledger_transaction_id
    and transaction_type='topup'
    and source_type='topup'
    and source_id=t.id::text;

  if not found then
    raise exception 'TOPUP_LEDGER_NOT_FOUND' using errcode='P0002';
  end if;

  prior_balance:=app_private.marketplace_wallet_total_balance(
    target_project_id,
    t.user_id
  );

  insert into public.wallet_transactions(
    project_id,user_id,currency,transaction_type,amount_delta,balance_after,
    source_type,source_id,idempotency_key,actor_id,metadata
  )
  values(
    target_project_id,
    t.user_id,
    t.currency,
    'topup_reversal',
    -t.amount,
    prior_balance-t.amount,
    'topup_reversal',
    t.id::text,
    target_idempotency_key,
    actor,
    jsonb_build_object(
      'topup_id',t.id,
      'original_ledger_transaction_id',original_tx.id,
      'reason',btrim(target_reason)
    )
  )
  returning id into reversal_tx;

  credit_note:=app_private.issue_marketplace_topup_credit_note(
    target_project_id,
    t.id,
    actor,
    target_idempotency_key,
    target_reason
  );

  insert into public.marketplace_topup_reversals(
    project_id,topup_id,user_id,amount,currency,
    ledger_transaction_id,financial_document_id,
    idempotency_key,reason,reversed_by
  )
  values(
    target_project_id,t.id,t.user_id,t.amount,t.currency,
    reversal_tx,credit_note.id,
    target_idempotency_key,btrim(target_reason),actor
  )
  returning * into result;

  return result;
end;
$function$;

revoke execute on function public.admin_reverse_marketplace_topup(uuid,uuid,text,uuid)
  from public,anon;
grant execute on function public.admin_reverse_marketplace_topup(uuid,uuid,text,uuid)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Índices de soporte para las rutas financieras/vehiculares modificadas.
-- ---------------------------------------------------------------------------

create index if not exists topups_user_id_idx
  on public.topups(user_id);

create index if not exists topups_requested_by_idx
  on public.topups(requested_by);

create index if not exists topups_confirmed_by_idx
  on public.topups(confirmed_by)
  where confirmed_by is not null;

create index if not exists topups_rejected_by_idx
  on public.topups(rejected_by)
  where rejected_by is not null;

create index if not exists topups_ledger_transaction_idx
  on public.topups(project_id,user_id,ledger_transaction_id)
  where ledger_transaction_id is not null;

create index if not exists wallets_user_id_idx
  on public.wallets(user_id);

create index if not exists vehicles_owner_user_id_idx
  on public.vehicles(owner_user_id);

create index if not exists vehicles_project_category_idx
  on public.vehicles(project_id,category_code)
  where deleted_at is null;

create index if not exists vehicles_project_propulsion_idx
  on public.vehicles(project_id,propulsion_code)
  where deleted_at is null;

create index if not exists wallet_transactions_actor_id_idx
  on public.wallet_transactions(actor_id)
  where actor_id is not null;

create index if not exists marketplace_topup_reversals_user_idx
  on public.marketplace_topup_reversals(project_id,user_id,reversed_at desc);
