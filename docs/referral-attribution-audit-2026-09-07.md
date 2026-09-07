# Auditoría de atribución automática de referidos

## Alcance y protección de datos

Base: `origin/main` (`49b41fe`). Rama: `codex/harden-referral-attribution`.
Se trabajó en `.worktrees/harden-referral-attribution` porque el checkout original
tenía cambios del usuario en otra rama. Esos cambios no se incorporaron ni editaron.
Se revisaron AGENTS.md, PRD, arquitectura, línea base, fases y migraciones.
No se editó la copia del PRD. El repositorio administrativo autoritativo localizado
es `D:\Codex\vrixora-admin-canvas`; allí están las migraciones originales de referidos.

Todas las consultas a Supabase fueron SELECT de definiciones, metadatos o agregados.
No se ejecutaron RPC de escritura, reparaciones, migraciones, db pull ni cambios de
historial. No se modificaron los dos casos reparados. La lectura final de la licencia
asociada a TUK-QC59 devolvió `2026-10-22T00:24:28.516906Z` (trial).
No hubo merge, despliegue de funciones, publicación de APK ni cambios en Cloudflare,
DNS, `/tuk`, `/tuktuk` o `/tuktuk/app/`.

## Causa comprobada y límites de la reconstrucción histórica

1. `PendingReferralClaimController` persistía `attemptedUserId` antes del RPC.
   Una excepción conservaba ese marcador y el código; intentos posteriores eran
   descartados incluso tras reiniciar. Solo el botón manual eliminaba el bloqueo.
2. `_installReferrerAttemptedThisSession` permanecía activo tras errores transitorios.
   `platformError` incluso se consideraba definitivo y se persistía como comprobado.
3. Reanudar no recuperaba Install Referrer ni procesaba el claim pendiente.
4. App Links escuchaba el stream pero no consultaba explícitamente el enlace inicial.
   La versión instalada del plugin puede entregar el inicial por stream: la ausencia
   de esa consulta, por sí sola, no demuestra que se perdiera el enlace.
5. Un fallo preparando el perfil antes del claim también podía impedir su procesamiento.

Estos defectos explican rutas reproducibles de pérdida de atribución automática.
El `referral_code NULL` de los dos casos es compatible con que el código nunca llegara
al claim. No hay trazas de esos teléfonos que permitan afirmar cuál de esos errores
ocurrió en cada instalación; no se presenta esa inferencia como causa histórica probada.

## Antes y después

| Situación | Antes | Después |
|---|---|---|
| RPC temporalmente inaccesible | Bloqueo persistente tras primer intento | Reintento a 5, 15, 30, 60, 120, 300 y luego 900 segundos |
| Reinicio | `attemptedUserId` impedía continuar | Recupera fecha de reintento y cuenta; marcador antiguo no significa éxito |
| Rechazo definitivo | Error genérico sin clasificación | Conserva código, cuenta y explicación; sin reintentos automáticos |
| Cuenta distinta | Pendiente protegido | Protección conservada y mensaje explicativo |
| Escritura local interrumpida | Código y cuenta en claves separadas | Estado del pendiente en un único valor Hive V2, con lectura de claves antiguas |
| Install Referrer temporal | Sin nueva consulta en la sesión | Espera progresiva y nueva conexión; límite nativo de 10 segundos |
| Arranque en frío | Dependencia del stream | Captura explícita antes de restaurar autenticación y escucha de eventos |
| Reanudación | No hacía claim | Procesa el pendiente respetando su fecha de reintento |
| Claim exitoso | Actualizaba referidos | Fuerza referidos, métricas y licencia |
| Compartir | Usaba el enlace remoto sin corregirlo | Garantiza `ref` con el código propio y conserva otros parámetros |

Las operaciones de captura/claim se serializan. Antes del RPC se vuelve a comprobar
la cuenta autenticada. Solo una confirmación no vacía del backend permite marcar
éxito y limpiar el pendiente. Se conserva la protección frente a enlaces repetidos.
La escritura de éxito precede a la limpieza: si se interrumpe, el siguiente arranque
limpia el pendiente confirmado sin repetir días. No cambian registros, vehículos,
respaldos, esquema de datos operativos ni sincronización incremental.

