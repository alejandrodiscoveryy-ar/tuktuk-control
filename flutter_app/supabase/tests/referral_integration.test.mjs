import {PGlite} from '@electric-sql/pglite';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import test from 'node:test';

// In-memory PostgreSQL only. No connection string and no production data.
// The schema/dependency helpers are minimal fixtures; the five business
// functions are an unchanged, read-only snapshot of the deployed definitions.
const P = '11111111-1111-1111-1111-111111111111';
const A = '22222222-2222-2222-2222-222222222222';
const B = '33333333-3333-3333-3333-333333333333';
const C = '44444444-4444-4444-4444-444444444444';
const schema = `
create schema auth; create schema app_private;
create function auth.uid() returns uuid language sql as $$
select nullif(current_setting('test.actor',true),'')::uuid $$;
create table public.profiles(id uuid primary key, display_name text);
create table public.projects(id uuid primary key,owner_id uuid);
create table public.referral_campaigns(id uuid primary key,name text,qualification_mode text,reward_days int);
create table public.project_referral_settings(project_id uuid,share_base_url text);
create table public.project_referral_codes(project_id uuid,user_id uuid,code text);
create table public.payments(id uuid primary key,project_id uuid,user_id uuid,status text,is_test boolean default false,recorded_by uuid);
create table public.licenses(id uuid primary key default gen_random_uuid(),project_id uuid,user_id uuid,license_type text,expires_at timestamptz,status text,updated_at timestamptz default now(),last_payment_id uuid);
create table public.referral_relationships(id uuid primary key default gen_random_uuid(),project_id uuid,referrer_user_id uuid,referred_user_id uuid,referral_code text,source text,is_test boolean default false,created_by uuid,updated_by uuid,campaign_id uuid,qualification_mode text,reward_days int,qualified_at timestamptz,created_at timestamptz default now(),check(referrer_user_id<>referred_user_id));
create unique index referral_relationships_real_referred_uidx on public.referral_relationships(project_id,referred_user_id) where not is_test;
create table public.referral_reward_ledger(id uuid primary key default gen_random_uuid(),project_id uuid,relationship_id uuid,referrer_user_id uuid,referred_user_id uuid,qualifying_payment_id uuid,reward_days int,status text,is_test boolean default false,created_by uuid,note text,applied_license_id uuid,previous_expires_at timestamptz,new_expires_at timestamptz,applied_at timestamptz,application_note text,updated_at timestamptz default now(),created_at timestamptz default now());
create unique index referral_reward_ledger_real_referred_uidx on public.referral_reward_ledger(project_id,referred_user_id) where not is_test;
create table public.license_audit_log(project_id uuid,license_id uuid,action text,detail text,actor_id uuid,metadata jsonb);
create function app_private.p1_current_referral_campaign(uuid) returns public.referral_campaigns language sql as $$ select * from public.referral_campaigns limit 1 $$;
create function app_private.p0d_resolve_referral_code(uuid,text) returns uuid language sql as $$ select user_id from public.project_referral_codes where project_id=$1 and code=upper(btrim($2)) $$;
create function app_private.p0d_ensure_referral_code(uuid,uuid) returns text language sql as $$ select code from public.project_referral_codes where project_id=$1 and user_id=$2 $$;
insert into public.profiles values('${A}','Referrer'),('${B}','Invitee'),('${C}','Other');
insert into public.projects values('${P}','${A}');
insert into public.referral_campaigns values('${P}','Test campaign','registration',15);
insert into public.project_referral_settings values('${P}','https://example.test/invite');
insert into public.project_referral_codes values('${P}','${A}','TUK-AA01'),('${P}','${B}','TUK-BB02'),('${P}','${C}','LEGACY-CODE');
`;
const snapshot = await readFile(new URL('./fixtures/referral_functions_snapshot.sql',import.meta.url),'utf8');

