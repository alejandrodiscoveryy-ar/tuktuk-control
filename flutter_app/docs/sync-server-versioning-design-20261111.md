# PR #121 — Plan técnico de versionado de servidor y convivencia con APK antiguas

**Fecha:** 2026-11-11. **Estado:** DISEÑO / PENDIENTE DE IMPLEMENTACIÓN Y VALIDACIÓN.  
**Repositorio:** `alejandrodiscoveryy-ar/tuktuk-control`. **Rama:** `fix/conductor-multidevice-conflict-safety-20261110`.  
**Alcance:** exclusivamente sincronización de datos de TukTuk Control / Conductor (`public.sync_entities`); no modifica carreras del Marketplace, billeteras, GPS, precios, Supabase ni producción.

## 1. Evidencia verificada en modo lectura

- PR #121 abierto como *draft*; conserva la cola local, las dos copias del conflicto y el aviso desde la WebApp. Aún **no** resuelve conflictos ni impide la carrera entre pull y push.
- `public.sync_entities` tiene PK `(user_id, entity_type, entity_id)`; columnas `vehicle_id, device_id, payload, updated_at, deleted_at`. No tiene `version` ni CAS.
- La app actual realiza `upsert` por lote con `onConflict: user_id,entity_type,entity_id` sin precondición de versión; el `pull` ordena por `updated_at, entity_type, entity_id`.
- Existen tres triggers con lógica de negocio en `sync_entities`: alias de vehículos, proyección de vehículo legado, bloqueo de carreras de prueba eliminadas. **No reemplazar ni deshabilitar** esas protecciones.
- RLS de lectura limita a `auth.uid()=user_id`; INSERT, UPDATE y DELETE además exigen `app_private.current_user_has_control_write_entitlement()`.
- **Hallazgo adicional de permisos:** `has_table_privilege('authenticated','public.sync_entities','TRUNCATE') = true`. PostgreSQL no aplica RLS a TRUNCATE. Es un privilegio excesivo que merece una corrección independiente y prioritaria, con aprobación previa; no se ha explotado ni probado con escritura.
- Se observaron 793 filas estimadas en `sync_entities` al inspeccionar metadatos; **no equivale** a un conteo transaccional exacto. No consultar ni copiar información personal para esta fase.

## 2. Decisión de arquitectura (propuesta, no aprobada)

### 2.1 Protocolo nuevo para WebApp / clientes actualizados

1. Añadir columna interna `server_version bigint NOT NULL DEFAULT 1 CHECK(server_version >= 1)`, con progresión monotónica **impuesta en el servidor** para INSERT/UPDATE, no por hora del teléfono.
2. Conservar los campos existentes, sus nombres y el `updated_at` que usan las APK antiguas. Los clientes antiguos pueden omitir la nueva columna.
3. Crear un contrato transaccional de escritura v2 (RPC), con usuario obtenido de sesión autenticada, identidad de entidad, carga, identificador único de mutación y **versión esperada**. Ningún cliente debe poder aportar arbitrariamente la nueva versión.
4. Bajo bloqueo de la fila y una única transacción: validar `auth.uid()`, derecho de escritura, identidad/vehículo, tipo de entidad, permisos y versión. Si coincide, guardar e incrementar versión; si no, responder `conflict` con versión actual sin tocar la copia remota.
5. Para nueva entidad, exigir versión esperada cero y resolver inserciones concurrentes por PK; no convertir silenciosamente `insert` en un `update`.
6. Registrar el acuse de cada mutación por `user_id + mutation_id` con garantía idempotente. Reintentar una operación ya aplicada debe devolver el mismo acuse y no incrementar de nuevo la versión. Verificar tamaño y retención del registro de acuses.
7. El resultado por operación debe distinguir `applied`, `already_applied`, `conflict`, `forbidden`, `invalid` y error temporal. Fallar una operación no bloquea las demás; las aceptadas pueden salir de Hive solo tras acuse verificable.
8. Tras sincronizar, guardar en Hive la versión del servidor conocida para cada registro y la base de edición. Cuidar que el acuse de una operación antigua no confirme una edición local más reciente.

**Seguridad:** Preferir una RPC bajo privilegios mínimos, con permisos expresos. Si se necesita `SECURITY DEFINER` para una tabla privada de acuses, aplicar `SET search_path = ''`, objetos calificados, comprobación obligatoria de `auth.uid()`, pertenencia y autorización, `REVOKE EXECUTE FROM PUBLIC, anon`, y `GRANT EXECUTE TO authenticated` únicamente a la función permitida. Nunca incluir `service_role` en clientes. Revisar posibles rutas alternativas de escritura directa, RLS y funciones existentes.

### 2.2 Cliente antiguo: límite técnico inevitable

Las APK distribuidas hoy escriben mediante `upsert` **sin enviar versión esperada**. El servidor no puede deducir de forma fiable si una escritura de esas APK proviene de una base obsoleta; comparar relojes tampoco garantiza causalidad. No prometer simultáneamente CAS obligatorio, compatibilidad de escrituras antiguas y ausencia absoluta de sobrescrituras.

