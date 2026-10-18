-- TUKTUK Conductor: impedir disponibilidad de vehiculos sin activacion.
-- Corrige las asignaciones futuras, transiciones posteriores y datos existentes.
-- No elimina vehiculos ni altera asignaciones de vehiculos activos.

-- El disparador ya existente de asignaciones pasa a verificar el estado real
-- del vehiculo. Un vinculo puede estar activo sin que el vehiculo este listo.
CREATE OR REPLACE FUNCTION app_private.enforce_marketplace_accepting_jobs()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF NOT NEW.accepting_jobs THEN
    NEW.is_available := false;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.vehicles v
    JOIN public.projects p ON p.id = v.project_id
    WHERE p.slug = 'tuktuk-control'
      AND v.project_id = NEW.project_id
      AND v.id = NEW.vehicle_id
      AND (
        v.deleted_at IS NOT NULL
        OR v.marketplace_status IS DISTINCT FROM 'active'
      )
  ) THEN
    NEW.accepting_jobs := false;
    NEW.is_available := false;
  END IF;

  RETURN NEW;
END;
$function$;

-- Si un vehiculo deja de estar activo, tambien debe salir de disponibilidad
-- aunque nadie haya modificado directamente su asignacion.
CREATE OR REPLACE FUNCTION app_private.disable_unready_marketplace_vehicle_availability()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.projects p
    WHERE p.id = NEW.project_id AND p.slug = 'tuktuk-control'
  ) THEN
    UPDATE public.driver_vehicle_assignments a
       SET accepting_jobs = false,
           is_available = false,
           updated_at = now()
     WHERE a.project_id = NEW.project_id
       AND a.vehicle_id = NEW.id
       AND (a.accepting_jobs OR a.is_available);
  END IF;

  RETURN NEW;
END;
$function$;

CREATE TRIGGER tuktuk_vehicle_unready_availability_guard
AFTER UPDATE OF marketplace_status, deleted_at ON public.vehicles
FOR EACH ROW
WHEN (NEW.marketplace_status IS DISTINCT FROM 'active' OR NEW.deleted_at IS NOT NULL)
EXECUTE FUNCTION app_private.disable_unready_marketplace_vehicle_availability();

-- Reconciliar exclusivamente asignaciones de TUKTUK no activas.
-- No tocar vehiculos activos, sus turnos, licencias ni carreras.
UPDATE public.driver_vehicle_assignments a
   SET accepting_jobs = false,
       is_available = false,
       updated_at = now()
  FROM public.vehicles v
  JOIN public.projects p ON p.id = v.project_id
 WHERE p.slug = 'tuktuk-control'
   AND a.project_id = v.project_id
   AND a.vehicle_id = v.id
   AND (v.deleted_at IS NOT NULL OR v.marketplace_status IS DISTINCT FROM 'active')
   AND (a.accepting_jobs OR a.is_available);

DO $checks$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.driver_vehicle_assignments a
    JOIN public.vehicles v ON v.project_id = a.project_id AND v.id = a.vehicle_id
    JOIN public.projects p ON p.id = v.project_id
    WHERE p.slug = 'tuktuk-control'
      AND (v.deleted_at IS NOT NULL OR v.marketplace_status IS DISTINCT FROM 'active')
      AND (a.accepting_jobs OR a.is_available)
  ) THEN
    RAISE EXCEPTION 'TUKTUK_UNREADY_VEHICLE_REMAINS_AVAILABLE';
  END IF;
END;
$checks$;
