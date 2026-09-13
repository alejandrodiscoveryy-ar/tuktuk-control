# PRD — TUKTUK Marketplace V1 / TUKTUK 2.0

**Producto:** Ecosistema TUKTUK Marketplace

**Componentes:** TUKTUK Control Conductor, TUKTUK Cliente y Vrixora Admin

**Versión del documento:** 1.0

**Fecha:** 13 de septiembre de 2026

**Estado:** Fase 0 — diseño y arquitectura; no implementado

**Rama de trabajo:** `feature/marketplace-v1`

**Base estable:** `0efed3c` — versión 1.0.8+10

---

## 1. Propósito y relación con el producto actual

Este documento formaliza la evolución de TUKTUK Control hacia TUKTUK 2.0,
un marketplace de servicios prestados con triciclos, sin eliminar, sustituir
ni degradar ninguna capacidad actual de control económico y operativo.

El Marketplace es una ampliación del ecosistema, no una reescritura de la
aplicación existente. Los registros diarios, ingresos, gastos, kilometraje,
batería, mantenimiento, estadísticas, Hive, respaldo en Google Drive,
sincronización incremental, Google Sign-In, licencias y soporte continúan con
sus contratos actuales salvo una migración posterior, explícita y compatible.

El PRD maestro vigente enumera Marketplace como fuera de la primera versión de
TUKTUK Control. Este PRD no contradice esa decisión: inicia una línea de producto
posterior sobre la base estable 1.0.8+10. La incorporación de esta evolución a la
fuente oficial `vrixora-admin-canvas/docs/PRD_MASTER.md` requiere el proceso de
gobernanza y aprobación del owner; esa fuente no se modifica en esta fase.

## 2. Objetivos

- Conectar solicitudes reales de pasajeros, carga, mensajería y turismo con
  conductores y vehículos compatibles.
- Permitir que un cliente solicite el servicio desde una Web/PWA, sin instalar
  una APK independiente.
- Asignar cada trabajo de forma atómica, auditable y segura al primer conductor
  elegible que lo confirme.
- Proteger los datos de contacto del cliente hasta que exista una asignación.
- Cobrar una comisión del 10 % mediante una billetera prepago basada en un libro
  mayor trazable y operaciones transaccionales de servidor.
- Mantener la experiencia actual de TUKTUK Control y sus funciones esenciales
  completamente disponibles sin conexión.
- Soportar inicialmente entre 500 y 1.000 usuarios activos y permitir crecer por
  encima de ese volumen sin sustituir la arquitectura principal.

## 3. Principios obligatorios

1. El servidor es la autoridad para asignaciones, transiciones de estado,
   compatibilidad, comisiones, reservas, liquidaciones y anulaciones.
2. Ningún frontend usa `service_role`, decide quién ganó un trabajo ni escribe
   directamente saldos financieros.
3. El libro mayor y los eventos de trabajo son trazables; no se corrigen
   eliminando o sobrescribiendo historia, sino con asientos o eventos
   compensatorios.
4. Toda mutación crítica admite reintentos idempotentes.
5. Los datos de contacto se exponen por capacidad y estado, no por conocer un ID.
6. La licencia de TUKTUK Control y la billetera del Marketplace son conceptos
   separados: una controla acceso al producto y la otra cubre comisiones.
7. Marketplace requiere conexión para publicar, aceptar y cambiar estados. Una
   caché local nunca autoriza una operación crítica.
8. Las listas de trabajos y eventos usan paginación por cursor, filtros e índices;
   no descargan históricos completos ni generan una fila permanente por cada
   conductor potencial.
9. Se reutilizan identidades y datos existentes cuando sean canónicos; no se
   crean copias de perfiles, vehículos, registros ni licencias sin una razón y
   una estrategia de migración aprobadas.

## 4. Componentes del sistema

### 4.1. TUKTUK Control Conductor

Es la aplicación actual ampliada para propietarios y conductores. Conserva todos
sus módulos y añade una sección principal **Trabajos**.

Navegación prevista:

1. Inicio.
2. Registros.
3. Trabajos.
4. Estadísticas.
5. Más.

La sección **Tienda** pasa a **Más → Tienda**; no se elimina ni pierde funciones.

**Trabajos** contiene:

- **Disponibles:** oportunidades publicadas compatibles con el conductor, su
  vehículo, disponibilidad y reglas de acceso.
- **Activos / Mis trabajos:** trabajo aceptado y flujo operativo actual.
- **Programados:** trabajos aceptados cuya fecha/hora es futura.
- **Historial:** trabajos completados, liquidados, cancelados, expirados o con
  incidencia, mediante paginación por cursor.

La aplicación debe distinguir visualmente funciones locales y funciones que
requieren internet. Sin conexión, el conductor conserva la gestión actual, ve
el último estado cacheado de Marketplace como no actualizado y no puede aceptar
ni cambiar el estado de un trabajo.

### 4.2. TUKTUK Cliente

Web/PWA móvil y de escritorio para personas y empresas. Permite solicitar y
seguir servicios sin APK. La PWA consume únicamente endpoints o RPC seguros y
nunca recibe credenciales privilegiadas.

En el MVP permite:

- identificar al solicitante conforme al mecanismo de acceso que se cierre;
- cotizar y crear una solicitud;
- editar el precio recomendado antes de publicar;
- consultar estado y datos del conductor asignado;
- cancelar conforme a las reglas vigentes;
- abrir llamada o WhatsApp después de la asignación.

### 4.3. Vrixora Admin

