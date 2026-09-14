# Blueprint técnico — Fase 1 de TUKTUK Trabajos

**Estado:** diseño para revisión; no autoriza implementación, migraciones ni despliegue.

## Arquitectura y límites

La suite visible es **TUKTUK Control + TUKTUK Trabajos**. Marketplace es un
término interno. Control conserva Hive, respaldos, `sync_entities`, cola
incremental y funcionamiento offline. Trabajos es server-first: PWA cliente,
Flutter Trabajos y Vrixora consumen RPC/casos de uso; no escriben ledger ni
asignaciones directamente. Una outbox posterior al commit entrega notificaciones
mediante adaptadores. En el MVP, el cliente siempre puede seguir el estado desde la
PWA; web push puede añadirse si está disponible y WhatsApp automatizado no es requisito.

```text
PWA anónima ─┐                 ┌─ Vrixora: recargas, incidentes, configuración
Flutter ─────┼─ RPC/RLS ───────┼─ jobs/events, perfiles, vehículos relacionales
             │                 └─ wallet/ledger/reservas + outbox
Hive/sync_entities ── compatibilidad y proyección idempotente de vehículos ──┘
```

## Modelo relacional propuesto

`profiles` continúa canónico. `driver_profiles(profile_id PK)` guarda estado
(`incomplete`, `active`, `suspended`), requisitos, suspensión y
referencia a la foto controlada; WhatsApp permanece canónico en `profiles.phone`.

`vehicles(id text PK)` es la representación relacional queryable de Trabajos y usa
exactamente el ID textual existente de `VehicleProfile`. Guarda propietario,
categoría, propulsión, marca, modelo, año, matrícula/identificación, capacidades,
servicios y foto principal. Un puente idempotente desde `sync_entities`/la app
actualiza únicamente los campos legacy que corresponda y nunca borra campos de
Trabajos aunque sincronice un APK antiguo.

`driver_vehicle_assignments(profile_id, vehicle_id text)` guarda relación,
disponibilidad y ventanas operativas. Las capacidades físicas permanecen en
`vehicles`, evitando duplicarlas por conductor y conservando la posibilidad de
varios vehículos y futuros conductores compartidos.

`customers` usa `id` opaco, una sesión anónima o token aleatorio de alta entropía y PII privada; no se requiere fingerprinting del navegador.
`service_requests` conserva el formulario; `jobs` guarda estado, precio final
congelado, comisión en puntos básicos, expiración y ganador. `job_assignments`
registra ganador e intentos relevantes; `job_events` es append-only.

`marketplace_work_trials` es una tabla server-first, inmutable y única por
usuario/proyecto; guarda botón/idempotencia, vehículo inicial y exactamente 30 días.
`job_assignments` congela `billing_mode` como `trial_free` o `wallet_commission`.
`wallets` es una por conductor/usuario y moneda en el MVP (CUP inicialmente), con saldo total,
reservado y disponible cacheados/reconciliables. `wallet_transactions` es el
ledger inmutable firmado. `commission_reservations` tiene una reserva canónica
por job; `topups` representa solicitud, evidencia, confirmación y crédito único.
`idempotency_operations`, `audit_events`, `media_assets` y `outbox_events`
completan trazabilidad. Dinero: enteros de unidad menor; comisión: 1000 bp.

## Compatibilidad y activación

No se cambia `profiles.id`, `profiles.phone` se interpreta como WhatsApp y se
preserva. No se crea cuenta, licencia, teléfono genérico ni vehículo duplicado.
Los `VehicleProfile` y sus IDs textuales se mantienen; `vehicles.id text` reutiliza
exactamente esos IDs. El backfill/proyector es idempotente y solo actualiza campos
legacy autorizados, de forma que un cliente antiguo nunca pueda poner a null ni
sobrescribir categoría, propulsión, capacidades, servicios o fotos de Trabajos.
`sync_entities` queda
exclusivamente para entidades offline de Control: nunca jobs, wallet, reservas,
ledger ni asignaciones.

El entitlement se deriva, no se materializa como licencia falsa:
`control_allowed = control_trial_valid OR control_license_valid OR suite_active`.
`suite_active = perfil activo/no suspendido AND (trial_Trabajos_activo OR
depósito_inicial_confirmado)`. Requisitos completos + inicio explícito del trial
otorgan 30 días; después, topup confirmado permite nuevas aceptaciones. Requisitos MVP: perfil/nombre, WhatsApp, foto
conductor, vehículo con categoría, propulsión, marca, modelo, identificación si
aplica, capacidades, servicios y foto principal. No hay aprobación documental ni
botón administrativo adicional; Vrixora puede suspender después.

## Wallet, topups y aceptación

