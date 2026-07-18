# Base SaaS de TukTuk Control

## Alcance de esta fase

Esta fase conserva el funcionamiento local y offline. No activa pagos,
restricciones por plan, autenticacion obligatoria ni sincronizacion con
Supabase. Tampoco modifica la interfaz.

La base actual separa presentacion, dominio, almacenamiento local y contratos
de sincronizacion. Hive continua siendo la fuente de verdad del dispositivo.
Google Drive se mantiene solamente porque ya era parte del funcionamiento
existente; no se agrega ningun servicio externo nuevo.

## Estado actual

- `DailyRecord` representa la jornada operativa y conserva ingreso, gasto,
  recorrido/odometro y carga. Incluye `id`, `userId`, `vehicleId`,
  `createdAt`, `updatedAt`, `syncStatus` y `deletedAt`.
- `MaintenanceRecord` y `VehicleProfile` incluyen la misma metadata de
  propiedad, version y sincronizacion que corresponde a su entidad.
- Los datos se guardan primero en Hive y cada cambio genera una operacion en
  la cola local de sincronizacion.
- Existe un propietario local estable por dispositivo (`localOwnerId`) y un
  vehiculo local principal. Los registros antiguos sin propietario o vehiculo
  se completan durante la migracion sin cambiar su identificador ni contenido.
- La arquitectura admite varios vehiculos, aunque la interfaz actual mantiene
  el vehiculo activo para no alterar la experiencia existente.
- Los contratos `AuthService`, `LicenseService`, `SyncService`,
  `UserRepository` y `VehicleRepository` separan futuras implementaciones
  remotas del dominio y la interfaz.
- El estado local de licencia no restringe funciones. Los modelos contemplan
  prueba, vigencia, vencimiento, suspension, pago pendiente y gracia offline.
- Los respaldos JSON incluyen version de esquema, propietario, vehiculo,
  identificadores y fechas. La lectura conserva compatibilidad con campos
  ausentes de respaldos anteriores.

## Riesgos antes de convertirlo en SaaS

1. `DailyRecord` agrupa varios conceptos operativos. Un backend relacional
   debera decidir si mantiene este agregado o normaliza ingresos, gastos,
   recorridos y cargas en tablas separadas.
2. La reclamacion del propietario local por una cuenta autenticada debe ser
   atomica en el backend para evitar duplicados si el mismo dispositivo reintenta.
3. La resolucion de conflictos por `updatedAt` requiere reloj de servidor o una
   estrategia de revision para dispositivos con horas incorrectas.
4. Las preferencias generales aun viven en claves simples de Hive. Antes de
   sincronizarlas deben convertirse en una entidad versionada por usuario y,
   cuando corresponda, por vehiculo.
5. Google Drive usa un respaldo completo; no debe confundirse con la futura
   sincronizacion incremental de Supabase.
6. Roles, membresias y permisos estan modelados, pero no deben considerarse un
   control de seguridad hasta que tambien se validen en el backend.
7. La cola registra cambios pendientes, pero la descarga y aplicacion completa
   de cambios remotos todavia no esta implementada.

## Archivos involucrados

- `lib/domain/entities.dart`: registros, vehiculos y metadata sincronizable.
- `lib/domain/saas_foundation.dart`: usuario local, licencias, planes y contratos.
- `lib/domain/access.dart`: roles y politicas de acceso sin activacion comercial.
- `lib/domain/sync.dart`: operaciones, conflictos y contratos remotos.
- `lib/data/record_store.dart`: migraciones, Hive, respaldo y vehiculo activo.
- `lib/data/sync_queue.dart`: cola offline-first.
- `lib/services/sync_coordinator.dart`: coordinacion desacoplada del proveedor.
- `test/domain/entities_test.dart`: compatibilidad, propiedad y licencias locales.
- `test/domain/sync_test.dart`: cola, conflictos y proveedor no configurado.

## Plan por fases

### Fase 1: base local compatible (actual)

- Versionar entidades y respaldos.
- Asignar propietario y vehiculo locales a datos antiguos.
- Mantener IDs y contenido historico.
- Incorporar borrado logico y cola de cambios.
- Definir contratos de autenticacion, licencias, repositorios y sincronizacion.
- Mantener restricciones desactivadas y acceso sin inicio de sesion.

### Fase 2: repositorios y preferencias versionadas

- Mover el acceso directo a Hive detras de repositorios locales concretos.
- Crear entidades separadas para configuracion y manifiestos de respaldo.
- Añadir transacciones de migracion con registro de resultado y recuperacion.
- Mantener la interfaz sin cambios visibles.

### Fase 3: adaptador remoto de prueba

- Presentar primero el diseño de tablas, politicas RLS y estrategia de secretos.
- Implementar un adaptador Supabase desactivado por configuracion.
- Probar subida, descarga, cursores, idempotencia y conflictos con datos ficticios.
- Conservar Hive como escritura primaria y permitir uso totalmente offline.

### Fase 4: identidad y multivehiculo

- Migrar de usuario local a cuenta autenticada de forma idempotente.
- Incorporar organizaciones, propietarios, conductores y asignaciones.
- Habilitar selector multivehiculo solo despues de validar compatibilidad.

### Fase 5: licencias y administracion

- Integrar validacion de planes y periodo de prueba sin mezclarla con UI.
- Añadir panel administrativo con autorizacion de servidor.
- Activar restricciones solamente despues de pruebas, telemetria y plan de gracia offline.

## Migraciones necesarias

- Respaldar antes de cada aumento de `schemaVersion`.
- Completar `deviceId`, `userId` y `vehicleId` solo cuando falten.
- Preservar el `id`, las fechas operativas y todos los importes originales.
- Crear un vehiculo principal estable para datos heredados sin relacion.
- Reasignar propietario local a usuario autenticado sin copiar registros.
- Convertir eliminaciones fisicas futuras en `deletedAt` y operacion `delete`.
- Mantener lectores tolerantes a respaldos sin metadata SaaS.

## Pruebas obligatorias por etapa

- `flutter test` para serializacion, migracion, propiedad, licencias, cola y conflictos.
- `flutter analyze` para validar tipos y contratos.
- Prueba de restauracion de respaldo anterior y del formato actual.
- Prueba de instalacion nueva vacia y de instalacion con datos existentes.
- Prueba offline completa: crear, editar y eliminar sin red.
- Prueba de cambio entre vehiculos sin mezclar registros.
- Prueba de reclamacion local repetida para verificar idempotencia.
- Cuando exista backend, pruebas de RLS, reintentos, cursores y relojes desalineados.

## Criterio de salida de la fase 1

La fase se considera segura cuando las pruebas y el analisis pasan, la UI no
cambia, Hive sigue siendo la fuente local, los datos existentes conservan sus
IDs y contenido, y ninguna regla comercial bloquea funciones.