Centro de control del Marketplace para personal autorizado. Amplía el producto
administrativo, no la aplicación de conductores. Debe administrar:

- conductores y clientes;
- trabajos, asignaciones y eventos;
- billeteras, recargas, reservas y comisiones;
- incidencias, cancelaciones y disputas;
- configuración de servicios, precios, advertencias y operación;
- auditoría, conciliación y métricas.

La autorización administrativa se aplica en backend. Ocultar una opción de la
interfaz no constituye un control de seguridad.

## 5. Actores y responsabilidades

| Actor | Responsabilidad principal | Restricciones relevantes |
|---|---|---|
| Cliente | Crear, publicar, seguir y cancelar sus solicitudes | No ve candidatos ni datos de otros clientes |
| Conductor | Configurar capacidades, disponibilidad y ejecutar trabajos | Solo ve oportunidades compatibles; no ve contacto antes de aceptar |
| Propietario de vehículo | Mantener vehículos y autorizar conductores cuando corresponda | No obtiene permisos de plataforma |
| Operaciones | Supervisar trabajos e incidencias | No altera el ledger sin una operación autorizada |
| Finanzas/cobros | Confirmar recargas y conciliar comisiones | No modifica historia financiera en sitio |
| Soporte | Atender clientes y conductores según permisos | Acceso mínimo a PII y acciones auditadas |
| Platform admin/owner | Configuración y excepciones controladas | Acciones sensibles requieren motivo y auditoría |

Los roles se almacenan en datos controlados por servidor o en `app_metadata`.
Nunca se toman decisiones de autorización con `user_metadata`, editable por el
usuario. Los permisos deben ser capacidades específicas, no un único indicador
global de “administrador”.

## 6. Tipos iniciales de servicio

- Pasajeros.
- Carga.
- Mensajería / Courier.
- Turismo.

Cada tipo tiene un identificador estable, nombre visible, estado activo, versión
de reglas de precio y requisitos de compatibilidad. Desactivar un tipo impide
nuevas publicaciones, pero no invalida trabajos históricos ni activos.

## 7. Solicitud del cliente

### 7.1. Campos comunes

- nombre;
- teléfono;
- WhatsApp;
- origen;
- destino;
- fecha y hora solicitadas;
- tipo de servicio;
- observaciones;
- paradas adicionales, cuando correspondan;
- precio recomendado y precio final propuesto;
- moneda.

Teléfono y WhatsApp se normalizan a formato internacional. Debe definirse cuál
es obligatorio; no se debe suponer que ambos números son iguales. Origen,
destino y observaciones se limitan y validan para evitar contenido abusivo.

### 7.2. Carga

- tipo de carga;
- peso aproximado;
- dimensiones o volumen;
- cantidad de bultos;
- necesidad de ayuda para carga;
- necesidad de ayuda para descarga;
- fotografía opcional.

La fotografía se almacena en un contenedor privado, con tipo, tamaño y acceso
temporal controlados. No se incorpora como datos binarios dentro de la tabla.

### 7.3. Pasajeros

- cantidad de pasajeros;
- equipaje;
- observaciones.

### 7.4. Validación y publicación

La solicitud comienza como **Solicitado** mientras el cliente revisa los datos y
el precio. Solo pasa a **Publicado** mediante una operación de servidor que:

1. valida campos y disponibilidad del tipo de servicio;
2. calcula o verifica el precio recomendado con su versión de reglas;
3. registra el precio final elegido por el cliente;
4. almacena si se mostró y aceptó una advertencia por precio bajo;
5. crea el trabajo y su primer evento de forma atómica;
6. inicia la entrega de notificaciones a conductores elegibles.

## 8. Perfil operativo del conductor y del vehículo

El dominio debe admitir varios vehículos por usuario y varios conductores por
organización, aunque la interfaz inicial conserve un vehículo activo.

Debe poder definir:

- tipos de servicio habilitados;
- capacidad de pasajeros;
- capacidad máxima de carga;
- volumen o dimensiones útiles;
- tipo de carrocería;
- disponibilidad actual y ventanas futuras;
- conductor y vehículo activos para recibir oportunidades;
- en una fase posterior, radio, zona o corredor de trabajo.

Las capacidades físicas pertenecen al vehículo. La disponibilidad, el conductor
activo y sus ventanas pertenecen a la relación conductor–vehículo. Las
habilitaciones que requieren verificación administrativa deben distinguir valor
declarado, valor verificado, estado y fecha de verificación.

Un conductor es elegible solo si, en el momento de consultar y nuevamente al
aceptar:

- su identidad y relación con el vehículo están activas;
- su licencia permite usar Marketplace según la política vigente;
- conductor y vehículo están disponibles;
- el tipo de servicio está habilitado;
- todas las capacidades requeridas satisfacen la solicitud;
- no existe un trabajo activo incompatible;
- cumple la política de billetera aplicable;
- no está suspendido ni bloqueado por riesgo u operación.

La validación definitiva ocurre dentro de la transacción de aceptación. La lista
vista por el conductor es informativa y puede quedar obsoleta.

## 9. Precio

### 9.1. Precio recomendado

La plataforma calcula una recomendación versionada a partir de:

- precio base;
- distancia estimada;
- tipo de servicio;
- cantidad de pasajeros o características de la carga;
- peso y volumen;
- ayuda para carga y descarga;
- cantidad de paradas;
- horario y urgencia.

El resultado conserva un desglose inmutable y la versión de reglas utilizada.
Esto permite explicar el precio y reproducir auditorías aunque la configuración
cambie después.

