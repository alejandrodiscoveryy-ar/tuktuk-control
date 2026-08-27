-- Replace legacy friendly referral codes with compact, project-scoped codes.
-- Existing codes remain valid through project_referral_code_aliases.

do $$
begin
  if to_regclass('public.project_referral_codes') is null
     or to_regclass('public.project_referral_code_aliases') is null then
    raise exception 'REFERRAL_CODE_TABLES_REQUIRED' using errcode = '42P01';
  end if;

  if exists (
    select 1
    from public.project_referral_codes primary_code
    join public.project_referral_code_aliases alias
      on alias.project_id = primary_code.project_id
     and alias.code = primary_code.code
    where alias.user_id <> primary_code.user_id
  ) then
    raise exception 'REFERRAL_CODE_NAMESPACE_CONFLICT' using errcode = '23505';
  end if;
end;
$$;

create or replace function app_private.p2_referral_code_candidate(
  target_project_id uuid,
  target_user_id uuid,
  target_attempt integer
) returns text
language plpgsql
immutable
strict
security invoker
set search_path = ''
as $$
declare
  letter_count integer;
  position integer;
  digest bytea;
  candidate text := 'TUK-';
begin
  if target_attempt < 0 then
    raise exception 'INVALID_REFERRAL_CODE_ATTEMPT' using errcode = '22023';
  end if;

  -- Twenty collisions exhaust one level before new codes grow by one letter.
  letter_count := 2 + (target_attempt / 20);
  for position in 1..letter_count loop
    digest := decode(md5(
      target_project_id::text || ':' || target_user_id::text || ':' ||
      target_attempt::text || ':letter:' || position::text
    ), 'hex');
    candidate := candidate || chr(65 + (get_byte(digest, 0) % 26));
  end loop;

  for position in 1..2 loop
    digest := decode(md5(
      target_project_id::text || ':' || target_user_id::text || ':' ||
      target_attempt::text || ':digit:' || position::text
    ), 'hex');
    candidate := candidate || (get_byte(digest, 0) % 10)::text;
  end loop;

  return candidate;
end;
$$;

create or replace function app_private.p2_next_referral_code(
  target_project_id uuid,
  target_user_id uuid
) returns text
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  candidate text;
  attempt integer := 0;
begin
  -- One allocator per project prevents races across the primary and alias tables.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('referral-code:' || target_project_id::text, 0)
  );

  loop
    candidate := app_private.p2_referral_code_candidate(
      target_project_id,
      target_user_id,
      attempt
    );

    if not exists (
         select 1
         from public.project_referral_codes code
         where code.project_id = target_project_id
           and code.code = candidate
       )
       and not exists (
         select 1
         from public.project_referral_code_aliases alias
         where alias.project_id = target_project_id
           and alias.code = candidate
       ) then
      return candidate;
    end if;

    attempt := attempt + 1;
    if attempt >= 1000 then
      raise exception 'REFERRAL_CODE_GENERATION_FAILED' using errcode = '54000';
    end if;
  end loop;
end;
$$;

create or replace function app_private.p2_guard_referral_code_namespace()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('referral-code:' || new.project_id::text, 0)
  );

  new.code := upper(btrim(new.code));
  if tg_table_name = 'project_referral_codes' then
    if exists (
      select 1
      from public.project_referral_code_aliases alias
      where alias.project_id = new.project_id
        and alias.code = new.code
        and alias.user_id <> new.user_id
    ) then
      raise exception 'REFERRAL_CODE_NAMESPACE_CONFLICT' using errcode = '23505';
    end if;
  elsif exists (
    select 1
    from public.project_referral_codes primary_code
    where primary_code.project_id = new.project_id
      and primary_code.code = new.code
      and primary_code.user_id <> new.user_id
  ) then
    raise exception 'REFERRAL_CODE_NAMESPACE_CONFLICT' using errcode = '23505';
  end if;

  return new;
end;
$$;

drop trigger if exists p2_referral_code_namespace
  on public.project_referral_codes;
create trigger p2_referral_code_namespace
before insert or update of project_id, user_id, code
on public.project_referral_codes
for each row execute function app_private.p2_guard_referral_code_namespace();