Primer topup: CUP, mínimo configurable por Vrixora con 500 CUP inicial; el
crédito entra íntegro al ledger. No es cuota y no hay mínimo permanente posterior.
Durante trial no se exige billetera, reserva ni saldo. Fuera de trial, aceptar exige
`available >= commission`, donde comisión es 10% del precio final.
Nunca hay saldo negativo ni se bloquea Control por falta de saldo.

`accept_job(job_id, vehicle_id, idempotency_key)` bloquea job, valida actor,
trial/depósito, vehículo/requisitos y compatibilidad. En `trial_free` crea
assignment/event sin billetera ni reserva; en `wallet_commission` bloquea wallet,
comprueba saldo y crea reserva. Ambos cambian a `accepted` en una transacción.
Restricciones únicas e idempotencia impiden segundo ganador/reserva. Antes de
`in_progress`, cancelar libera totalmente la reserva. Después, pasa a `incident`;
Vrixora resuelve con asientos compensatorios auditables. El conductor marca
`in_progress` y `completed`; al completar, `trial_free` no consulta billetera ni
reserva y nunca debita, incluso vencido. `wallet_commission` consume reserva +
débito una vez. Cancelar trial no crea ledger; cancelar wallet libera reserva.

`confirm_topup(topup_id, idempotency_key)` es exclusivo de capacidad Vrixora:
bloquea topup pendiente, crea crédito único, audita y recalcula activación. La
configuración remota aporta el mínimo inicial, no una constante Flutter.

## Privacidad, PWA, multimedia y notificaciones

La PWA pide nombre, WhatsApp, servicio y precio; no muestra registro, contraseña,
OTP ni código WhatsApp. Una sesión anónima/token opaco aislado habilita
seguir/cancelar solo sus solicitudes. El endpoint aplica rate limit por sesión/IP,
deduplicación, expiración, validación y CAPTCHA/alternativa configurable. El
WhatsApp no se considera identidad verificada en el MVP.

Antes de asignar, proyecciones y push excluyen contactos y PII. Después, una RPC
autorizada entrega al conductor WhatsApp del cliente y al cliente nombre, foto,
WhatsApp y vehículo permitido del conductor. Fotos son activos separados, privados
y versionados en almacenamiento controlado; Google solo inicializa la foto y se
copia/importa o reemplaza para no depender de su URL externa. Storage usa URLs
firmadas cortas emitidas tras autorización. La PWA ofrece seguimiento de estado
seguro como canal base; push/web push es adicional. Ninguna notificación lleva PII
innecesaria ni cambia estado.

## RLS, auditoría e idempotencia

RLS por propiedad/asignación/sesión opaca; PWA anónima sin insert directo general.
Lecturas sensibles se exponen por vistas/proyecciones security-invoker o RPC.
Funciones privilegiadas fijan `search_path`, validan `auth.uid()`/sesión/capacidad,
revocan `PUBLIC` y usan grants mínimos. Ledger, events y auditoría no admiten
edición/borrado frontend. Cada mutación lleva clave, hash de payload y respuesta
persistida; reutilizar una clave con otro payload falla. Auditoría registra actor,
rol, antes/después, motivo, servidor, correlación y resultado.

## Migración, rollback y Fase 2

Primero se inspecciona esquema canónico Vrixora y se ensaya en staging. Backfill
crea `vehicles`/extensiones desde profiles y `sync_entities`, con claves
idempotentes, validación de conteos e informe de excepciones; jamás cambia IDs ni
borra Hive/sync. El puente de compatibilidad tiene actualización por columnas para
que APK anteriores no puedan borrar campos exclusivos de Trabajos. Rollback deshabilita rutas/UI/RPC nuevas y conserva tablas,
ledger, topups y auditoría en lectura/operación segura; no borra datos financieros.

En Fase 2, un completado crea registro idempotente por `job_id`: precio final es
ingreso bruto y comisión gasto separado, con unicidad para impedir doble conteo.

## Riesgos y pruebas requeridas

Riesgos: modelo canónico desconocido, contención de aceptación, PII/abuso PWA,
recargas manuales, fotos privadas, estados ambiguos, frontera de 30 días e integración offline. Pruebas:
compatibilidad 1.0.8+10/Hive/restauración; RLS/IDOR; concurrencia de aceptación;
idempotencia de todas las RPC; ledger/reconciliación y compensaciones; topup antes/
después de ficha; privacidad antes/después de asignación; PWA abuso/duplicados;
push duplicado/perdido; inicio/reintento único de trial; aceptación gratis; fin de
trial sin comisión retroactiva; transición trial → wallet; offline; carga y `EXPLAIN`; actualización/rollback.