En el MVP puede utilizarse una distancia introducida o calculada por un proveedor
externo que se seleccione posteriormente; no se exige GPS propio. Si no existe
una distancia confiable, la interfaz debe indicarlo y aplicar una regla explícita,
no fingir precisión.

### 9.2. Precio final del cliente

El cliente puede aceptar, subir o bajar la recomendación antes de publicar. El
precio final se congela al publicar y es el que ven los conductores.

Si el precio cae por debajo de un umbral configurable respecto de la recomendación,
se muestra una advertencia y se registra su aceptación. La advertencia no impide
publicar mientras el precio sea positivo y cumpla el mínimo técnico/configurado.
No hay pujas ni contraofertas de conductores en el MVP.

Todos los importes se representan de forma exacta mediante unidades monetarias
menores enteras y código de moneda; nunca con punto flotante. El porcentaje de
comisión se almacena en puntos básicos (`1000` = 10 %) y la regla de redondeo se
versiona junto con el precio.

## 10. Distribución de oportunidades y notificaciones

Los conductores compatibles reciben una oportunidad con:

- tipo de servicio;
- origen y destino con el nivel de precisión permitido;
- fecha/hora;
- requisitos relevantes;
- precio final;
- expiración de la oportunidad;
- ausencia explícita de teléfono y WhatsApp del cliente.

La elegibilidad se calcula en servidor con filtros indexables. Para no multiplicar
el almacenamiento por cada combinación trabajo–conductor, no se requiere crear
una asignación permanente para cada notificación. Los intentos de entrega pueden
registrarse en una infraestructura de notificaciones con retención limitada; la
tabla `job_assignments` conserva candidatos que iniciaron una aceptación, el
ganador y cambios de asignación con valor operativo o de auditoría.

Las notificaciones son una ayuda de descubrimiento, no una garantía. Al abrir
**Disponibles**, la aplicación consulta el estado vigente. Una notificación
duplicada o tardía no permite aceptar dos veces un trabajo.

## 11. Asignación atómica

El primer conductor elegible que confirma obtiene el trabajo. La aceptación se
implementa como una única operación transaccional de servidor, conceptualmente
`accept_job(job_id, vehicle_id, idempotency_key)`.

Dentro de una transacción corta, la operación debe:

1. autenticar al actor y validar que controla la relación conductor–vehículo;
2. bloquear o actualizar condicionalmente el trabajo solo si continúa publicado,
   no expiró y no tiene ganador;
3. reevaluar compatibilidad, disponibilidad, licencia y bloqueos;
4. calcular la comisión esperada a partir del precio final congelado;
5. bloquear la billetera en un orden consistente y comprobar saldo disponible
   cuando la modalidad prepago esté activa;
6. crear exactamente una reserva de comisión para el trabajo;
7. crear la asignación ganadora;
8. actualizar trabajo, disponibilidad y estado a **Aceptado**;
9. añadir el evento auditable;
10. devolver el mismo resultado ante un reintento con la misma clave.

Una restricción única impide más de una asignación ganadora por trabajo y otra
impide más de una reserva de comisión activa por trabajo. El cambio condicional
de estado y esas restricciones son defensas complementarias. Las llamadas a
WhatsApp, push u otros servicios externos se realizan después del commit mediante
una cola/outbox; nunca mientras se mantienen bloqueos.

### 11.1. Decisión sobre “Reservado” y “Aceptado”

Para el MVP se **simplifican como un único estado de negocio: Aceptado**.
Mantener un estado durable **Reservado** entre pulsar y confirmar abre problemas
de expiración, trabajos bloqueados, dos temporizadores y una experiencia confusa,
sin aportar valor cuando la aceptación completa cabe en una sola transacción.

“Reservado” se conserva únicamente como concepto técnico futuro para una cesión
temporal con vencimiento si más adelante se incorpora confirmación en dos pasos,
documentación previa o pago del cliente. No aparece en la interfaz ni en la
máquina de estados del MVP. Esta decisión no afecta al **saldo reservado** de la
billetera, que es un concepto financiero distinto y sí existe en el MVP.

## 12. Máquina de estados

### 12.1. Estados canónicos del MVP

| Estado | Significado | Transiciones principales |
|---|---|---|
| Solicitado | Borrador validable aún no visible a conductores | Publicado, Cancelado por cliente |
| Publicado | Disponible para conductores elegibles | Aceptado, Cancelado por cliente, Expirado |
| Aceptado | Conductor asignado y comisión reservada | En camino, Cancelado por cliente, Cancelado por conductor, Incidente |
| En camino | Conductor se dirige al origen | Recogida, Cancelado, Incidente |
| Recogida | Llegó o inició la recogida/abordaje | En curso, Cancelado, Incidente |
| En curso | Servicio en ejecución | Completado, Incidente |
| Completado | Ejecución confirmada; pendiente de cierre financiero | Liquidado, Incidente |
| Liquidado | Comisión asentada y trabajo cerrado | Incidente administrativo excepcional |
| Cancelado por cliente | Terminal operativo | — |
| Cancelado por conductor | Terminal operativo | — |
| Expirado | Nadie aceptó dentro del plazo | — |
| Incidente | Flujo normal suspendido para revisión | Reanudación autorizada, cancelación o liquidación |

Cada transición define actor permitido, estado de origen, datos requeridos,
efecto financiero, plazo e idempotency key. El cliente no envía un estado final
arbitrario: solicita una acción y el servidor decide la transición válida.

### 12.2. Eventos y tiempo

