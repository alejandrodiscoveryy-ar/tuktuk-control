"""Prueba real del PR106 en PostgreSQL DESCARTABLE de GitHub Actions.
Nunca admite servidores remotos, ni un database que no sea el previsto.
"""
import os
import re
from pathlib import Path
from urllib.parse import urlsplit, urlunsplit
import psycopg

root = Path(__file__).resolve().parents[2]
old_file = root / 'supabase/migrations/20261017180000_driver_identity_documents_private.sql'
new_file = root / 'supabase/migrations/20261027020000_marketplace_identity_document_type.sql'
url = os.environ['TEST_DATABASE_URL']
parsed = urlsplit(url)
assert parsed.hostname in ('localhost', '127.0.0.1'), 'SQL_TEST_REQUIRES_LOCALHOST'
assert parsed.path == '/referral_validation_disposable', 'SQL_TEST_REQUIRES_DISPOSABLE_DATABASE'
assert parsed.username == 'postgres', 'SQL_TEST_REQUIRES_DISPOSABLE_SUPERUSER'

# Se usa una BD aislada distinta de la usada por otras pruebas del mismo job.
with psycopg.connect(url, autocommit=True) as setup:
    setup.execute('CREATE DATABASE tuktuk_identity_pr106_disposable')
target_url = urlunsplit(parsed._replace(path='/tuktuk_identity_pr106_disposable'))
old = old_file.read_text(encoding='utf-8')
new = new_file.read_text(encoding='utf-8')
assert "d.identity_document_type in ('national_id', 'driver_license')" in new, 'GATE_MISSING'
get_and_save = re.search(
    r'(?s)-- Consulta exclusiva del propietario\.\s*(.*?)-- El acceso al trabajo usa esta misma funcion\.', old
)
gate = re.search(
    r'(?s)(create or replace function app_private\.marketplace_onboarding_requirements_complete\(.*?\$\$;)', old
)
assert get_and_save and gate, 'LEGACY_SQL_CONTRACT_CHANGED'

PROJECT = '33333333-3333-4333-8333-333333333333'
FIRST = '11111111-1111-4111-8111-111111111111'
OLD = '22222222-2222-4222-8222-222222222222'
STRANGER = '99999999-9999-4999-8999-999999999999'
A_DRIVER = '44444444-4444-4444-8444-444444444441'
A_VEHICLE = '44444444-4444-4444-8444-444444444442'
A_FRONT1 = '44444444-4444-4444-8444-444444444443'
A_BACK1 = '44444444-4444-4444-8444-444444444444'
A_FRONT2 = '44444444-4444-4444-8444-444444444445'
A_BACK2 = '44444444-4444-4444-8444-444444444446'
OLD_DRIVER = '55555555-5555-4555-8555-555555555551'
OLD_VEHICLE = '55555555-5555-4555-8555-555555555552'
FOREIGN = '66666666-6666-4666-8666-666666666661'

