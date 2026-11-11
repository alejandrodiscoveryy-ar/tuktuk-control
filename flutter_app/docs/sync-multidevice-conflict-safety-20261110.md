# PR #121: contención de conflictos sin bloquear toda la sincronización

## Problema comprobado en el código anterior

Un pull remoto que ganaba por fecha podía sustituir un registro local con
operación pendiente y eliminar su cola. Un bloqueo global simple tampoco era
aceptable: interrumpía las demás operaciones del conductor.

## Diseño aplicado en el borrador

- Si no hay una edición local pendiente, se conserva el flujo actual.
- Si un registro local tiene una edición sin enviar, el pull nunca sobrescribe
  ese registro ni retira su operación de la cola.
- Se compara la versión remota con el contenido actual y con la versión previa
  a la edición. Un reenvío idéntico no genera conflicto. Si no hay base previa
  y el contenido remoto es diferente, se preserva como divergencia.
- Las preferencias se comparan por contenido, normalizando sus campos antiguos.
- Las discrepancias de propietario o vehículo se conservan sin exportar datos
  privados de una cuenta diferente.
- La copia local, la copia remota y los metadatos de la operación se conservan
  bajo una clave local por cuenta y registro, sin resolverlos automáticamente.
- Sólo la operación afectada se excluye del push; el resto de la cola continúa.
- El aviso aparece en la WebApp, con un contador. La exportación JSON incluye
  ambas copias como `syncConflictSnapshots` para conservación manual.
- La importación normal de un respaldo **no** restaura ni resuelve automáticamente
  esos conflictos. No realizar restauraciones destructivas como solución.
- Una edición pendiente de preferencias no se reemplaza durante el pull y
  se compara contra la base anterior si la operación tiene esa referencia.

## Lo que **no** está resuelto

El servidor actual acepta `upsert` incondicional en `sync_entities`.
Un cambio remoto posterior al pull y anterior al push todavía puede ser
sobrescrito sin control de versiones. Para una solución completa hacen falta
versiones monotónicas de servidor, actualización condicional atómica,
compatibilidad con clientes antiguos, pruebas SQL aisladas y un procedimiento
para resolver cada conflicto de forma explícita. No desplegar un cambio de
base de datos sin autorización expresa.

Esta es una protección parcial conservadora; el PR continúa **draft**.
No se han modificado Supabase, APK o WebApp de producción.