drop trigger if exists p2_referral_alias_namespace
  on public.project_referral_code_aliases;
create trigger p2_referral_alias_namespace
before insert or update of project_id, user_id, code
on public.project_referral_code_aliases
for each row execute function app_private.p2_guard_referral_code_namespace();

create or replace function app_private.p0d_ensure_referral_code(
  target_project_id uuid,
  target_user_id uuid
) returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  existing_code text;
  candidate text;
  insertion_round integer := 0;
begin
  select code into existing_code
  from public.project_referral_codes
  where project_id = target_project_id and user_id = target_user_id;
  if found then return existing_code; end if;

  if not exists (
       select 1 from public.projects project where project.id = target_project_id
     ) or not exists (
       select 1 from public.profiles profile where profile.id = target_user_id
     ) then
    raise exception 'REFERRAL_CODE_SUBJECT_NOT_FOUND' using errcode = 'P0002';
  end if;

  loop
    candidate := app_private.p2_next_referral_code(
      target_project_id,
      target_user_id
    );
    begin
      insert into public.project_referral_codes(project_id, user_id, code)
      values(target_project_id, target_user_id, candidate)
      on conflict(project_id, user_id) do nothing;
    exception when unique_violation then
      -- A database constraint remains authoritative if another writer wins.
      null;
    end;

    select code into existing_code
    from public.project_referral_codes
    where project_id = target_project_id and user_id = target_user_id;
    if found then return existing_code; end if;

    insertion_round := insertion_round + 1;
    if insertion_round >= 5 then
      raise exception 'REFERRAL_CODE_GENERATION_FAILED' using errcode = '54000';
    end if;
  end loop;
end;
$$;

-- The existing immutability trigger must be suspended only while legacy primary
-- codes are moved to aliases. ALTER/DROP locks the table for this transaction.
drop trigger if exists p0d_referral_code_immutable
  on public.project_referral_codes;

-- Remove the legacy format constraint before assigning the new A-Z/00-99
-- alphabet. The replacement constraint is validated after every row migrates.
alter table public.project_referral_codes
  drop constraint if exists project_referral_codes_code_check;

do $$
declare
  subject record;
  candidate text;
  alias_owner uuid;
begin
  for subject in
    select code.project_id, code.user_id, code.code
    from public.project_referral_codes code
    where code.code !~ '^TUK-[A-Z]{2,}[0-9]{2}$'
    order by code.project_id, code.user_id
    for update
  loop
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(
        'referral-code:' || subject.project_id::text,
        0
      )
    );

    insert into public.project_referral_code_aliases(project_id, user_id, code)
    values(subject.project_id, subject.user_id, upper(btrim(subject.code)))
    on conflict(project_id, code) do nothing;

    select alias.user_id into alias_owner
    from public.project_referral_code_aliases alias
    where alias.project_id = subject.project_id
      and alias.code = upper(btrim(subject.code));
    if alias_owner is distinct from subject.user_id then
      raise exception 'REFERRAL_ALIAS_OWNER_CONFLICT' using errcode = '23505';
    end if;

    candidate := app_private.p2_next_referral_code(
      subject.project_id,
      subject.user_id
    );
    update public.project_referral_codes
    set code = candidate
    where project_id = subject.project_id and user_id = subject.user_id;
  end loop;
end;
$$;

alter table public.project_referral_codes
  add constraint project_referral_codes_code_check
  check (code ~ '^TUK-[A-Z]{2,}[0-9]{2}$') not valid;
alter table public.project_referral_codes
  validate constraint project_referral_codes_code_check;

create trigger p0d_referral_code_immutable
before update or delete on public.project_referral_codes
for each row execute function app_private.p0d_guard_referral_code_immutable();

revoke all on function
  app_private.p2_referral_code_candidate(uuid, uuid, integer),
  app_private.p2_next_referral_code(uuid, uuid),
  app_private.p2_guard_referral_code_namespace()
from public, anon, authenticated;

revoke all on function app_private.p0d_ensure_referral_code(uuid, uuid)
from public, anon, authenticated;