async function fixture(t, type='paid', status='active', expiry='2030-01-01') {
  const db = new PGlite();
  t.after(() => db.close());
  await db.exec(schema + snapshot);
  await db.query('insert into public.licenses(project_id,user_id,license_type,status,expires_at) values($1,$2,$3,$4,$5)',[P,A,type,status,expiry]);
  return db;
}
async function actor(db,id) { await db.query("select set_config('test.actor',$1,false)",[id]); }
async function claim(db,code='TUK-AA01') { return (await db.query('select public.claim_referral_code($1,$2) id',[P,code])).rows[0].id; }
async function scalar(db,sql) { return Object.values((await db.query(sql)).rows[0])[0]; }

test('registro → relación → recompensa → 15 días; reintento idempotente y Mis referidos',async t => {
  const db=await fixture(t); await actor(db,B);
  const id=await claim(db,'tuk-aa01');
  assert.equal(await claim(db),id);
  assert.equal(await scalar(db,'select count(*)::int from public.referral_relationships'),1);
  assert.equal(await scalar(db,'select count(*)::int from public.referral_reward_ledger'),1);
  assert.equal(await scalar(db,"select to_char(expires_at,'YYYY-MM-DD') from public.licenses"),'2030-01-16');
  await actor(db,A);
  const list=await scalar(db,`select public.get_my_referrals('${P}')`);
  assert.equal(list[0].relationship_id,id); assert.equal(list[0].status,'rewarded');
  const metrics=await scalar(db,`select public.get_my_referral_program('${P}')`);
  assert.equal(metrics.referred_count,1); assert.equal(metrics.applied_days,15);
});

test('owner/admin conserva earned y aplica una sola vez al existir licencia cliente',async t => {
  const db=await fixture(t,'admin'); await actor(db,B); await claim(db);
  assert.equal(await scalar(db,'select status from public.referral_reward_ledger'),'earned');
  assert.equal(await scalar(db,"select to_char(expires_at,'YYYY-MM-DD') from public.licenses"),'2030-01-01');
  await db.exec("update public.licenses set license_type='paid'");
  assert.equal(await scalar(db,`select app_private.p0d_apply_earned_rewards('${P}','${A}')`),1);
  assert.equal(await scalar(db,`select app_private.p0d_apply_earned_rewards('${P}','${A}')`),0);
});

test('autorreferido, código inválido, cambio de referente y usuario ya pagado',async t => {
  const db=await fixture(t); await actor(db,A);
  await assert.rejects(claim(db),/SELF_REFERRAL_NOT_ALLOWED/);
  await actor(db,B); await assert.rejects(claim(db,'MISSING'),/REFERRAL_CODE_NOT_FOUND/);
  await claim(db); await assert.rejects(claim(db,'LEGACY-CODE'),/REFERRAL_RELATIONSHIP_LOCKED/);
  await actor(db,C);
  await db.exec(`insert into public.payments(id,project_id,user_id,status) values(gen_random_uuid(),'${P}','${C}','paid')`);
  await assert.rejects(claim(db),/REFERRAL_RELATIONSHIP_LOCKED/);
  assert.equal(await scalar(db,'select count(*)::int from public.referral_relationships'),1);
});

for (const type of ['trial','paid']) {
  test(`licencia cliente ${type} activa recibe días`,async t=>{
    const db=await fixture(t,type); await actor(db,B); await claim(db);
    assert.equal(await scalar(db,'select status from public.referral_reward_ledger'),'applied');
  });
}
test('licencia vencida comienza en la fecha actual',async t=>{
  const db=await fixture(t,'paid','expired','2020-01-01'); await actor(db,B); await claim(db);
  assert.equal(await scalar(db,"select abs(extract(epoch from (expires_at-now()-interval '15 days')))<10 from public.licenses"),true);
});
test('sin licencia elegible conserva earned y no inventa días aplicados',async t=>{
  const db=await fixture(t,'paid','suspended'); await actor(db,B); await claim(db);
  assert.equal(await scalar(db,'select status from public.referral_reward_ledger'),'earned');
  await actor(db,A);
  const metrics=await scalar(db,`select public.get_my_referral_program('${P}')`);
  assert.equal(metrics.earned_days,15); assert.equal(metrics.applied_days,0);
});
