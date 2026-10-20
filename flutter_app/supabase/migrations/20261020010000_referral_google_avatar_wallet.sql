-- TUKTUK Conductor. Restaurar avatar_url en dos modos antiguos del RPC.
-- Solo agrega un atributo a la respuesta JSON; no modifica relaciones,
-- recompensas, licencias, tablas ni permisos.
-- Este archivo NO se aplica a produccion desde GitHub ni al abrir el PR.
begin;

do $migration$
declare
  v_definition text;
  v_old constant text := '''qualified_at'',r.qualified_at)';
  v_new constant text := '''qualified_at'',r.qualified_at,''avatar_url'',p.avatar_url)';
  v_existing constant text := '''avatar_url'',p.avatar_url';
  v_old_count integer;
  v_existing_count integer;
begin
  select pg_catalog.pg_get_functiondef('public.get_my_referrals(uuid)'::regprocedure)
    into v_definition;
  if v_definition is null
     or position('SECURITY DEFINER' in v_definition) = 0
     or position('auth.uid()' in v_definition) = 0
     or position('r.referrer_user_id=actor' in v_definition) = 0 then
    raise exception 'REFERRALS_FUNCTION_CONTRACT_UNEXPECTED';
  end if;
  v_old_count := (length(v_definition) - length(replace(v_definition, v_old, ''))) / length(v_old);
  v_existing_count := (length(v_definition) - length(replace(v_definition, v_existing, ''))) / length(v_existing);

  if v_old_count = 2 and v_existing_count = 1 then
    execute replace(v_definition, v_old, v_new);
    raise notice 'REFERRAL_AVATAR_RESPONSE_ENABLED';
  elsif v_old_count = 0 and v_existing_count = 3 then
    raise notice 'REFERRAL_AVATAR_RESPONSE_ALREADY_ENABLED';
  else
    raise exception 'REFERRAL_AVATAR_MIGRATION_UNEXPECTED_FUNCTION old=% existing=%',
      v_old_count, v_existing_count;
  end if;
end;
$migration$;

commit;