**Plan de convivencia recomendado:**
- Fase transitoria **aditiva**: el trigger actualiza la versión y registra, en un historial privado y acotado, las imágenes anterior y nueva, origen/versión y momento de cada modificación, incluidas las escrituras legadas; no cambiar la forma de `upsert` de las APK.
- Las nuevas WebApps escriben mediante RPC v2 con CAS; cualquier escritura previa a una RPC incompatible provoca respuesta de conflicto.
- Una escritura legada posterior **aún podría reemplazar** el valor visible de una versión v2. El historial conserva evidencia para recuperación, pero no equivale a protección estricta en tiempo real. Incorporar identificación y visualización de tales divergencias en la WebApp nueva antes de reclamar seguridad total.
- Para protección estricta universal, retirar escritura directa de APK antiguas solo tras distribución y aceptación de una versión actualizada y una política aprobada de versión mínima. **Ese corte rompe escritura de APK antiguas**, por lo que requiere decisión expresa del propietario y plan de comunicación.
- No redirigir silenciosamente datos antiguos a otra cuenta o vehículo ni borrar registros originales.

### 2.3 Resolución desde la WebApp (sin pruebas manuales aisladas)

- Mostrar aviso comprensible y contador; permitir abrir un registro y comparar copia local, copia remota, fecha, origen y versión.
- Ofrecer `Conservar mi cambio` (vuelve a enviar contra versión remota conocida), `Usar versión de la nube` y `Mantener ambas como respaldo` según tipo de dato. Toda decisión exige confirmación; ninguna elimina silenciosamente una copia.
- No resolver automáticamente cambios de propietario/vehículo ni eliminaciones; respetar pertenencia por cuenta y confirmación reforzada.
- Resolver un conflicto no debe frenar otras operaciones pendientes; si la versión remota cambió durante la elección, pedir nueva revisión.
- Conservar respaldo JSON compatible, *tombstones* (`deleted_at`) y recuperación del historial; no restaurar masivamente Hive como atajo.

## 3. Plan de entregas sin cambios productivos no autorizados

**Etapa A — Baseline de seguridad y compatibilidad.** Inventariar APK publicadas y sus rutas reales de escritura, RLS, triggers, dependencias del pull y reversibilidad. Documentar corrección separada del exceso de TRUNCATE.

**Etapa B — Migración en entorno aislado.** Generar migración por CLI y probar: columna aditiva, trigger de incremento, historial privado, acuses, RPC condicional y grants; conservar las funciones existentes. No realizar DDL en el proyecto remoto durante desarrollo. Medir bloqueos e impacto sobre los 793 registros estimados, sin copiar datos privados a fixtures.

**Etapa C — Integración Flutter WebApp en la rama.** Ampliar gateway, DTO, versión conocida en Hive, acuses, cola, pull e interfaz de resolución. Evitar pérdida de cambios con concurrencia edición/acuse, caída tras commit y cambio de usuario. Mantener ruta antigua para instalaciones que aún la usan.

**Etapa D — Verificación.** Tests unitarios y SQL en base aislada, ejecución concurrente de dos clientes sobre una misma entidad, pruebas negativas de acceso entre cuentas, idempotencia, tombstones, triggers de vehículos/carreras, respaldo/restauración, interrupción/reanudación offline, migración repetida, rollback, rendimiento y pruebas WebApp de punta a punta.

**Etapa E — Aprobación de cambios reales.** Solicitar permiso específico para migración, permisos, despliegue, merge y publicación como decisiones independientes. Respaldar y verificar restauración antes de DDL en producción. Registrar SHA exacto, resultado de migración, pruebas y plan de retorno. No compilar ni distribuir APK sin autorización.

## 4. Criterios para cerrar PR #121

- [ ] SQL de migración creado por flujo estándar, revisado y probado fuera de producción.
- [ ] RPC v2 versionada e idempotente probada con competencia real; las operaciones fallidas nunca se marcan sincronizadas.
- [ ] RLS y derechos de ejecución sin accesos cruzados ni privilegios públicos accidentales.
- [ ] Compatibilidad demostrada con APKs antiguas: lectura, inserción, edición, borrado lógico y triggers preexistentes; limitación de concurrencia legada documentada y mitigada con historial recuperable.
- [ ] UI de revisión y resolución de conflictos probada en WebApp.
- [ ] Pruebas de sincronización incremental, reloj desajustado, paginación y actualizaciones que llegan durante el pull.
- [ ] Revisión de seguridad sobre privilegio TRUNCATE; aprobación separada para corregirlo en remoto.
- [ ] CI, tests Flutter, análisis y compilación web satisfactorios en nuevo SHA.
- [ ] Confirmación explícita del propietario antes de merge, DDL remoto, deploy o APK.

## 5. Estado y límite de esta documentación

**Solo diseño y auditoría estática / inspección SQL de lectura.** Ninguna migración se aplicó, ningún test SQL de escritura o concurrencia se ejecutó y no se verificó el comportamiento con dos dispositivos reales. El PR sigue como borrador. El registro de resultados tiene que distinguir implementación, tests, integración y producción.

**Referencias:** `flutter_app/lib/data/supabase_sync_gateway.dart`, `flutter_app/lib/domain/sync.dart`, `flutter_app/lib/data/sync_queue.dart`, `flutter_app/docs/sync-multidevice-conflict-safety-20261110.md`, `AGENTS.md`, `docs/architecture.md`. Documentación Supabase RLS y PostgreSQL RLS (TRUNCATE fuera de las políticas).