`jobs.status` representa el estado actual para consultas eficientes.
`job_events` es el historial append-only y contiene estado anterior, nuevo estado,
actor, marca de tiempo del servidor, motivo, metadatos mínimos e identificador de
operación. El reloj del cliente puede registrarse como dato diagnóstico, pero no
ordena eventos ni determina expiraciones.

## 13. Contacto y privacidad

Antes de aceptar, ningún conductor recibe teléfono, WhatsApp ni otros datos que
permitan identificar directamente al cliente. RLS y la forma de las respuestas
del servidor deben impedir obtenerlos incluso manipulando solicitudes.

Después de la asignación:

- el conductor asignado puede obtener teléfono y WhatsApp del cliente;
- el cliente obtiene nombre operativo, contacto y datos autorizados del conductor
  y vehículo;
- ambos pueden usar `tel:` y un enlace de WhatsApp con número internacional y
  texto codificado de forma segura.

El acceso al contacto se entrega mediante una proyección/RPC específica que
verifica en servidor la asignación vigente. Los datos sensibles no deben formar
parte de la fila pública usada para listar oportunidades ni del payload push.

No se implementa chat interno en el MVP. Los accesos administrativos a PII se
limitan por rol, se auditan y siguen una política de retención por definir.

## 14. Modelo económico y billetera

### 14.1. Separación entre licencia y billetera

- Se mantienen los 30 días de licencia/prueba de entrada y la regla de una sola
  licencia por usuario y aplicación.
- La primera compra reemplaza la prueba; una renovación activa conserva días y
  una licencia vencida reinicia desde la confirmación, como define el PRD maestro.
- La licencia habilita el uso del producto. La billetera financia comisiones del
  Marketplace; renovar una licencia no altera el saldo y recargar no extiende la
  licencia.

El ledger, la reserva y la liquidación son necesarios desde el MVP para cobrar el
10 %. La activación estricta del requisito de saldo prepago puede desplegarse con
configuración gradual, pero no se permite una implementación de comisión basada
solo en un número editable. Antes de operar con dinero real deben cerrarse la
política de saldo inicial/promocional, recargas y conducta ante saldo insuficiente.

### 14.2. Saldos

- **Saldo total:** suma neta de transacciones contabilizadas del ledger.
- **Saldo reservado:** suma de reservas abiertas asociadas a trabajos aceptados.
- **Saldo disponible:** saldo total menos saldo reservado.

Los tres se muestran juntos y con moneda. Los saldos cacheados pueden mantenerse
para rendimiento, pero deben poder reconciliarse con el ledger y las reservas.

### 14.3. Ciclo de la comisión

1. Al aceptar, se reserva el 10 % esperado del precio final.
2. Al completar y confirmar el cierre, la reserva permanece identificada hasta
   la liquidación.
3. Al liquidar, se crea un débito inmutable en `wallet_transactions` y la reserva
   cambia a consumida dentro de la misma transacción.
4. En una cancelación válida, la reserva se libera. Si ya existió un asiento, se
   crea un asiento compensatorio; no se edita ni elimina el original.
5. Un incidente congela el efecto pendiente hasta una resolución autorizada.

`job_id` y el tipo de operación tienen restricciones únicas para impedir doble
reserva o doble comisión. Cada recarga y acción financiera usa una clave de
idempotencia, referencia externa única cuando corresponda, actor, motivo y evento
de auditoría.

## 15. Modelo de datos conceptual

Este modelo no crea tablas en esta fase. Los nombres son conceptuales y deberán
validarse contra el esquema canónico de Vrixora antes de una migración.

### 15.1. Entidades propuestas

| Entidad | Propósito y campos conceptuales principales | Relaciones/garantías |
|---|---|---|
| `customers` | Identidad de solicitante, nombre y contactos normalizados; vínculo opcional a Auth/empresa | No duplica `profiles`; PII privada; deduplicación controlada |
| `service_requests` | Entrada del cliente, origen/destino, horario, servicio, detalles de carga/pasajeros, observaciones, foto privada | Pertenece a customer; conserva snapshot solicitado |
| `jobs` | Trabajo publicable/operable, estado actual, precio recomendado/final, moneda, versión de precio, expiración y ganador | Uno por solicitud publicada; actualización condicional de estado |
| `job_assignments` | Historial de intentos relevantes, ganador, conductor, vehículo, aceptación y finalización | Índice único para un ganador por job |
| `job_events` | Historial append-only de transiciones y acciones | Orden por `(job_id, created_at, id)`; no editable por clientes |
| `driver_availability` | Relación conductor–vehículo, disponible/ocupado, ventanas y futura zona | Un estado actual por relación; solapes controlados |
| `wallets` | Billetera por conductor/propietario y moneda, saldos cacheados/revisión | Única por owner y moneda; no editable desde frontend |
| `wallet_transactions` | Ledger inmutable: recarga, comisión, ajuste, reverso; importe firmado y referencia | Claves únicas de idempotencia y origen; nunca hard delete |
| `commission_reservations` | Retención por job, importe, estado abierta/consumida/liberada y expiración | Una reserva canónica por job y wallet |
| `topups` | Solicitud, validación y conciliación de recargas | Confirmación crea exactamente un crédito de ledger |
| `ratings` | Calificación posterior y relación job–autor–destinatario | Fase 3; una por dirección y job |
| `disputes` | Incidencia/disputa, estado, responsable, resolución y referencias | Fase 3 o soporte mínimo de incidentes en MVP |

