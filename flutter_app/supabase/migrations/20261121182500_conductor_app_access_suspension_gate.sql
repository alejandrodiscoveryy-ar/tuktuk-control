-- Control de acceso exclusivamente a TukTuk Conductor.
-- La identidad Google/Supabase es compartida por otros servicios: no se bloquea auth.users.
-- Se reutiliza el estado de suspensión existente, sin duplicar sanciones ni cuentas.
CREATE OR REPLACE FUNCTION public.get_my_tuktuk_conductor_app_access()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  actor uuid := auth.uid();
  current_status text;
  suspended_on timestamptz;
  current_reason text;
  blocked boolean;
BEGIN
  IF actor IS NULL THEN
    RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING errcode='42501';
  END IF;

  SELECT d.status, d.suspended_at, d.suspension_reason
    INTO current_status, suspended_on, current_reason
  FROM public.driver_profiles d
  JOIN public.projects p ON p.id=d.project_id
  WHERE p.slug='tuktuk-control' AND d.user_id=actor
  LIMIT 1;

  blocked := coalesce(current_status='suspended' OR suspended_on IS NOT NULL, false);

  RETURN jsonb_build_object(
    'suspended', blocked,
    'reason', CASE WHEN blocked THEN nullif(btrim(current_reason), '') ELSE NULL END
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.get_my_tuktuk_conductor_app_access() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_tuktuk_conductor_app_access() TO authenticated;
