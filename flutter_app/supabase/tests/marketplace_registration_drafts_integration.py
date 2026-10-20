"""Verifica exclusivamente base PostgreSQL desechable; nunca conecta a producción."""
import os
from pathlib import Path
import psycopg
from psycopg.types.json import Jsonb

uri = os.environ['TEST_DATABASE_URL']
assert 'drafts_disposable' in uri and 'localhost' in uri, 'TEST_DATABASE_URL must be disposable'
path = Path(__file__).resolve().parents[1] / 'migrations' / '20261020230000_marketplace_registration_drafts.sql'

FIRST='11111111-1111-4111-8111-111111111111'
SECOND='22222222-2222-4222-8222-222222222222'
PROJECT='33333333-3333-4333-8333-333333333333'
ASSET='44444444-4444-4444-8444-444444444444'

with psycopg.connect(uri, autocommit=True) as db:
    with db.cursor() as cur:
        cur.execute('CREATE SCHEMA auth')
        cur.execute('CREATE ROLE authenticated NOLOGIN')
        cur.execute('CREATE ROLE anon NOLOGIN')
        cur.execute('CREATE TABLE auth.users(id uuid primary key)')
        cur.execute('CREATE TABLE public.projects(id uuid primary key, slug text not null unique)')
        cur.execute('CREATE TABLE public.driver_profiles(project_id uuid, user_id uuid, status text)')
        cur.execute('CREATE TABLE public.vehicles(id text primary key, project_id uuid, owner_user_id uuid, deleted_at timestamptz, marketplace_status text)')
        cur.execute('CREATE TABLE public.vehicle_categories(project_id uuid, code text, active boolean)')
        cur.execute('CREATE TABLE public.propulsion_types(project_id uuid, code text, active boolean)')
        cur.execute('CREATE TABLE public.service_types(project_id uuid, code text, active boolean)')
        cur.execute('CREATE TABLE public.media_assets(id uuid primary key, project_id uuid, owner_user_id uuid, asset_kind text, status text, storage_bucket text)')
        cur.execute("CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('test.actor',true),'')::uuid $$")
        cur.execute('INSERT INTO auth.users(id) VALUES (%s),(%s)', (FIRST,SECOND))
        cur.execute('INSERT INTO public.projects(id,slug) VALUES (%s,%s)', (PROJECT,'tuktuk-control'))
        cur.execute('INSERT INTO public.vehicles(id,project_id,owner_user_id,marketplace_status) VALUES (%s,%s,%s,%s),(%s,%s,%s,%s)',
                    ('vehicle-first',PROJECT,FIRST,'onboarding','vehicle-second',PROJECT,SECOND,'onboarding'))
        cur.execute('INSERT INTO public.vehicle_categories VALUES (%s,%s,true)',(PROJECT,'tuktuk'))
        cur.execute('INSERT INTO public.propulsion_types VALUES (%s,%s,true)',(PROJECT,'electric'))
        cur.execute('INSERT INTO public.service_types VALUES (%s,%s,true)',(PROJECT,'passengers'))
        cur.execute('INSERT INTO public.media_assets VALUES (%s,%s,%s,%s,%s,%s)',(ASSET,PROJECT,FIRST,'identity_front','available','marketplace-identity'))
        cur.execute(path.read_text(encoding='utf-8'))
        # RLS protegida, y sin autorización directa ni siquiera para seleccionar.
        cur.execute("SELECT set_config('test.actor', %s, false)", (FIRST,))
        cur.execute('SET ROLE authenticated')
        cur.execute("SELECT save_my_marketplace_registration_draft_field(NULL,'name',%s)",(Jsonb('Alejandro Cruz'),))
        cur.execute("SELECT save_my_marketplace_registration_draft_field(NULL,'phone',%s)",(Jsonb('+5355555555'),))
        cur.execute("SELECT save_my_marketplace_registration_draft_field('vehicle-first','brand',%s)",(Jsonb('Q7'),))
        cur.execute("SELECT save_my_marketplace_registration_draft_field('vehicle-first','services',%s)",(Jsonb(['passengers']),))
        cur.execute("SELECT save_my_marketplace_registration_draft_field(NULL,'identity_front_id',%s)",(Jsonb(ASSET),))
        cur.execute('SELECT get_my_marketplace_registration_drafts()')
        fields=cur.fetchone()[0]
        assert fields['driver']['name']=='Alejandro Cruz' and fields['vehicle:vehicle-first']['brand']=='Q7'
        assert fields['driver']['identity_front_id']==ASSET
        try:
            cur.execute('SELECT * FROM public.marketplace_registration_drafts')
        except psycopg.errors.InsufficientPrivilege:
            pass
        else:
            raise AssertionError('Direct table access incorrectly allowed')
        try:
            cur.execute("SELECT save_my_marketplace_registration_draft_field('vehicle-second','brand',%s)",(Jsonb('BAD'),))
        except psycopg.errors.InsufficientPrivilege:
            pass
        else:
            raise AssertionError('Unowned vehicle accepted')
        cur.execute('RESET ROLE')
        cur.execute("SELECT set_config('test.actor', %s, false)", (SECOND,))
        cur.execute('SET ROLE authenticated')
        cur.execute('SELECT get_my_marketplace_registration_drafts()')
        assert cur.fetchone()[0]=={}, 'Drafts leaked between accounts'
        cur.execute('RESET ROLE')
        cur.execute("SELECT set_config('test.actor', %s, false)", (FIRST,))
        cur.execute('SET ROLE authenticated')
        cur.execute("SELECT clear_my_marketplace_registration_drafts('vehicle-first')")
        cur.execute('SELECT get_my_marketplace_registration_drafts()')
        assert cur.fetchone()[0]=={}, 'Clearing a completed registration left stale drafts'
print('ISOLATED_POSTGRESQL_DRAFT_SECURITY=OK')