Tablas de configuración versionada —tipos de servicio, reglas de precio, umbrales,
reglas de cancelación y capacidades— pueden añadirse al esquema compartido. Sus
cambios no deben reescribir snapshots de trabajos existentes.

### 15.2. Reutilización del sistema actual

#### `profiles`

Se reutiliza como perfil canónico de usuarios autenticados. En este repositorio ya
existe `public.profiles` con el mismo UUID de `auth.users`, email, nombre visible,
avatar y RLS por propietario. Debe ampliarse solo con datos generales que apliquen
a cualquier rol. Capacidades de vehículo, estado de conducción, saldo y PII
específica de clientes pertenecen a entidades separadas.

Un mismo usuario autenticado puede ejercer más de un rol; no se crea un perfil
duplicado por ser conductor y cliente. Un `customer` puede enlazar a `profiles.id`
cuando exista autenticación. El acceso sin cuenta y la deduplicación por teléfono
quedan pendientes de decisión.

#### `vehicles`

Se preservan los IDs actuales. La app ya modela múltiples `VehicleProfile`, aunque
la interfaz usa un vehículo activo, y actualmente sincroniza vehículos como
payloads `vehicle` en `sync_entities`; este repositorio todavía no define una
tabla relacional `vehicles` en sus migraciones.

Antes del Marketplace debe identificarse la tabla canónica compartida o diseñarse
una migración idempotente desde `sync_entities`, sin copiar el mismo vehículo con
un ID nuevo. El perfil canónico se amplía o relaciona con capacidades físicas y
servicios. No se almacenan esas capacidades como una copia dentro de cada job;
solo se conserva un snapshot mínimo de compatibilidad cuando haga falta auditar.

#### `records`

Los `DailyRecord` actuales —ingresos, gastos, odómetro, batería y metadatos de
sincronización— continúan siendo datos operativos offline-first. No se usan como
cola ni estado del Marketplace. En Fase 2, un trabajo completado puede originar
un registro mediante un vínculo estable `source_type = marketplace_job` y
`source_id = job_id`, protegido por unicidad para impedir duplicados.

La integración debe pasar por el contrato/repositorio de registros y la cola
incremental actual, conservar IDs y permitir reintentos. No debe sumar una
comisión como ingreso: ingreso bruto y comisión/gasto se representan de acuerdo
con la decisión contable que se cierre y sin contar dos veces el mismo importe.

#### `licenses`

Se reutiliza la misma licencia por usuario y aplicación. No se crea una “licencia
Marketplace” duplicada. La prueba de 30 días y las reglas de compra/renovación se
mantienen. El servidor valida la licencia al aceptar cuando esa sea la política
de acceso; el frontend solo muestra el resultado. La tabla y RPC actuales son
administradas por Vrixora Admin y deben verificarse en su esquema canónico antes
de añadir relaciones.

### 15.3. Tipos, claves e índices

- Identificadores expuestos o compartidos entre clientes son UUID/IDs opacos y
  estables; se preservan los IDs de entidades existentes.
- Fechas usan `timestamptz` y tiempo del servidor.
- Dinero usa unidad menor entera más moneda; porcentajes usan puntos básicos.
- Campos consultados y restricciones son columnas tipadas; JSON se reserva para
  snapshots versionados o detalles variables, no para claves de relación.
- Toda clave foránea en rutas de consulta tiene índice.
- Índices compuestos siguen filtros reales: por ejemplo estado/expiración en
  oportunidades, conductor/estado/fecha en historial y job/fecha/ID en eventos.
- Índices parciales cubren conjuntos pequeños y frecuentes como trabajos
  publicados, asignaciones ganadoras, reservas abiertas y topups pendientes.
- Las listas usan cursores estables `(created_at, id)` o equivalentes; no `OFFSET`
  profundo.
- Restricciones `CHECK`, `UNIQUE`, claves foráneas y transiciones de servidor
  protegen invariantes incluso si un frontend contiene un error.

No se propone particionamiento para 500–1.000 usuarios. Se medirá primero; eventos
y ledger podrán particionarse en el futuro por fecha únicamente si volumen,
retención y planes de consulta lo justifican.

## 16. API y límites de módulos

Los clientes consumen casos de uso, no tablas financieras abiertas. Contratos
conceptuales mínimos:

- calcular precio recomendado;
- crear/editar/publicar/cancelar solicitud;
- listar oportunidades compatibles;
- aceptar trabajo atómicamente;
- avanzar un trabajo mediante acciones válidas;
- obtener contacto de una asignación vigente;
- completar y liquidar;
- consultar resumen y movimientos propios de billetera;
- solicitar/consultar recarga;
- abrir y resolver una incidencia según rol.

Lecturas simples de datos propios pueden usar la Data API con grants mínimos y
RLS. Asignación, transición, publicación, recargas y dinero usan funciones/RPC
transaccionales o un servicio confiable. Si una función requiere privilegios de
definidor, vive en un esquema no expuesto, fija `search_path`, usa nombres
calificados, comprueba `auth.uid()` y revoca ejecución a `PUBLIC` y roles no
autorizados.

Push, WhatsApp, almacenamiento y proveedores externos se integran mediante
adaptadores. Una outbox posterior al commit permite reintentos sin mantener
transacciones de base de datos abiertas durante llamadas de red.

## 17. Seguridad

### 17.1. RLS y privilegios

- RLS se habilita en toda tabla de un esquema expuesto.
- Grants y policies se diseñan por operación; `TO authenticated` por sí solo no
  autoriza acceso a una fila.
- Policies de usuario comparan con `(select auth.uid())` e indexan las columnas
  de propiedad.
