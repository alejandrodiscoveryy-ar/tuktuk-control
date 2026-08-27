-- Run only in an isolated Supabase branch.
-- All test mutations performed by this file are rolled back.

create or replace function pg_temp.assert_true(condition boolean, message text)
returns void language plpgsql as $$
begin
  if not coalesce(condition, false) then
    raise exception 'TEST_FAILED: %', message;
  end if;
end;
$$;

-- Format, uniqueness, alias ownership and public RPC contracts.
select pg_temp.assert_true(
  'TUK-TV27' ~ '^TUK-[A-Z]{2}[0-9]{2}$',
  'TUK-TV27 must be accepted by the primary format'
);

select pg_temp.assert_true(
  not exists(
    select 1 from public.project_referral_codes code
    where code.code !~ '^TUK-[A-Z]{2,}[0-9]{2}$'
  ),
  'every primary code must use the branded format'
);

select pg_temp.assert_true(
  not exists(
    select 1
    from public.project_referral_codes code
    group by code.project_id, code.code
    having count(*) > 1
  ),
  'two users cannot own the same primary code'
);

select pg_temp.assert_true(
  not exists(
    select 1
    from public.project_referral_codes primary_code
    join public.project_referral_code_aliases alias
      on alias.project_id = primary_code.project_id
     and alias.code = primary_code.code
    where alias.user_id <> primary_code.user_id
  ),
  'primary and alias namespaces cannot disagree on ownership'
);

select pg_temp.assert_true(
  not exists(
    select 1
    from public.project_referral_code_aliases alias
    where app_private.p0d_resolve_referral_code(alias.project_id, alias.code)
          is distinct from alias.user_id
  ),
  'every historical alias must resolve to its original user'
);

select pg_temp.assert_true(
  not exists(
    select 1
    from public.referral_relationships relationship
    where not relationship.is_test
      and relationship.referral_code is not null
      and app_private.p0d_resolve_referral_code(
            relationship.project_id,
            relationship.referral_code
          ) is distinct from relationship.referrer_user_id
  ),
  'historical relationships must keep resolving to their original owner'
);

select pg_temp.assert_true(
  to_regprocedure('public.get_my_referral_program(uuid)') is not null
  and to_regprocedure('public.get_my_referrals(uuid)') is not null
  and to_regprocedure('public.claim_referral_code(uuid,text)') is not null,
  'public referral RPC signatures must remain unchanged'
);

select pg_temp.assert_true(
  pg_get_function_result('public.get_my_referral_program(uuid)'::regprocedure)
    = 'jsonb'
  and pg_get_function_result('public.get_my_referrals(uuid)'::regprocedure)
    = 'jsonb'
  and pg_get_function_result('public.claim_referral_code(uuid,text)'::regprocedure)
    = 'uuid',
  'public referral RPC return contracts must remain unchanged'
);

-- Collision retry and automatic growth use one existing subject, but rollback.
begin;
do $$
declare
  subject record;
  attempt integer;
  candidate text;
  next_code text;
begin
  select code.project_id, code.user_id into subject
  from public.project_referral_codes code
  where not exists (
    select 1
    from generate_series(0, 19) attempt
    where exists (
      select 1
      from public.project_referral_codes other_code
      where other_code.project_id = code.project_id
        and other_code.code = app_private.p2_referral_code_candidate(
          code.project_id,
          code.user_id,
          attempt
        )
        and other_code.user_id <> code.user_id
    ) or exists (
      select 1
      from public.project_referral_code_aliases other_alias
      where other_alias.project_id = code.project_id
        and other_alias.code = app_private.p2_referral_code_candidate(
          code.project_id,
          code.user_id,
          attempt
        )
        and other_alias.user_id <> code.user_id
    )
  )
  order by code.project_id, code.user_id
  limit 1;
  if subject.user_id is null then
    raise exception 'TEST_SETUP_FAILED: referral subject required';
  end if;

  candidate := app_private.p2_referral_code_candidate(
    subject.project_id,
    subject.user_id,
    0
  );
  insert into public.project_referral_code_aliases(project_id, user_id, code)
  values(subject.project_id, subject.user_id, candidate)
  on conflict(project_id, code) do nothing;
  next_code := app_private.p2_next_referral_code(
    subject.project_id,
    subject.user_id
  );
  if next_code = candidate then
    raise exception 'TEST_FAILED: collision did not cause retry';
  end if;

  for attempt in 0..19 loop
    candidate := app_private.p2_referral_code_candidate(
      subject.project_id,
      subject.user_id,
      attempt
    );
    insert into public.project_referral_code_aliases(project_id, user_id, code)
    values(subject.project_id, subject.user_id, candidate)
    on conflict(project_id, code) do nothing;
  end loop;

  next_code := app_private.p2_next_referral_code(
    subject.project_id,
    subject.user_id
  );
  if next_code !~ '^TUK-[A-Z]{3}[0-9]{2}$' then
    raise exception 'TEST_FAILED: generator did not grow after collisions: %',
      next_code;
  end if;
