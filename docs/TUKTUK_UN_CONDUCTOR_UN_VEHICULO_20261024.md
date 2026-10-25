# Regla temporal de inscripción: un conductor, un vehículo en Trabajos

- En el módulo Trabajos se usa un solo vehículo operativo por conductor.
- Si ya existe una ficha, el formulario permite completarla y no ofrece crear otra.
- Un vehículo activo y completo tiene prioridad sobre borradores históricos.
- El servidor ya limita `get_my_marketplace_onboarding` y `create_my_marketplace_vehicle` con `marketplace_one_driver_one_operational_vehicle_20261024`.
- Restricciones posteriores verificadas en Supabase:
  - `tuktuk_one_driver_one_operational_vehicle_constraints_20261024` (una asignación activa y un vehículo habilitado).
  - `tuktuk_prevent_marketplace_vehicle_drafts_from_legacy_clients_20261024` (bloqueo de duplicados creados por clientes antiguos).
- **Pendiente separado:** sincronizar las migraciones aplicadas remotamente con el repositorio canónico de backend. Este script NO modifica Supabase ni el repositorio backend.
- Los vehículos históricos no se borran: pueden estar vinculados a ingresos, kilómetros, sincronización, servicios anteriores o pagos.
- El botón Trabajar/Descansar continúa siendo controlado voluntariamente por el conductor.

## Compatibilidad

Esta restricción es una regla de producto para **Trabajos/Marketplace**, no una eliminación del modelo de múltiples vehículos de Control/Hive. Las versiones anteriores siguen protegidas por el servidor. No se modifican tablas, datos existentes ni permisos de la base de datos desde esta rama.

## Verificación

- `flutter analyze --no-pub`
- `flutter test --no-pub test/domain/marketplace_models_test.dart`
- Validación manual: conductor nuevo, conductor con vehículo único incompleto, conductor con ficha activa y borradores históricos (Acosta), cambio de estado Trabajar/Descansar y datos offline de Control.

## Estado de publicación

Un PR en borrador no implica integración ni publicación web/APK. Requiere auditoría y autorización posterior.