- Una actualización sensible requiere `USING`, `WITH CHECK` y la policy de
  lectura correspondiente.
- Los clientes solo leen/escriben el mínimo necesario. No tienen `DELETE` físico
  sobre trabajos, eventos, ledger, reservas, recargas confirmadas o auditoría.
- Vistas expuestas son `security_invoker` o permanecen fuera del API.
- La PWA no autenticada, si se aprueba, no obtiene permiso directo general de
  inserción; usa un endpoint validado, limitado y protegido contra abuso.

### 17.2. Matriz de acceso resumida

| Recurso | Cliente | Conductor | Vrixora Admin |
|---|---|---|---|
| Solicitud propia | Crear/leer/cancelar según estado | Solo proyección sin contacto antes de aceptar | Según capacidad |
| Oportunidad compatible | No | Leer datos operativos sin PII | Leer/gestionar según capacidad |
| Trabajo asignado | Leer propio | Leer/accionar solo si es el asignado | Supervisión auditada |
| Contacto | Del conductor asignado | Del cliente solo tras asignación | Solo roles autorizados |
| Billetera/ledger | No | Leer la propia | Finanzas/owner; mutaciones por RPC |
| Eventos/auditoría | Eventos propios permitidos | Eventos asignados permitidos | Acceso por capacidad; sin edición histórica |

### 17.3. Amenazas y controles

- **Doble aceptación:** cambio condicional, bloqueo transaccional y unicidad del
  ganador.
- **Doble cobro/reserva:** unicidad por `job_id`/tipo, idempotency key y ledger
  append-only.
- **Repetición de solicitudes:** clave única por actor, operación y alcance;
  misma clave con payload diferente se rechaza.
- **IDOR/BOLA:** RLS y validación de propiedad/asignación en servidor; no confiar
  en IDs enviados por la interfaz.
- **Filtración de contacto:** proyecciones sin PII, RPC posterior a asignación,
  push sin teléfonos y objetos privados para fotos.
- **Escalada de rol:** roles administrados por servidor; nunca `user_metadata` ni
  un valor que el cliente pueda escribir.
- **Manipulación de precio/comisión:** precio final y regla se congelan al publicar;
  comisión se calcula en servidor.
- **Eventos falsos o fuera de orden:** tabla append-only, transición validada y
  tiempo de servidor.
- **Abuso de PWA:** validación, límites por identidad/IP/teléfono, CAPTCHA o
  mecanismo equivalente sujeto a decisión, expiración y monitoreo.

## 18. Idempotencia, auditoría y consistencia

Toda publicación, aceptación, transición, cancelación, liquidación, recarga y
ajuste recibe una `idempotency_key`. El servidor guarda actor, operación, hash
del payload, estado y respuesta. Repetir exactamente la solicitud devuelve el
resultado original; reutilizar la clave con otro payload falla.

La auditoría registra como mínimo:

- actor y rol efectivo;
- acción y entidad;
- valores anterior y nuevo pertinentes;
- motivo;
- fecha/hora de servidor;
- idempotency key y correlation ID;
- origen de la operación;
- resultado.

Los eventos de dominio no reemplazan la auditoría de seguridad y viceversa. Los
procesos de conciliación verifican periódicamente:

- un ganador máximo por trabajo;
- correspondencia entre trabajo aceptado y reserva;
- correspondencia entre trabajo liquidado, reserva consumida y débito;
- saldos cacheados contra ledger y reservas;
- recargas confirmadas contra créditos únicos;
- ausencia de integraciones de Fase 2 duplicadas.

## 19. Compatibilidad offline y sincronización

- Hive continúa como fuente local para las funciones esenciales actuales.
- La cola existente consolida cambios por entidad y transfiere lotes pequeños;
  no debe mezclarse con la competencia en tiempo real por un trabajo.
- Marketplace no admite aceptar, publicar ni avanzar estados sin conexión.
- Una acción iniciada con red inestable muestra resultado pendiente hasta que el
  servidor confirme; el reintento reutiliza la misma idempotency key.
- La aplicación puede cachear listas y detalles para lectura, marcándolos con la
  hora de última actualización y sin habilitar acciones sobre estado obsoleto.
- Restaurar un respaldo de Google Drive no restaura ni altera trabajos, wallet o
  ledger del servidor.
- Las actualizaciones conservan cajas Hive, IDs, datos históricos y lectores de
  esquemas anteriores.

## 20. Rendimiento, escalabilidad y operación

Para 500–1.000 usuarios activos, una base PostgreSQL/Supabase compartida con
índices correctos y transacciones cortas es suficiente; no se requiere una
arquitectura distribuida prematura.

Requisitos operativos:

- seleccionar solo columnas y cambios necesarios;
- paginar disponibles, historial, eventos y transacciones;
- evitar N+1 mediante proyecciones y consultas por lote;
- limitar el fan-out de push y procesarlo fuera de la transacción;
- adquirir bloqueos en un orden documentado y consistente;
- establecer timeouts y observabilidad para RPC críticas;
- medir latencia y contención de aceptación, fallos RLS, duplicados evitados,
  profundidad de outbox, sincronizaciones y reconciliación;
- revisar planes con `EXPLAIN (ANALYZE, BUFFERS)` usando datos representativos
  antes de producción;
- aplicar retención y archivado a notificaciones técnicas, no al ledger ni a la
  auditoría financiera requerida;
- evitar suscripciones Realtime globales: cada cliente escucha solo recursos
  autorizados o usa refresco/push dirigido.