end;
$$;
rollback;

-- Self-contained legacy preservation and idempotency fixture. Reuse three
-- staging subjects to avoid manufacturing auth/profile/project dependency
-- graphs. Every mutation, including temporary DDL, is reverted by ROLLBACK.
begin;
create temp table legacy_code_fixtures on commit drop as
select
  selected.project_id,
  selected.user_id,
  selected.code as original_primary_code,
  'LEGACY-Q' || selected.fixture_number::text || '-' ||
    left(replace(selected.user_id::text, '-', ''), 8) as legacy_code
from (
  select
    code.project_id,
    code.user_id,
    code.code,
    row_number() over(order by code.project_id, code.user_id) as fixture_number
  from public.project_referral_codes code
  order by code.project_id, code.user_id
  limit 3
) selected;

select pg_temp.assert_true(
  (select count(*) from legacy_code_fixtures) = 3,
  'isolated staging verification requires three referral-code subjects'
);

select pg_temp.assert_true(
  not exists(
    select 1
    from legacy_code_fixtures fixture
    join public.project_referral_code_aliases alias
      on alias.project_id = fixture.project_id
     and alias.code = fixture.legacy_code
  ),
  'controlled legacy fixture codes must not already exist as aliases'
);

-- Permit only this rolled-back fixture setup to emulate pre-migration rows.
drop trigger if exists p0d_referral_code_immutable
  on public.project_referral_codes;
alter table public.project_referral_codes
  drop constraint if exists project_referral_codes_code_check;

update public.project_referral_codes code
set code = fixture.legacy_code
from legacy_code_fixtures fixture
where code.project_id = fixture.project_id
  and code.user_id = fixture.user_id;

select pg_temp.assert_true(
  not exists(
    select 1
    from legacy_code_fixtures fixture
    join public.project_referral_codes code
      on code.project_id = fixture.project_id
     and code.user_id = fixture.user_id
    where code.code is distinct from fixture.legacy_code
  ),
  'controlled primary codes must be in legacy format before the first pass'
);

create temp table relationships_before_fixture_migration on commit drop as
select to_jsonb(relationship) as row_data
from public.referral_relationships relationship;

create temp table rewards_before_fixture_migration on commit drop as
select to_jsonb(reward) as row_data
from public.referral_rewards reward;

-- Encapsulate the migration's relevant data loop so the same implementation is
-- exercised twice in this session without relying on an earlier connection.
create or replace function pg_temp.run_short_referral_migration_pass()
returns integer
language plpgsql
as $$
declare
  subject record;
  candidate text;
  alias_owner uuid;
  processed_count integer := 0;
begin
  for subject in
    select code.project_id, code.user_id, code.code
    from public.project_referral_codes code
    where code.code !~ '^TUK-[A-Z]{2,}[0-9]{2}$'
    order by code.project_id, code.user_id
    for update
  loop
    processed_count := processed_count + 1;
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
      raise exception 'TEST_FAILED: migration pass changed alias ownership';
    end if;

    candidate := app_private.p2_next_referral_code(
      subject.project_id,
      subject.user_id
    );
    update public.project_referral_codes
    set code = candidate
    where project_id = subject.project_id and user_id = subject.user_id;
  end loop;
  return processed_count;
end;
$$;

select pg_temp.assert_true(
  pg_temp.run_short_referral_migration_pass() = 3,
  'first fixture migration pass must process every controlled legacy code'
);