## Backend real revisado

Se recuperaron `claim_referral_code`, `get_my_referral_program`, `get_my_referrals`,
`app_private.p1_register_referral` y `app_private.p0d_apply_earned_rewards`.
También se revisaron resolver de códigos, índices, restricciones, triggers y RLS.

- Índices únicos parciales por `(project_id, referred_user_id)` protegen relaciones
  y recompensas reales. Cero duplicados en los agregados consultados.
- Autorreferidos bloqueados por función y CHECK. La función devuelve la relación
  existente para el mismo referente y rechaza cambios o usuarios ya pagados.
- Aplicación de días bloquea licencia y ledger, consume solo `earned`, excluye tests,
  licencias admin, estados suspendido/revocado y licencias sin vencimiento.
- Sin licencia cliente elegible retorna sin consumir `earned`. Cero aplicaciones
  inválidas por cuenta/proyecto o licencia administrativa en los agregados leídos.
- “Mis referidos” consulta las relaciones directamente y une el ledger; no necesita
  una escritura adicional para mostrar una relación nueva.
- RLS está activo. Las tablas de relaciones y ledger no tienen políticas directas;
  el cliente usa RPC con `auth.uid()`. Flutter no usa `service_role`.

No se creó ninguna migración. El snapshot SQL dentro de `supabase/tests/fixtures`
es exclusivamente una fixture, con separadores de sentencias añadidos a la salida
de `pg_get_functiondef`; no debe aplicarse a producción ni tomarse como historial.
Las pruebas usan PostgreSQL en memoria y un esquema mínimo con datos ficticios.
No sustituyen pruebas de todas las políticas del esquema completo ni de concurrencia
entre conexiones PostgreSQL independientes.

## Redirección y App Links

Se incorporó el código fuente de `referral-redirect` v1, recuperado de producción,
sin cambios funcionales. Desplegada con `verify_jwt=false`; no se volvió a desplegar.
`share_base_url` apunta a esa función. Las pruebas ejecutan su handler sin abrir servidor.
Comprueban Android/web, fallback Intent, minúsculas, alias, URL encoding, parámetros
adicionales y entradas inválidas/ausentes. Los 52 alias históricos de producción
tienen como máximo 16 caracteres y ninguno incumple el patrón del redirect.

Google Play recibe `referrer=ref%3DTUK-QC59`, equivalente a `ref=TUK-QC59`.
La función valida sintaxis, no existencia del código: el RPC decide esta última.
La versión desplegada es suficiente para transportar los códigos actualmente existentes.

`https://www.vrixora.com/.well-known/assetlinks.json` responde y declara el paquete
`com.alejandrocruz.tuktukcontrol`, igual al manifest y Gradle. Huella publicada:
`D6:5E:51:B2:F9:FA:31:C6:A8:A6:0D:08:3E:63:EE:43:90:2E:85:1F:6D:4B:7F:08:C4:DC:39:39:6C:DD:CC:27`.
Falta contrastarla con el certificado de **firma de aplicación de Google Play**;
el certificado de subida y el de debug no sirven para esa comparación.
No había teléfono conectado en `adb devices`.

## Actualización del teléfono del referente y notificaciones

Las tablas revisadas, incluida `licenses`, no figuran en la publicación Realtime.
El cliente refresca al reanudar (intervalo general de 5 minutos), cada 15 minutos en
primer plano y tras un claim local; conserva además el callback de licencia existente.
No se promete actualización instantánea entre dos teléfonos con la publicación actual.
Habilitar Realtime requeriría revisar el repositorio administrativo, permisos y alcance.

No se encontró productor SQL que combinara referidos con `notification_outbox` ni
un tipo de notificación de referido en los datos consultados. Añadirlo requiere
decisión de producto, preferencia del usuario, tipo admitido por el worker y una
clave única por recompensa/evento. Recomendación separada para el repositorio
administrativo; no se implementó en esta corrección.

## Validación

- `dart format`: ejecutado sobre los archivos Dart de la corrección.
- `flutter analyze --no-pub`: sin incidencias en la última ejecución.
- Suite Flutter: 126 aprobadas antes de añadir la integración; integración real
  de RecordStore aprobada por separado. Suite final completa en ejecución al redactar.