La optimización de elegibilidad por zona se incorpora en Fase 3 con PostGIS o
equivalente solo después de definir geolocalización. El MVP filtra por criterios
no geoespaciales y ámbito operativo configurado.

## 21. Fases

### Fase 0 — diseño y arquitectura

- cerrar este PRD, estados, límites y contratos;
- validar el modelo contra el esquema canónico de Vrixora Admin;
- cerrar decisiones pendientes de identidad, precio, wallet y cancelación;
- preparar diagramas, amenazas, migraciones y plan de pruebas sin desplegar.

### Fase 1 — Marketplace MVP

- PWA cliente;
- publicación de trabajos;
- precio recomendado editable y advertencia por precio bajo;
- filtrado de conductores compatibles y notificaciones;
- aceptación atómica sin pujas;
- contacto por teléfono y WhatsApp después de asignar;
- flujo hasta completado/liquidado;
- wallet ledger, reserva y comisión del 10 %;
- operación y conciliación mínima en Vrixora Admin.

### Fase 2 — integración automática

- creación idempotente de ingreso y kilómetros desde un trabajo completado;
- representación contable de la comisión sin doble conteo;
- incorporación a estadísticas;
- sincronización incremental con compatibilidad offline-first.

### Fase 3 — expansión

- geolocalización y radio/zona de trabajo;
- empresas y hoteles;
- trabajos recurrentes;
- calificaciones;
- incidencias y disputas avanzadas;
- carga avanzada;
- optimización de precios.

## 22. Fuera del MVP

- pujas o contraofertas entre conductores;
- chat interno;
- GPS propio o seguimiento continuo;
- pago digital del cliente dentro de la plataforma;
- precio dinámico complejo;
- APK independiente para clientes;
- geolocalización/radio de trabajo;
- empresas, hoteles y trabajos recurrentes;
- calificaciones y disputas avanzadas.

## 23. Decisiones cerradas

1. El ecosistema tiene tres componentes: Conductor, Cliente PWA y Vrixora Admin.
2. TUKTUK Control conserva todas sus funciones y añade **Trabajos**; Tienda pasa
   a **Más → Tienda**.
3. Los cuatro servicios iniciales son pasajeros, carga, courier y turismo.
4. Solo conductores compatibles reciben/consultan oportunidades.
5. El cliente puede cambiar el precio recomendado y publicar un precio bajo tras
   una advertencia.
6. No hay pujas en el MVP.
7. El primer conductor elegible que confirma gana mediante una transacción de
   servidor.
8. **Reservado** se simplifica dentro de **Aceptado** para el MVP; no es un estado
   durable visible.
9. El contacto permanece oculto hasta asignar; después se usan `tel:` y WhatsApp.
10. No hay chat interno en el MVP.
11. La comisión es 10 % del precio final y se reserva al aceptar.
12. Wallet y comisión se implementan como ledger/reserva, no como saldo editable.
13. Se mantiene la prueba/licencia de 30 días y una licencia por usuario/aplicación.
14. Marketplace requiere conexión; la gestión actual continúa offline.
15. La integración con registros y estadísticas es idempotente y pertenece a
    Fase 2.
16. No se crean nuevas copias de perfiles, vehículos, registros o licencias sin
    validar antes el modelo canónico existente.

## 24. Decisiones pendientes

| Decisión | Opciones/impacto | Debe cerrarse antes de |
|---|---|---|
| Identidad del cliente PWA | Cuenta con OTP/magic link, sesión invitada verificada u otro mecanismo | Diseño de Auth/RLS del MVP |
| Campos de contacto obligatorios | Teléfono, WhatsApp o al menos uno; consentimiento y verificación | Formularios y política de privacidad |
| Proveedor de mapas/distancia | Entrada manual, API externa o combinación | Motor de precio del MVP |
| Configuración inicial de precio | Tarifas, moneda, mínimos, umbral de advertencia y redondeo | Pruebas de cotización |
| Inicio del prepago estricto | Desde lanzamiento, después de prueba o activación gradual | Reglas de aceptación |
| Saldo inicial | Crédito promocional, recarga previa o saldo negativo controlado | Piloto financiero |
| Recargas del MVP | Flujo manual confirmado por Vrixora Admin, canales y evidencias | Operación con dinero real |
| Cancelaciones | Ventanas, penalizaciones, liberación parcial/total y actor autorizado | Implementar estados/ledger |
| Confirmación de completado | Conductor, cliente, ambos o cierre por plazo | Liquidación |
| Titular de wallet | Conductor, propietario u organización en vehículos compartidos | Modelo relacional financiero |
| Privacidad y retención | Plazos para PII, fotos, ubicaciones, eventos y auditoría | Producción pública |
| Ámbito operativo sin geolocalización | Municipio, zona declarada o publicación general | Distribución del MVP |
| Integración contable Fase 2 | Ingreso bruto/neto y comisión como gasto separado | Automatización de registros |
| SLA de incidentes | Estados, permisos, escalamiento y cierre mínimo del MVP | Piloto operativo |

## 25. Riesgos técnicos

- El esquema canónico de Vrixora Admin puede diferir del subconjunto visible en
  este repositorio; duplicar tablas antes de compararlo rompería identidad/RLS.
- Una policy RLS compleja de compatibilidad puede degradar listados; deben usarse
  filtros indexables y helpers cuidadosamente auditados.
- La concurrencia entre aceptación y cancelación puede producir resultados
  ambiguos si ambas acciones no comparten la misma máquina de estados y bloqueo.