select pg_temp.assert_true(
  not exists(
    select 1
    from legacy_code_fixtures fixture
    left join public.project_referral_code_aliases alias
      on alias.project_id = fixture.project_id
     and alias.user_id = fixture.user_id
     and alias.code = fixture.legacy_code
    where alias.code is null
  ),
  'every controlled legacy code must become an alias of the same project and user'
);

select pg_temp.assert_true(
  not exists(
    select 1
    from legacy_code_fixtures fixture
    where app_private.p0d_resolve_referral_code(
            fixture.project_id,
            fixture.legacy_code
          ) is distinct from fixture.user_id
  ),
  'every controlled legacy alias must resolve to its original user'
);

select pg_temp.assert_true(
  not exists(
    select 1
    from legacy_code_fixtures fixture
    join public.project_referral_codes code
      on code.project_id = fixture.project_id
     and code.user_id = fixture.user_id
    where code.code !~ '^TUK-[A-Z]{2,}[0-9]{2}$'
  ),
  'every controlled primary code must migrate to the branded format'
);

create temp table second_pass_codes_before on commit drop as
select to_jsonb(code) as row_data
from public.project_referral_codes code;

create temp table second_pass_aliases_before on commit drop as
select to_jsonb(alias) as row_data
from public.project_referral_code_aliases alias;

select pg_temp.assert_true(
  pg_temp.run_short_referral_migration_pass() = 0,
  'second fixture migration pass must process zero rows'
);

select pg_temp.assert_true(
  (select count(*) from second_pass_codes_before)
    = (select count(*) from public.project_referral_codes)
  and not exists(
    (select row_data from second_pass_codes_before)
    except all
    (select to_jsonb(code) from public.project_referral_codes code)
  )
  and not exists(
    (select to_jsonb(code) from public.project_referral_codes code)
    except all
    (select row_data from second_pass_codes_before)
  ),
  'second pass must not change branded primary codes or their owners'
);

select pg_temp.assert_true(
  (select count(*) from second_pass_aliases_before)
    = (select count(*) from public.project_referral_code_aliases)
  and not exists(
    (select row_data from second_pass_aliases_before)
    except all
    (select to_jsonb(alias) from public.project_referral_code_aliases alias)
  )
  and not exists(
    (select to_jsonb(alias) from public.project_referral_code_aliases alias)
    except all
    (select row_data from second_pass_aliases_before)
  ),
  'second pass must not create duplicate aliases or change alias ownership'
);

select pg_temp.assert_true(
  (select count(*) from relationships_before_fixture_migration)
    = (select count(*) from public.referral_relationships)
  and not exists(
    (select row_data from relationships_before_fixture_migration)
    except all
    (select to_jsonb(relationship) from public.referral_relationships relationship)
  )
  and not exists(
    (select to_jsonb(relationship) from public.referral_relationships relationship)
    except all
    (select row_data from relationships_before_fixture_migration)
  ),
  'fixture migration passes must not alter referral relationships'
);

select pg_temp.assert_true(
  (select count(*) from rewards_before_fixture_migration)
    = (select count(*) from public.referral_rewards)
  and not exists(
    (select row_data from rewards_before_fixture_migration)
    except all
    (select to_jsonb(reward) from public.referral_rewards reward)
  )
  and not exists(
    (select to_jsonb(reward) from public.referral_rewards reward)
    except all
    (select row_data from rewards_before_fixture_migration)
  ),
  'fixture migration passes must not alter referral rewards'
);
rollback;

-- The existing backend remains authoritative for self-referral and historical
-- idempotency. Verify those guards were not removed or replaced.
select pg_temp.assert_true(
  position(
    'SELF_REFERRAL_NOT_ALLOWED' in
    pg_get_functiondef('app_private.p1_register_referral(uuid,uuid,text,text,uuid)'::regprocedure)
  ) > 0,
  'self-referral guard must remain in the shared registration path'
);

select pg_temp.assert_true(
  position(
    'return existing.id' in lower(
      pg_get_functiondef('app_private.p1_register_referral(uuid,uuid,text,text,uuid)'::regprocedure)
    )
  ) > 0,
  'existing referral relationships must remain idempotent'
);