- Redirect: 11 pruebas Node aprobadas.
- Funciones SQL recuperadas: 7 pruebas PostgreSQL en memoria aprobadas.
- Worker existente: 17 pruebas Deno aprobadas.
- Compilación Android debug: en ejecución al redactar (NDK instalado).
- Prueba Python PostgreSQL existente: rechazada localmente por revisión automática
  porque elimina `public` y no había una base desechable verificada. El nuevo CI usa
  un servicio PostgreSQL exclusivo del job con destino explícito y datos ficticios.

El CI nuevo ejecuta análisis, suite Flutter, compilación debug, pruebas SQL/redirect y
la prueba Python existente en su servicio desechable. La configuración Firebase de
`test/fixtures/google-services.debug.json` es ficticia y sirve únicamente para compilar;
no valida Google Sign-In/FCM en dispositivo ni se debe usar en una publicación.
La firma release sigue requiriendo sus propiedades; compilar debug ya no exige tenerlas.

## Revisión de impacto y pendientes antes del merge

- Sin dependencias nuevas de la aplicación. PGlite es una dependencia de pruebas,
  fijada y con lockfile. La cola ocupa un estado local pequeño por instalación.
- Reintentos acotados en frecuencia, sin peticiones simultáneas de claim y sin
  reintentos rápidos permanentes ante rechazos conocidos. Los timers se cancelan
  al destruir el store. No se modifica la cola incremental de datos operativos.
- Se conservan datos Hive previos; V2 lee el pendiente anterior. El tombstone evita
  que reaparezca un código antiguo después de limpiarlo. No se elimina historial.
- Pendiente: prueba física instalada/no instalada/reinstalación desde Play, incluida
  restauración automática de Android si está habilitada. Una simulación de canal y
  persistencia no demuestra el comportamiento de Google Play o Android Auto Backup.
- Pendiente: certificado de firma Play y comprobaciones CI/compilación finales.
- Hace falta una nueva versión Android para distribuir esta corrección. No se
  incrementó versión ni se publicó una APK/AAB en esta tarea.

## Prueba física final (entorno/cuentas de prueba autorizados)

1. Confirmar el certificado en Play Console → Integridad de la aplicación y
   compararlo con la huella anterior. Usar la versión corregida en un canal de prueba
   de Play; publicar en ese canal requiere autorización separada y no se hizo aquí.
2. En un teléfono sin la app, abrir el enlace compartido de una cuenta de prueba,
   pulsar “Instalar en Google Play”, instalar desde esa ficha y abrir desde Play.
   Iniciar sesión con una cuenta invitada nueva. Verificar una sola relación,
   recompensa y extensión de 15 días, según la campaña vigente.
3. En el teléfono del referente, reanudar y comprobar “Mis referidos”, métricas y
   licencia. Considerar los intervalos anteriores; no asumir Realtime activo.
4. Con app instalada, abrir el mismo enlace con la app cerrada y luego abierta.
   Repetir el enlace: no deben crearse otra relación/recompensa ni sumarse más días.
5. Con otra cuenta de prueba nueva, cortar red después de capturar la invitación y
   durante el claim. Recuperar red: debe reintentarse solo. Repetir cerrando la app
   tras el error; abrir/reanudar y comprobar recuperación del pendiente.
6. Antes de que termine el pendiente, cambiar a otra cuenta: debe mostrarse el aviso
   y no atribuirlo a esa cuenta. Volver a la cuenta original y completar el flujo.
7. Probar código propio, inexistente y cuenta ya atribuida: conservar explicación,
   sin bucle de peticiones. Probar cuenta referente admin sin licencia cliente:
   recompensa `earned`, sin cambiar la licencia administrativa.
8. Reinstalar únicamente en teléfono/perfil de prueba con datos respaldados; repetir
   instalación desde el enlace de Play, y comprobar idempotencia con cuenta ya
   atribuida. Repetir con/sin restauración de Android Auto Backup.
9. No usar ni reparar de nuevo las cuentas o registros reales mencionados por el owner.