- Wallet, topups y comisión amplían el riesgo financiero y exigen conciliación,
  pruebas transaccionales y operaciones compensatorias.
- Push puede llegar tarde o duplicado; la interfaz debe volver a consultar al
  servidor y tolerar la pérdida de la oportunidad.
- Relojes de dispositivos incorrectos no pueden gobernar expiraciones ni eventos.
- La futura creación de registros puede duplicar ingresos/kilómetros si no existe
  unicidad por `job_id` y una estrategia clara de reintentos.
- Guardar detalles variables solo en JSON dificultaría índices y validación; los
  campos de compatibilidad deben permanecer tipados.
- Fotos y ubicaciones aumentan superficie de privacidad, almacenamiento y abuso.
- El acoplamiento del Marketplace con Hive podría degradar el modo offline; deben
  mantenerse módulos y fuentes de verdad separados.

## 26. Riesgos de negocio

- Un precio editable demasiado bajo puede reducir aceptación y calidad aun con
  advertencia.
- Sin pujas, la velocidad favorece a conductores con mejor conexión; deben medirse
  concentración y equidad antes de optimizar distribución.
- Comisión, cancelaciones y saldo insuficiente pueden causar disputas si no se
  muestran antes de aceptar.
- La verificación limitada de capacidades puede permitir información falsa sobre
  pasajeros, carga o carrocería.
- Compartir contacto por canales externos reduce la visibilidad sobre acuerdos y
  conductas posteriores.
- Una PWA con baja fricción puede recibir spam o solicitudes fraudulentas.
- La operación manual de recargas puede no escalar si crece el volumen sin
  conciliación y SLA claros.
- Licencia y wallet pueden confundirse; la interfaz y soporte deben explicar por
  separado acceso, saldo, reserva y comisión.
- Falta definir responsabilidades legales, privacidad, seguros y artículos/cargas
  prohibidas antes de operación pública.

## 27. Criterios de aceptación del MVP

El MVP se considera aceptable solo cuando, con pruebas automatizadas e integración
en un entorno no productivo:

1. TUKTUK Control conserva todos los módulos actuales y sus datos tras actualizar.
2. Inicio, Registros, Trabajos, Estadísticas y Más funcionan en los anchos móviles
   soportados; Tienda continúa disponible desde Más.
3. Un cliente puede crear y publicar cada tipo inicial con validaciones específicas.
4. El servidor genera un precio recomendado reproducible, muestra su desglose y
   permite editarlo con advertencia registrable cuando corresponda.
5. Un conductor incompatible no recibe ni puede consultar/aceptar la oportunidad,
   incluso invocando el endpoint directamente.
6. Una oportunidad nunca expone teléfono, WhatsApp ni foto privada antes de la
   asignación.
7. Dos o más aceptaciones concurrentes producen exactamente un ganador y respuestas
   coherentes para los demás.
8. Repetir una aceptación con la misma idempotency key no crea asignación, reserva,
   evento ni cargo adicional.
9. Aceptar crea una reserva exacta del 10 % y actualiza los tres saldos de forma
   consistente cuando el prepago está activo.
10. Completar/liquidar produce exactamente un débito; una cancelación válida libera
    o compensa según la regla configurada.
11. Cada transición acepta solo actores y estados permitidos y genera un evento
    append-only con tiempo de servidor.
12. Después de asignar, solo cliente y conductor asignado obtienen los contactos
    autorizados y pueden abrir `tel:`/WhatsApp.
13. RLS y grants impiden lectura cruzada entre clientes, conductores y organizaciones;
    ningún frontend contiene `service_role` ni secretos.
14. Las funciones/RPC privilegiadas validan identidad, fijan `search_path`, tienen
    permisos mínimos y rechazan llamadas no autorizadas.
15. Los listados principales usan índices y cursores y cumplen objetivos de latencia
    acordados con un conjunto representativo de 1.000 usuarios activos.
16. Una caída o duplicación de push no altera la asignación ni genera cobros dobles.
17. Sin internet, Marketplace bloquea mutaciones con un mensaje claro mientras
    registros, gastos, kilometraje, batería, mantenimiento y estadísticas locales
    continúan funcionando.
18. Recuperar conexión reintenta operaciones inciertas con la misma clave y no crea
    duplicados.
19. Respaldar o restaurar Google Drive no modifica trabajos ni el ledger remoto.
20. Vrixora Admin puede localizar trabajos, reservas, cargos, recargas e incidentes
    con permisos y auditoría adecuados.
21. La conciliación detecta cualquier diferencia entre trabajo, asignación, reserva,
    ledger y saldo cacheado.
22. Pruebas de actualización y restauración conservan los registros históricos,
    IDs, propietarios, vehículos y compatibilidad con esquemas anteriores.
23. Se ejecutan análisis estático, pruebas unitarias, pruebas de integración RLS/RPC,
    pruebas de concurrencia, pruebas offline, pruebas de carga y compilaciones
    Android/Web antes de considerar implementada la fase.
24. Existe un plan de rollback que no elimina datos financieros ni datos locales.

## 28. Condición de salida de la Fase 0

La Fase 0 termina cuando el owner aprueba este alcance, se cierran las decisiones
que bloquean Auth, precio, billetera y cancelaciones, se valida el modelo contra
el backend canónico de Vrixora Admin y se convierte el diseño en migraciones y
planes de prueba revisables. La existencia de este documento no autoriza cambios
de código, Supabase, Edge Functions, Android, Web, producción, versiones, secretos,
firma ni `google-services`.
