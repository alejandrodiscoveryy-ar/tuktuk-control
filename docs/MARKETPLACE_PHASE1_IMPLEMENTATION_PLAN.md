# Plan de implementación — Fase 1 TUKTUK Trabajos

**Precondición:** aprobar el blueprint. Ningún bloque autoriza despliegue remoto.

| Bloque | Objetivo y sistemas probables | Dependencias y pruebas | Terminado / rollback / regresión |
|---|---|---|---|
| 1. Schema foundations | Tablas, catálogos, índices, checks y auditoría: Vrixora/Supabase staging. | Blueprint aprobado; pruebas de esquema e índices. | Migraciones reversibles antes de datos; rollback deshabilita objetos nuevos. Riesgo: nombres canónicos. |
| 2. Compatibility/migration | Extensiones `profiles`, `vehicles.id text` relacional y relación conductor–vehículo; puente idempotente desde `VehicleProfile`/`sync_entities`. | Inventario real 1.0.8+10; pruebas de backfill repetido, Hive/restauración y APK antiguo que sincroniza después del backfill. | Sin ID cambiado ni sync destruido; el puente legacy nunca borra campos de Trabajos; rollback corta proyector. Riesgo: duplicado/desasociación. |
| 3. Entitlement | Suite reconoce trial Trabajos activo o depósito confirmado; trial inmutable una vez por usuario/proyecto. | Bloques 1–2; pruebas de 30 días, idempotencia, licencia/suite/suspensión. | No licencia Marketplace ni bloqueo Control; rollback apaga entitlement suite. |
| 4. Wallet/topups | Wallet por conductor/usuario en CUP, ledger, topups y configuración Vrixora (500 CUP por defecto). | 1, 3; crédito único, depósito permitido durante trial y saldo no negativo. | Depósito no es requisito durante trial; rollback conserva historia. |
| 5. Jobs/state machine | Requests, jobs, events, estados e incidente. | 1–3; pruebas de transición y roles. | Eventos append-only; rollback cierra publicación nueva. Riesgo: estados inválidos. |
| 6. Atomic acceptance | RPC acepta `trial_free` sin wallet o `wallet_commission` con lock financiero estable, reserva 10 % y liquidación por modo congelado. | 4–5; carreras, reintentos, cancelación e incidente. | Cero doble reserva/cargo; rollback bloquea aceptación. |
| 7. Privacy/RLS/RPC | Proyecciones sin PII, contacto post-asignación, grants, rate limits y estado derivado del trial. | 2, 5–6; pruebas RLS/IDOR/PWA abuso. | Ninguna PII previa; rollback revoca RPC/vistas. |
| 8. Vrixora | Recargas, configuración, supervisión, incidentes y auditoría. | 3–7; RBAC, confirmación y compensación. | Vrixora acredita manualmente; no aprueba segundo botón de activación. |
| 9. Flutter Trabajos | Onboarding, “Comenzar 30 días gratis”, días restantes y solicitud de acreditar saldo al vencer. | 2–7; UI, offline y actualización. | Control intacto offline; rollback feature flag/UI. |
| 10. Customer PWA | Flujo anónimo: nombre, WhatsApp, servicio, precio y seguimiento seguro desde la PWA. | 5,7; pruebas sesión/token opaco, spam, duplicados, WhatsApp no verificado y privacidad. | Sin login/OTP visible ni segundo teléfono; rollback despublica ruta. |
| 11. Notificaciones | Outbox para conductores y adaptadores; seguimiento PWA como canal base del cliente, web push opcional. | 5–7; pruebas de pérdida/duplicado y ausencia de PII. | Ninguna notificación muta estado; WhatsApp automatizado no es requisito MVP; rollback pausa consumidor. |
| 12. Tests | Suites unitarias, RPC/RLS, concurrencia de inicio/liquidación wallet, frontera día 30, congelación de `billing_mode` y no comisión retroactiva. | Todos los anteriores. | Cobertura de invariantes y `git diff --check`; rollback no aplica. |
| 13. Staging/pilot | Datos sintéticos, reconciliación y piloto de transición trial → wallet. | 1–12; pruebas E2E y runbooks. | Métricas/alertas y aprobación owner; rollback feature flags. |
| 14. Production rollout | Publicación gradual aprobada y monitoreada. | Pilot aprobado, backup/runbook. | Sin despliegue en esta tarea; rollback operativo preserva ledger/datos. |

Cada bloque requiere revisión de rendimiento, seguridad, escalabilidad, mantenibilidad,
compatibilidad offline y sincronización incremental antes de avanzar.