with psycopg.connect(target_url, autocommit=True) as db:
    with db.cursor() as cur:
        cur.execute('''
        create schema auth;
        create schema app_private;
        do $$ begin
          if not exists (select 1 from pg_roles where rolname='authenticated') then
            create role authenticated nologin;
          end if;
          if not exists (select 1 from pg_roles where rolname='anon') then
            create role anon nologin;
          end if;
        end $$;
        grant usage on schema auth, public to authenticated;
        create function auth.uid() returns uuid language sql stable
        as $$select nullif(current_setting('test.actor',true),'')::uuid$$;
        create table public.projects(id uuid primary key, slug text unique not null);
        create table public.profiles(id uuid primary key, display_name text, phone text);
        create table public.driver_profiles(
          project_id uuid not null, user_id uuid not null, status text not null,
          suspended_at timestamptz, photo_asset_id uuid,
          identity_front_asset_id uuid, identity_back_asset_id uuid,
          identity_docs_required boolean not null, updated_at timestamptz default now(),
          primary key(project_id,user_id)
        );
        create table public.vehicles(
          id text primary key, project_id uuid, owner_user_id uuid, deleted_at timestamptz,
          marketplace_status text, main_photo_asset_id uuid, category_code text,
          propulsion_code text, brand text, model text, passenger_capacity integer,
          cargo_capacity_kg numeric, cargo_volume_m3 numeric, cargo_length_cm numeric,
          cargo_width_cm numeric, cargo_height_cm numeric
        );
        create table public.driver_vehicle_assignments(
          project_id uuid, driver_user_id uuid, vehicle_id text, is_active boolean
        );
        create table public.media_assets(
          id uuid primary key, project_id uuid, owner_user_id uuid,
          asset_kind text, storage_bucket text, storage_path text, status text
        );
        create table public.vehicle_services(
          project_id uuid, vehicle_id text, service_code text, enabled boolean
        );
        create table public.service_types(project_id uuid, code text, active boolean);
        create table public.marketplace_registration_drafts(
          project_id uuid, user_id uuid, scope text, fields jsonb not null default '{}'::jsonb,
          updated_at timestamptz not null default now(),
          primary key(project_id,user_id,scope)
        );
        alter table public.marketplace_registration_drafts enable row level security;
        revoke all on public.marketplace_registration_drafts from public,anon,authenticated;
        ''')
        cur.execute(get_and_save.group(1))
        cur.execute(gate.group(1))
        cur.execute('insert into public.projects(id,slug) values (%s,%s)',(PROJECT,'tuktuk-control'))
        for user, name, phone, driver_photo, vehicle_photo, vehicle_id, required in [
            (FIRST,'Conductor Nuevo','+5355555555',A_DRIVER,A_VEHICLE,'new-vehicle',True),
            (OLD,'Conductor Antiguo','+5355555556',OLD_DRIVER,OLD_VEHICLE,'old-vehicle',False),
        ]:
            cur.execute('insert into public.profiles(id,display_name,phone) values (%s,%s,%s)', (user,name,phone))
            cur.execute('''insert into public.driver_profiles(project_id,user_id,status,photo_asset_id,identity_docs_required)
                           values(%s,%s,'active',%s,%s)''', (PROJECT,user,driver_photo,required))
            cur.execute('''insert into public.vehicles(id,project_id,owner_user_id,marketplace_status,main_photo_asset_id,
                          category_code,propulsion_code,brand,model,passenger_capacity,cargo_capacity_kg)
                          values(%s,%s,%s,'active',%s,'tuktuk','electric','Q7','Estándar',2,0)''',
                        (vehicle_id,PROJECT,user,vehicle_photo))
            cur.execute('''insert into public.driver_vehicle_assignments(project_id,driver_user_id,vehicle_id,is_active)
                          values(%s,%s,%s,true)''', (PROJECT,user,vehicle_id))
            cur.execute("insert into public.vehicle_services values(%s,%s,'passenger',true)",(PROJECT,vehicle_id))
            for aid,kind in [(driver_photo,'driver_photo'),(vehicle_photo,'vehicle_photo')]:
                cur.execute('''insert into public.media_assets values(%s,%s,%s,%s,'marketplace-media',%s,'available')''',
                            (aid,PROJECT,user,kind,kind+'/'+aid))
        cur.execute("insert into public.service_types values(%s,'passenger',true)",(PROJECT,))
        for aid, owner, kind in [
            (A_FRONT1,FIRST,'identity_front'),(A_BACK1,FIRST,'identity_back'),
            (A_FRONT2,FIRST,'identity_front'),(A_BACK2,FIRST,'identity_back'),
            (FOREIGN,STRANGER,'identity_front')
        ]:
            cur.execute('''insert into public.media_assets values(%s,%s,%s,%s,'marketplace-identity',%s,'available')''',
                        (aid,PROJECT,owner,kind,kind+'/'+aid))

        def gate_result(user, vehicle):
            cur.execute('select app_private.marketplace_onboarding_requirements_complete(%s,%s)',(user,vehicle))
            return cur.fetchone()[0]

        assert gate_result(OLD,'old-vehicle') is True, 'LEGACY_DRIVER_NOT_ACTIVE_PRE_MIGRATION'
        assert gate_result(FIRST,'new-vehicle') is False, 'NEW_DRIVER_PRE_MIGRATION_NOT_BLOCKED'
        # Este caso reproduce el agujero real: dos fotos sin tipo sí permitían trabajar.
        cur.execute('''update public.driver_profiles
            set identity_front_asset_id=%s, identity_back_asset_id=%s where user_id=%s''',
            (A_FRONT1,A_BACK1,FIRST))
        assert gate_result(FIRST,'new-vehicle') is True, 'OLD_GATE_DID_NOT_REPRODUCE_BYPASS'
        cur.execute(new)
        cur.execute(new)  # Idempotencia para CI y despliegues controlados.
        assert gate_result(OLD,'old-vehicle') is True, 'LEGACY_DRIVER_REGRESSION'
        assert gate_result(FIRST,'new-vehicle') is False, 'NEW_DRIVER_WITHOUT_TYPE_CAN_WORK'
        # Volver al onboarding incompleto, sin usar datos reales.
        cur.execute('''update public.driver_profiles
            set identity_front_asset_id=null, identity_back_asset_id=null where user_id=%s''', (FIRST,))

        def rpc(actor, sql, params=()):
            cur.execute("select set_config('test.actor',%s,false)",(actor,))
            cur.execute('set role authenticated')
            try:
                cur.execute(sql,params)
                return cur.fetchone()[0]
            finally:
                cur.execute('reset role')

        def fails(actor, sql, params, marker):
            try:
                rpc(actor,sql,params)
            except psycopg.Error as err:
                assert marker in str(err), f'ERROR_WRONG: {err}'
            else:
                raise AssertionError(f'UNEXPECTED_SQL_SUCCESS: {marker}')

        saved = rpc(FIRST,'select public.save_my_marketplace_identity_document_type_draft(%s)',('national_id',))
        assert saved['identity_document_type'] == 'national_id', 'DRAFT_MISSING_TYPE'
        fails(FIRST,'select public.save_my_marketplace_identity_document_type_draft(%s)',('invalid',),'INVALID_IDENTITY_DOCUMENT_TYPE')
        fails(FIRST,'select public.save_my_marketplace_identity_documents_v2(%s,%s,%s)',
              (A_FRONT1,None,'national_id'),'IDENTITY_DOCUMENT_BOTH_SIDES_REQUIRED')
        cur.execute('select identity_front_asset_id from public.driver_profiles where user_id=%s',(FIRST,))
        assert cur.fetchone()[0] is None, 'PARTIAL_SAVE_NOT_ROLLED_BACK'

        saved=rpc(FIRST,'select public.save_my_marketplace_identity_documents_v2(%s,%s,%s)',
                  (A_FRONT1,A_BACK1,'national_id'))
        assert saved['document_type'] == 'national_id' and saved['front'] and saved['back']
        assert gate_result(FIRST,'new-vehicle') is True, 'NEW_DRIVER_WITH_TYPE_AND_PHOTOS_NOT_ALLOWED'

        fails(FIRST,'select public.save_my_marketplace_identity_documents_v2(%s,%s,%s)',
              (A_FRONT1,A_BACK1,'driver_license'),'DOCUMENT_PHOTOS_MUST_BE_REPLACED')
        fails(FIRST,'select public.save_my_marketplace_identity_documents_v2(%s,%s,%s)',
              (FOREIGN,A_BACK2,'driver_license'),'INVALID_IDENTITY_FRONT')
        saved=rpc(FIRST,'select public.save_my_marketplace_identity_documents_v2(%s,%s,%s)',
                  (A_FRONT2,A_BACK2,'driver_license'))
        assert saved['document_type'] == 'driver_license' and gate_result(FIRST,'new-vehicle')
        assert gate_result(OLD,'old-vehicle'), 'OLD_DRIVER_MUST_REMAIN_ALLOWED'
        old_docs=rpc(OLD,'select public.get_my_marketplace_identity_documents()')
        assert old_docs['required'] is False and old_docs['document_type'] is None, 'OLD_DRIVER_DOC_TYPE_CHANGED'
        assert rpc(STRANGER,'select public.get_my_marketplace_identity_documents()')['front'] is None
        cur.execute("select has_table_privilege('authenticated','public.marketplace_registration_drafts','select')")
        assert cur.fetchone()[0] is False, 'DIRECT_DRAFT_ACCESS_ALLOWED'
        cur.execute("select has_function_privilege('anon','public.save_my_marketplace_identity_documents_v2(uuid,uuid,text)','execute')")
        assert cur.fetchone()[0] is False, 'ANON_CAN_USE_DOCUMENT_RPC'
        cur.execute("select has_function_privilege('anon','public.save_my_marketplace_identity_document_type_draft(text)','execute')")
        assert cur.fetchone()[0] is False, 'ANON_CAN_WRITE_DRAFT'
        print('PR106_ISOLATED_POSTGRESQL_IDENTITY_DOCUMENTS=OK')
