# PRD — TUKTUK Marketplace V1 / TUKTUK 2.0

**Producto:** Suite TUKTUK Control + TUKTUK Trabajos

**Componentes:** TUKTUK Control Conductor, TUKTUK Cliente y Vrixora Admin

**Versión del documento:** 1.1

**Fecha:** 14 de septiembre de 2026

**Estado:** Fase 1 — implementación en curso; sin autorización de despliegue a producción

**Rama de trabajo:** `feature/marketplace-v1`

**Base estable:** `0efed3c` — versión 1.0.8+10

---

## 1. Propósito y relación con el producto actual

Este documento formaliza la evolución de TUKTUK Control hacia TUKTUK 2.0,
un marketplace multimodal de servicios prestados con categorías configurables
de vehículos, sin eliminar, sustituir ni degradar ninguna capacidad actual de
control económico y operativo.

TUKTUK Trabajos ("Marketplace" es únicamente terminología técnica interna) es una ampliación del ecosistema, no una reescritura de la
aplicación existente. Los registros diarios, ingresos, gastos, kilometraje,
batería, mantenimiento, estadísticas, Hive, respaldo/restauración local,
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
- Cobrar una comisión del 10 % únicamente en `wallet_commission`, mediante una
  billetera prepago y operaciones transaccionales de servidor; `trial_free` no cobra.
- Mantener la experiencia actual de TUKTUK Control y sus funciones esenciales
  completamente disponibles sin conexión.
- Usar 500–1.000 usuarios activos como supuesto técnico inicial de pruebas y
  dimensionamiento, y permitir evolucionar conforme aumente el volumen real sin
  sustituir la arquitectura principal.

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
6. La prueba/licencia de TUKTUK Control, la prueba única de Trabajos y la
   billetera son conceptos distintos. No existe una licencia Marketplace separada.
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

**Trabajos** es también un gancho principal de adquisición: el usuario no debe
agotar ni esperar los 30 días de Control para iniciar la habilitación Marketplace.
Desde el onboarding inicial puede elegir conceptualmente **Gestionar mi vehículo /
usar TUKTUK Control** o **Quiero trabajar con TUKTUK**. La segunda opción inicia
de inmediato el perfil de conductor, configuración de vehículo, fotografías y
requisitos, inicio explícito de 30 días gratis, continuidad con saldo prepago y recepción de
oportunidades. Esta elección no elimina la modalidad Control ni sus datos.

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

- publicar sin registro, contraseña, OTP ni código de WhatsApp visibles; el
  servidor puede usar una sesión anónima o identificador opaco interno;
- cotizar y crear una solicitud;
- editar el precio recomendado antes de publicar;
- consultar estado y datos del conductor asignado;
- recibir actualizaciones del trabajo conforme a su estado;
- cancelar conforme a las reglas vigentes;
- abrir WhatsApp después de la asignación.

### 4.3. Vrixora Admin

Centro de control del Marketplace para personal autorizado. Amplía el producto
administrativo, no la aplicación de conductores. Debe administrar:

- conductores y clientes;
- trabajos, asignaciones y eventos;
- valoraciones y comentarios relevantes;
- billeteras, recargas, reservas y comisiones;
- incidencias, cancelaciones y disputas;
- configuración de servicios, precios, advertencias y operación;
- foto del conductor, su origen cuando sea relevante, foto principal del vehículo
  y estado de perfil/verificación;
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
- WhatsApp;
- origen;
- destino;
- fecha y hora solicitadas;
- tipo de servicio;
- observaciones;
- paradas adicionales, cuando correspondan;
- precio recomendado y precio final propuesto;
- moneda.

WhatsApp se normaliza a formato internacional y es el contacto operativo único;
no se solicita un segundo teléfono genérico. Origen,
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

### 8.1. Clasificación independiente del vehículo

Todo conductor que habilite un vehículo para Marketplace completa un onboarding
específico de Marketplace y selecciona dos dimensiones independientes:

1. **Categoría o tipo de vehículo:** su clase operativa.
2. **Tipo de propulsión:** cómo se impulsa el vehículo.

No se confunden ni se derivan una de la otra. Un triciclo, por ejemplo, puede ser
eléctrico o de combustión; un auto ligero puede ser eléctrico, de combustión o
híbrido.

Las categorías iniciales son:

- Auto ligero.
- Triciclo.
- Motocicleta.
- Furgoneta.
- Camión.
- Otro.

Los tipos iniciales de propulsión son:

- Eléctrico.
- Combustión.
- Híbrido.

La arquitectura conserva ambos como catálogos configurables con códigos estables,
estado y orden de presentación, no como restricciones rígidas dispersas en el
cliente. Así se podrán añadir nuevas categorías o propulsiones sin rediseñar el
modelo ni reescribir reglas históricas. La categoría **Otro** requiere una
descripción operativa y queda sujeta a las mismas capacidades declaradas o
verificadas que cualquier otra.

Ejemplos válidos de combinaciones: Triciclo + Eléctrico, Triciclo + Combustión,
Auto ligero + Combustión, Auto ligero + Eléctrico, Motocicleta + Eléctrico,
Furgoneta + Combustión y Camión + Combustión.

### 8.2. Perfil para Marketplace

Debe poder definir:

- categoría del vehículo;
- tipo de propulsión;
- marca;
- modelo;
- año;
- matrícula o identificación;
- tipos de servicio habilitados;
- capacidad de pasajeros;
- capacidad máxima de carga;
- volumen o dimensiones útiles;
- carrocería o configuración;
- disponibilidad actual y ventanas futuras;
- conductor y vehículo activos para recibir oportunidades;
- en una fase posterior, radio, zona o corredor de trabajo.

Las capacidades físicas pertenecen al vehículo. La disponibilidad, el conductor
activo y sus ventanas pertenecen a la relación conductor–vehículo. Las
habilitaciones que requieren verificación administrativa deben distinguir valor
declarado, valor verificado, estado y fecha de verificación.

Según la propulsión seleccionada, la interfaz presenta solo los módulos
correspondientes sin borrar datos existentes:

- **Eléctrico:** batería, voltaje, carga, energía y funciones eléctricas actuales
  o futuras.
- **Combustión:** oculta los módulos exclusivos de batería de tracción y carga
  eléctrica, no exige `batteryVoltage` ni valores ficticios y prepara combustible,
  consumo, repostajes y autonomía para fases posteriores.
- **Híbrido:** permite ambos grupos cuando apliquen a la configuración real.

La adaptación por propulsión no es solamente visual: define formularios,
validaciones, campos requeridos, registros y estadísticas aplicables. Los datos
históricos existentes se conservan aunque la configuración actual no los use.

### 8.3. Identidad visual del conductor y del vehículo

Al iniciar sesión con Google, si la cuenta proporciona una imagen de perfil,
TUKTUK la utiliza inicialmente como foto de perfil del conductor para reducir
pasos del onboarding de Marketplace. Es un valor inicial de conveniencia, no una
prueba de identidad ni una fuente de autorización.

El conductor puede conservar esa foto, sustituirla por una foto personalizada o
actualizarla desde su perfil. Si Google no proporciona imagen, el onboarding debe
solicitar o permitir subir una foto para completar el perfil de Marketplace.

La foto del conductor identifica a la persona y es independiente de la foto
principal del vehículo, que identifica el transporte asignado. Cada vehículo
puede tener su propia foto principal; cambiar el vehículo no reemplaza la foto
del conductor y cambiar la foto del conductor no modifica ninguna foto de
vehículo.

El MVP exige al menos una foto principal para habilitar un vehículo en
Marketplace. Esa foto ayuda a identificar el transporte, se muestra al cliente
solo después de la asignación y puede ser consultada por Vrixora Admin; por sí
sola no constituye verificación oficial. Múltiples fotografías de vehículo se
incorporan posteriormente.

La arquitectura no depende indefinidamente de una URL externa de Google. En el
MVP, la foto del conductor y la foto principal del vehículo se gestionan como
`media_assets` en almacenamiento privado controlado por TUKTUK, con acceso
autorizado mediante URLs firmadas de corta duración. La imagen de Google puede
usarse como valor inicial y copiarse/importarse al almacenamiento controlado
durante el onboarding o cuando el conductor la confirme. La política exacta de
retención y eliminación sigue siendo una decisión de privacidad previa a la
operación pública, pero no cambia este contrato técnico.

### 8.4. Habilitación Marketplace y estados del conductor

El perfil de Trabajos tiene estados independientes de la licencia de Solo
Control: **incompleto**, **activo** y **suspendido**. Tras completar onboarding,
el conductor inicia explícitamente su única prueba con “Comenzar 30 días gratis”.
Durante ella, un conductor activo con vehículo activo puede aceptar sin depósito.

Como mínimo para activar Trabajos requiere nombre/perfil válido, WhatsApp,
foto del conductor, vehículo, categoría, propulsión, marca, modelo,
matrícula/identificación cuando aplique, capacidades, servicios habilitados y
foto principal del vehículo. El MVP no exige aprobación documental administrativa
previa; Vrixora puede suspender posteriormente.

El primer depósito mínimo es CUP 500 por defecto y configurable desde Vrixora.
Se acredita íntegro al saldo; no es cuota ni pago de activación. Requisitos
completos + inicio explícito del trial otorgan 30 días gratuitos; al vencer,
depósito confirmado = continuidad para nuevas aceptaciones. Personal con
`payments.manage` verifica y acredita el pago; no existe un segundo activador.

Un conductor es elegible solo si, en el momento de consultar y nuevamente al
aceptar:

- su identidad y relación con el vehículo están activas;
- su perfil de Trabajos está activo;
- conductor y vehículo están disponibles;
- el tipo de servicio está habilitado;
- la categoría del vehículo cumple las reglas configurables del servicio;
- todas las capacidades requeridas satisfacen la solicitud;
- no existe un trabajo activo incompatible;
- cumple la política de billetera aplicable;
- no está suspendido ni bloqueado por riesgo u operación.

La validación definitiva ocurre dentro de la transacción de aceptación. La lista
vista por el conductor es informativa y puede quedar obsoleta.

La categoría es una señal del motor de elegibilidad, no una regla absoluta de
asignación. Las reglas pueden combinar tipo de servicio, categoría, pasajeros,
carga máxima, volumen/dimensiones, carrocería y características solicitadas. Los
ejemplos iniciales orientan configuración —motocicletas para mensajería y envíos
pequeños; triciclos para pasajeros, carga ligera y mensajería; autos ligeros para
pasajeros, turismo, mensajería y carga compatible; furgonetas para pasajeros o
carga; y camiones principalmente para carga—, pero no se codifican como límites
inamovibles. La decisión final se basa en capacidades reales declaradas o
verificadas y reglas versionadas del servicio.

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

Todos los importes se representan como `numeric(14,2)` y código de moneda. La tasa
de comisión usa `numeric(8,6)`, donde `0.10` = 10 %, y la regla de redondeo se
versiona junto con el precio.

## 10. Distribución de oportunidades y notificaciones

Los conductores compatibles reciben una oportunidad con:

- tipo de servicio;
- origen y destino con el nivel de precisión permitido;
- fecha/hora;
- requisitos relevantes;
- precio final;
- expiración de la oportunidad;
- ausencia explícita de WhatsApp y otros contactos del cliente.

La elegibilidad se calcula en servidor con filtros indexables. Para no multiplicar
el almacenamiento por cada combinación trabajo–conductor, no se requiere crear
una asignación permanente para cada notificación. Los intentos de entrega pueden
registrarse en una infraestructura de notificaciones con retención limitada; la
tabla `job_assignments` conserva candidatos que iniciaron una aceptación, el
ganador y cambios de asignación con valor operativo o de auditoría.

Las notificaciones son una ayuda de descubrimiento, no una garantía. Al abrir
**Disponibles**, la aplicación consulta el estado vigente. Una notificación
duplicada o tardía no permite aceptar dos veces un trabajo.

El cliente también recibe actualizaciones de estado —asignación, conductor en
camino, llegada/recogida, servicio en curso, completado, cancelación e incidente—
por un mecanismo técnico que se decidirá posteriormente. Esas notificaciones se
derivan de eventos de servidor y nunca cambian el estado por sí mismas.

## 11. Asignación atómica

El primer conductor elegible que confirma obtiene el trabajo. La aceptación se
implementa como una única operación transaccional de servidor, conceptualmente
`accept_job(job_id, vehicle_id, idempotency_key)`.

Dentro de una transacción corta, la operación debe:

1. autenticar al actor y validar que controla la relación conductor–vehículo;
2. bloquear o actualizar condicionalmente el trabajo solo si continúa publicado,
   no expiró y no tiene ganador;
3. reevaluar compatibilidad, disponibilidad, estado activo de Trabajos y
   bloqueos;
4. congelar `trial_free` si el trial está activo, o `wallet_commission` si existe
   depósito inicial confirmado;
5. en trial no bloquear billetera ni crear reserva; fuera de él, comprobar saldo;
6. crear una reserva solo en `wallet_commission`;
7. crear la asignación ganadora con snapshots inmutables;
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
| Aceptado | Conductor asignado; modo económico congelado. Durante trial no hay reserva; fuera del trial se reserva comisión | En camino, Cancelado por cliente, Cancelado por conductor, Incidente |
| En camino | Conductor se dirige al origen | Recogida, Cancelado, Incidente |
| Recogida | Llegó o inició la recogida/abordaje | En curso, Cancelado, Incidente |
| En curso | Servicio en ejecución | Completado, Incidente |
| Completado | El conductor finalizó; trial queda gratis o el servidor liquida la reserva | Liquidado, Incidente |
| Liquidado | Trabajo cerrado; comisión asentada solo en `wallet_commission` | Incidente administrativo excepcional |
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

Antes de aceptar, ningún conductor recibe WhatsApp ni otros datos que
permitan identificar directamente al cliente. RLS y la forma de las respuestas
del servidor deben impedir obtenerlos incluso manipulando solicitudes.

Después de la asignación:

- el conductor asignado puede obtener el WhatsApp del cliente;
- el cliente obtiene los datos autorizados del conductor y vehículo: foto del
  conductor, nombre, valoración promedio y cantidad de valoraciones cuando haya
  información suficiente; foto principal del vehículo, categoría/tipo,
  marca/modelo cuando corresponda y matrícula o identificación conforme a la
  política de privacidad;
- ambos pueden usar el enlace de WhatsApp autorizado con número internacional y
  texto codificado de forma segura.

El acceso al contacto se entrega mediante una proyección/RPC específica que
verifica en servidor la asignación vigente. Los datos sensibles no deben formar
parte de la fila pública usada para listar oportunidades ni del payload push. La
foto, nombre u otros datos personales del conductor no se exponen al cliente antes
de la asignación salvo la información operacional mínima que una regla de negocio
autorice explícitamente.

No se implementa chat interno en el MVP. Los accesos administrativos a PII se
limitan por rol, se auditan y siguen una política de retención por definir.

### 13.1. Valoración básica del servicio

Después de un trabajo **Liquidado**, el cliente puede valorar una única vez al
conductor/servicio con una puntuación de 1 a 5 estrellas y comentario opcional.
La valoración se vincula a `job_id`, `customer_id`, `driver_id` y fecha/hora; una
restricción de unicidad impide duplicados. La interfaz puede mostrar promedio y
cantidad de valoraciones cuando haya información suficiente, conforme a reglas de
privacidad. Vrixora Admin consulta valoraciones y comentarios relevantes según
permisos. La valoración del conductor al cliente queda fuera del MVP.

## 14. Modelo económico y billetera

### 14.1. Modalidades comerciales cerradas

Los 30 días iniciales y la regla de una licencia por usuario y aplicación se
mantienen para quienes comienzan en la modalidad **TUKTUK Control**. Después del
período inicial, quien solo usa herramientas de gestión requiere una licencia
periódica vigente conforme al PRD maestro.

TUKTUK Trabajos ofrece una única prueba gratuita de 30 días por usuario, iniciada
explícitamente después de completar onboarding. Durante la prueba no requiere
depósito, no reserva ni cobra comisión y no genera deuda posterior. El modo
económico se congela al aceptar cada trabajo. Tras vencer, los nuevos trabajos
requieren depósito inicial confirmado y saldo suficiente para reservar el 10 %.

La prueba de Trabajos ≠ la prueba de Control: usuarios antiguos de Control también
reciben sus 30 días al pulsar el botón. Un depósito temprano se acredita íntegro y
no termina el trial; un trabajo aceptado en trial sigue gratis aunque termine
después. No hay comisión retroactiva.

Regla comercial: **Solo Control → licencia. `trial_free` → Control + Trabajos sin
comisión. `wallet_commission` → Control + Trabajos + comisión del 10 %.**

### 14.2. Prueba de Trabajos y continuidad con saldo prepago

Pulsar “Comenzar 30 días gratis” tras completar ficha personal, vehículo y fotos
inicia el trial con tiempo de servidor. Durante los 30 días las oportunidades son
gratuitas. Después, una recarga física o transferencia confirmada por Vrixora
habilita nuevas aceptaciones. El mínimo inicial es 500 CUP por defecto y
configurable; aplica solo al primer depósito.

Las oportunidades reales de **Trabajos** se muestran cuando la suite está activa.
Antes de activar, el onboarding puede mostrar información explicativa o ejemplos,
pero no el listado vivo de oportunidades. Durante `trial_free`, aceptar no exige
saldo; después del trial, `wallet_commission` exige saldo disponible.

### 14.3. Saldos e insuficiencia

- **Saldo total:** suma neta de transacciones contabilizadas del ledger.
- **Saldo reservado:** suma de reservas abiertas asociadas a trabajos aceptados.
- **Saldo disponible:** saldo total menos saldo reservado.

Los tres se muestran juntos y con moneda. Los saldos cacheados pueden mantenerse
para rendimiento, pero deben poder reconciliarse con el ledger y las reservas.

Fuera del trial, si el saldo disponible no permite reservar el 10 %, el conductor no puede aceptar
el trabajo y se le solicita recargar. Esto solo bloquea nuevas operaciones
Marketplace que requieren reserva; nunca bloquea registros, ingresos/gastos
históricos, estadísticas, mantenimiento, datos del vehículo ni las demás funciones
de TUKTUK Control.

### 14.4. Comisión y pago del cliente

En el MVP, el cliente paga directamente al conductor por el medio que acuerden.
TUKTUK no procesa, recibe ni retiene el pago del servicio y no actúa como custodio
de ese dinero. TUKTUK obtiene su ingreso al liquidar el 10 % desde el saldo
prepago del conductor. Los pagos digitales del cliente dentro de TUKTUK quedan
fuera del MVP.

1. En `trial_free` no se reserva ni cobra nada; en `wallet_commission` se reserva
   el 10 % esperado del precio final al aceptar.
2. Al marcar Completado, el servidor valida asignación y estado; solo
   `wallet_commission` valida y liquida reserva sin confirmación adicional.
3. Solo al liquidar `wallet_commission` se crea un débito inmutable en
   `wallet_transactions` y la reserva cambia a consumida.
4. En una cancelación válida, la reserva se libera. Si ya existió un asiento, se
   crea un asiento compensatorio; no se edita ni elimina el original.
5. Un incidente congela el efecto pendiente hasta una resolución autorizada.

`job_id` y el tipo de operación tienen restricciones únicas para impedir doble
reserva o doble comisión. Cada recarga y acción financiera usa una clave de
idempotencia, referencia externa única cuando corresponda, actor, motivo y evento
de auditoría.

### 14.5. Inactividad

No habrá desactivación automática por 180 días en el lanzamiento. Primero se
medirá actividad y oportunidades compatibles. Nunca se confisca saldo ni se borra
historia; una política futura requerirá aprobación separada.

## 15. Modelo de datos conceptual

Este modelo no crea tablas en esta fase. Los nombres son conceptuales y deberán
validarse contra el esquema canónico de Vrixora antes de una migración.

### 15.1. Entidades propuestas

| Entidad | Propósito y campos conceptuales principales | Relaciones/garantías |
|---|---|---|
| `customers` | Identidad de solicitante, nombre y WhatsApp normalizado; vínculo opcional a Auth/empresa | No duplica `profiles`; PII privada; deduplicación controlada |
| `service_requests` | Entrada del cliente, origen/destino, horario, servicio, detalles de carga/pasajeros, observaciones, foto privada | Pertenece a customer; conserva snapshot solicitado |
| `jobs` | Trabajo publicable/operable, estado actual, precio recomendado/final, moneda, versión de precio, expiración y ganador | Uno por solicitud publicada; actualización condicional de estado |
| `job_assignments` | Ganador, conductor, vehículo, aceptación, finalización y modo económico congelado | `trial_free` o `wallet_commission`; snapshots inmutables |
| `marketplace_work_trials` | Una prueba explícita por usuario/proyecto | Inmutable; inicio/fin exactos de 30 días |
| `job_events` | Historial append-only de transiciones y acciones | Orden por `(job_id, created_at, id)`; no editable por clientes |
| `vehicles` | Proyección relacional canónica para Trabajos usando exactamente el `vehicle_id text` existente; propietario, categoría, propulsión, marca, modelo, año, matrícula/identificación, capacidades, servicios y foto principal | No sustituye `VehicleProfile`/`sync_entities`; el puente legacy actualiza solo campos legacy y nunca borra campos de Trabajos |
| `driver_availability` | Relación conductor–vehículo, disponible/ocupado, ventanas y futura zona | Un estado actual por relación; solapes controlados; las capacidades físicas permanecen en `vehicles` |
| `driver_profiles` | Extensión de Trabajos del perfil autenticado: foto vigente, estado, suspensión y requisitos de activación | Relación 1:1 con `profiles`; WhatsApp permanece canónico en `profiles.phone` y no se duplica |
| `media_assets` | Referencia controlada a fotos de conductor y vehículo, propietario, tipo, estado, versión y metadatos mínimos | Acceso privado y proyecciones autorizadas; no depende indefinidamente de URL externa de Google |
| `wallets` | Billetera por conductor/usuario y moneda en el MVP, saldos cacheados/revisión | Una por `profiles.id` y moneda; no editable desde frontend; propiedad por organización queda para una evolución posterior |
| `wallet_transactions` | Ledger inmutable: recarga, comisión, ajuste, reverso; importe firmado y referencia | Claves únicas de idempotencia y origen; nunca hard delete |
| `commission_reservations` | Retención por job, importe, estado abierta/consumida/liberada y expiración | Una reserva canónica por job y wallet |
| `topups` | Solicitud, validación y conciliación de recargas | Confirmación crea exactamente un crédito de ledger |
| `ratings` | Valoración MVP de 1 a 5 estrellas y comentario opcional posterior a trabajo liquidado, con `job_id`, `customer_id`, `driver_id` y fecha/hora | Una valoración de cliente por trabajo; unicidad por `(job_id, customer_id, driver_id)` e historial sujeto a privacidad |
| `disputes` | Incidencia/disputa, estado, responsable, resolución y referencias | Fase 3 o soporte mínimo de incidentes en MVP |

Tablas de configuración versionada —tipos de servicio, categorías de vehículo,
tipos de propulsión, servicios habilitados por vehículo, reglas de elegibilidad,
reglas de precio, umbrales, reglas de cancelación y capacidades— pueden añadirse
al esquema compartido. Sus cambios no deben reescribir snapshots de trabajos
existentes. `vehicles` conserva referencias a una categoría y una propulsión
canónicas, además de los atributos de capacidad; las reglas de trabajo conservan
un snapshot mínimo de los criterios aplicados para auditoría.

### 15.2. Reutilización del sistema actual

#### `profiles`

Se reutiliza como perfil canónico de usuarios autenticados. En este repositorio ya
existe `public.profiles` con el mismo UUID de `auth.users`, email, nombre visible,
avatar y RLS por propietario. Debe ampliarse solo con datos generales que apliquen
a cualquier rol. Capacidades de vehículo, estado de conducción, saldo y PII
específica de clientes pertenecen a entidades separadas.

`profiles.phone` se preserva por compatibilidad y se trata en producto como
WhatsApp; no se añade un teléfono genérico duplicado. Un mismo usuario autenticado
puede ejercer más de un rol; no se crea un perfil duplicado por ser conductor y
cliente. Un `customer` puede enlazar a `profiles.id` cuando exista autenticación.
En el MVP, el cliente puede operar sin cuenta visible mediante una sesión anónima
o identificador opaco interno; no hay contraseña ni OTP. La deduplicación y los
controles de abuso no convierten el WhatsApp en una identidad autenticada.

El avatar disponible desde Google puede inicializar la foto de conductor, pero no
es el activo final ni una garantía de disponibilidad. El origen, la referencia
controlada, el estado de verificación y el reemplazo por foto personalizada se
modelan en la extensión de Marketplace y sus activos multimedia, sin convertir la
URL externa en dependencia permanente.

#### `vehicles`

Se preservan exactamente los IDs actuales, incluso si son texto: no se exige ni se
convierte a UUID. La app ya modela múltiples `VehicleProfile`, aunque
la interfaz usa un vehículo activo, y actualmente sincroniza vehículos como
payloads `vehicle` en `sync_entities`; este repositorio todavía no define una
tabla relacional `vehicles` en sus migraciones.

Antes del Marketplace debe identificarse la tabla canónica compartida o diseñarse
una proyección relacional queryable e idempotente desde `sync_entities`, sin
destruirlo, sustituirlo ni copiar el vehículo con un ID nuevo. Trabajos nunca
guarda jobs, wallet, asignaciones, reservas ni ledger en `sync_entities`.
El perfil canónico se amplía o relaciona con capacidades físicas y
servicios. Para Marketplace incluye categoría, propulsión, marca, modelo, año,
matrícula/identificación, pasajeros, carga, volumen/dimensiones, carrocería y
servicios habilitados, además de una referencia a su foto principal independiente
de la foto del conductor. No se almacenan esas capacidades como una copia dentro
de cada job; solo se conserva un snapshot mínimo de compatibilidad cuando haga
falta auditar.

#### `records`

Los `DailyRecord` actuales —ingresos, gastos, odómetro, batería y metadatos de
sincronización— continúan siendo datos operativos offline-first. No se usan como
cola ni estado del Marketplace. Sus formularios, validaciones, campos requeridos
y estadísticas deben adaptarse a la propulsión: un vehículo de combustión no exige
voltaje/carga eléctrica ni valores ficticios, y uno híbrido admite ambos grupos.
Los datos históricos se preservan. En Fase 2, un trabajo completado puede originar
un registro mediante un vínculo estable `source_type = marketplace_job` y
`source_id = job_id`, protegido por unicidad para impedir duplicados.

La integración debe pasar por el contrato/repositorio de registros y la cola
incremental actual, conservar IDs y permitir reintentos. No debe sumar una
comisión como ingreso: ingreso bruto y comisión/gasto se representan de acuerdo
con la decisión contable que se cierre y sin contar dos veces el mismo importe.

#### `licenses`

Se reutiliza la misma licencia por usuario y aplicación; no se crea una “licencia
Marketplace” duplicada. La prueba de 30 días y las reglas de compra/renovación se
mantienen para Solo Control. Un Marketplace habilitado incluye Control conforme a
la modalidad comercial. `trial_free` exige trial activo y onboarding/perfil/vehículo
válidos, sin saldo. `wallet_commission` exige depósito inicial confirmado, saldo
suficiente y reserva de comisión, sin un segundo cobro de licencia. La tabla y RPC actuales son
administradas por Vrixora Admin y deben verificarse en su esquema canónico antes
de añadir relaciones.

### 15.3. Tipos, claves e índices

- Identificadores expuestos o compartidos entre clientes son UUID/IDs opacos y
  estables; se preservan los IDs de entidades existentes.
- Fechas usan `timestamptz` y tiempo del servidor.
- Importes usan `numeric(14,2)` y tasas `numeric(8,6)` (`0.10` = 10 %).
- Campos consultados y restricciones son columnas tipadas; JSON se reserva para
  snapshots versionados o detalles variables, no para claves de relación.
- Categoría y propulsión usan códigos de catálogos canónicos; los trabajos
  declaran requisitos configurables y no comparan etiquetas visibles.
- Toda clave foránea en rutas de consulta tiene índice.
- Índices compuestos siguen filtros reales: por ejemplo estado/expiración en
  oportunidades, conductor/estado/fecha en historial y job/fecha/ID en eventos.
- Las rutas de elegibilidad indexan las relaciones conductor–vehículo activas,
  categoría, servicios habilitados y disponibilidad antes de evaluar capacidades
  más específicas.
- Índices parciales cubren conjuntos pequeños y frecuentes como trabajos
  publicados, asignaciones ganadoras, reservas abiertas y topups pendientes.
- Las listas usan cursores estables `(created_at, id)` o equivalentes; no `OFFSET`
  profundo.
- Restricciones `CHECK`, `UNIQUE`, claves foráneas y transiciones de servidor
  protegen invariantes incluso si un frontend contiene un error.

El rango 500–1.000 usuarios activos es un supuesto técnico inicial para pruebas y
dimensionamiento, no un límite ni un objetivo comercial. Se medirá primero; eventos
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
- crear la valoración única del cliente posterior a liquidación;
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
| Valoraciones | Crear/leer la propia según reglas | Lectura de promedio/proyección autorizada; no valora al cliente en MVP | Revisar/moderar según capacidad |
| Billetera/ledger | No | Leer la propia | Finanzas/owner; mutaciones por RPC |
| Eventos/auditoría | Eventos propios permitidos | Eventos asignados permitidos | Acceso por capacidad; sin edición histórica |

### 17.3. Amenazas y controles

- **Doble aceptación:** cambio condicional, bloqueo transaccional y unicidad del
  ganador.
- **Doble cobro/reserva:** unicidad por `job_id`/tipo, idempotency key y ledger
  append-only.
- **Valoración duplicada o anticipada:** unicidad por trabajo/cliente/conductor y
  validación de que el trabajo está liquidado y pertenece a las partes.
- **Repetición de solicitudes:** clave única por actor, operación y alcance;
  misma clave con payload diferente se rechaza.
- **IDOR/BOLA:** RLS y validación de propiedad/asignación en servidor; no confiar
  en IDs enviados por la interfaz.
- **Filtración de contacto:** proyecciones sin PII, RPC posterior a asignación,
  push sin WhatsApp/contactos y objetos privados para fotos.
- **Escalada de rol:** roles administrados por servidor; nunca `user_metadata` ni
  un valor que el cliente pueda escribir.
- **Manipulación de precio/comisión:** precio final y regla se congelan al publicar;
  comisión se calcula en servidor.
- **Eventos falsos o fuera de orden:** tabla append-only, transición validada y
  tiempo de servidor.
- **Abuso de PWA:** validación, límites por sesión/IP/WhatsApp, CAPTCHA o
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
- `trial_free`: assignment válido, `billing_mode=trial_free`, cero
  `commission_reservation` y cero débito de comisión;
- `wallet_commission`: assignment válido, reserva canónica, reserva consumida al
  liquidar y exactamente un débito de comisión;
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
- Ninguna restauración, respaldo o dato local altera trabajos, asignaciones,
  billeteras, reservas, ledger ni estados remotos del Marketplace.
- Las actualizaciones conservan cajas Hive, IDs, datos históricos y lectores de
  esquemas anteriores.

## 20. Rendimiento, escalabilidad y operación

Para el supuesto técnico inicial de pruebas y dimensionamiento de 500–1.000
usuarios activos, una base PostgreSQL/Supabase compartida con índices correctos y
transacciones cortas es suficiente; no se requiere una arquitectura distribuida
prematura. Ese rango no es un límite del producto ni un techo de usuarios.

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
- mantener como configuración previa al piloto las tarifas/precios iniciales,
  canales/evidencia de recarga, retención de datos y criterios operativos que no
  cambian la arquitectura;
- preparar diagramas, amenazas, migraciones y plan de pruebas sin desplegar.

### Fase 1 — Marketplace MVP

- PWA cliente;
- publicación de trabajos;
- precio recomendado editable y advertencia por precio bajo;
- filtrado de conductores compatibles y notificaciones;
- aceptación atómica sin pujas;
- contacto por WhatsApp después de asignar;
- notificaciones de estado al cliente;
- valoración básica de cliente al conductor/servicio después de liquidar;
- flujo hasta completado/liquidado;
- wallet ledger, recarga mínima configurable, reserva y comisión del 10 % en `wallet_commission`; `trial_free` no cobra;
- prueba explícita de Trabajos, congelación de `billing_mode` y transición trial → wallet;
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
- valoraciones mutuas, reseñas avanzadas e incidencias/disputas avanzadas;
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
- valoraciones mutuas, reseñas avanzadas y disputas avanzadas.

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
9. El contacto permanece oculto hasta asignar; después se usa WhatsApp como contacto operativo autorizado.
10. No hay chat interno en el MVP.
11. La comisión es 10 % del precio final y se reserva al aceptar solo en `wallet_commission`; el trial es `trial_free` sin deuda ni retroactividad.
12. Wallet y comisión se implementan como ledger/reserva, no como saldo editable.
13. Se mantiene una licencia por usuario/aplicación; los 30 días y la licencia
    periódica aplican a Solo Control, mientras Marketplace activo incluye Control.
14. Marketplace requiere conexión; la gestión actual continúa offline y no pierde
    acceso por saldo Marketplace insuficiente.
15. La integración con registros y estadísticas es idempotente y pertenece a
    Fase 2.
16. No se crean nuevas copias de perfiles, vehículos, registros o licencias sin
    validar antes el modelo canónico existente.
17. Categoría/tipo de vehículo y tipo de propulsión son dimensiones independientes,
    configurables y obligatorias al habilitar un vehículo para Marketplace.
18. La categoría participa en elegibilidad, pero la compatibilidad se decide por
    capacidades reales declaradas o verificadas y reglas versionadas, no por una
    lista rígida codificada de vehículos permitidos.
19. La interfaz muestra módulos de batería/energía según la propulsión sin eliminar
    datos ni degradar las funciones actuales de TUKTUK Control.
20. La foto de Google, cuando exista, inicializa la foto del conductor durante el
    onboarding de Marketplace; el conductor puede conservarla, sustituirla o
    actualizarla y debe poder completar el perfil con una foto si Google no aporta
    una.
21. La foto del conductor y la foto principal del vehículo son activos independientes.
22. Tras asignar, el cliente recibe una proyección autorizada con identidad visual,
    reputación disponible y datos permitidos del conductor/vehículo; antes de
    asignar no se expone información personal innecesaria del conductor.
23. Las fotos se gestionan como activos privados controlados por TUKTUK; Google
    puede aportar el valor inicial, pero la plataforma lo copia/importa o reemplaza
    en almacenamiento controlado y no depende de la URL externa de forma permanente.
24. Marketplace admite categorías configurables de vehículos; las categorías
    iniciales no limitan rígidamente la elegibilidad, que se basa en capacidades y
    requisitos concretos del trabajo.
25. El conductor inicia una sola prueba explícita de 30 días de Trabajos tras
    onboarding, sin esperar Control; durante ella acepta sin billetera.
26. El primer depósito es CUP 500 por defecto, configurable desde Vrixora, entra
    íntegro como saldo y no crea un mínimo permanente ni es cuota/comisión.
27. El cliente paga directamente al conductor; TUKTUK cobra 10 % desde la billetera
    solo en `wallet_commission`; `trial_free` no genera comisión.
28. La valoración básica de cliente a conductor/servicio, de una a cinco estrellas
    con comentario opcional y una sola vez por trabajo liquidado, pertenece al MVP.
29. No hay desactivación automática por inactividad en el lanzamiento; nunca se
    confisca saldo ni se borra historia.
30. Las notificaciones al cliente reflejan eventos de servidor y cubren asignación,
    avance, completado, cancelación e incidente.
31. Tras vencer el trial, depósito físico o transferencia confirmado y acreditado
    por `payments.manage` permite nuevas aceptaciones; no hay segundo activador.

## 24. Decisiones pendientes

| Decisión | Opciones/impacto | Debe cerrarse antes de |
|---|---|---|
| Proveedor de mapas/distancia | Entrada manual, API externa o combinación detrás de un adaptador | Configuración/cotización antes del piloto |
| Configuración inicial de precio | Tarifas, mínimos, umbral de advertencia y regla de redondeo | Pruebas de cotización antes del piloto |
| Canales/evidencia de recarga | El flujo es manual y Vrixora confirma; falta definir qué comprobantes/canales se aceptan | Operación con dinero real |
| Privacidad y retención | Plazos para PII, fotos, ubicaciones, notificaciones técnicas y auditoría | Producción pública |
| SLA de incidentes | Tiempos, escalamiento y cierre operativo; el estado mínimo `incident` ya está definido | Piloto operativo |
| Verificaciones posteriores | Criterios de suspensión/revisión posterior; no bloquean la activación inicial del MVP | Operación/piloto |
| Política de inactividad futura | No automatizar en lanzamiento; medir actividad/oportunidades antes de proponerla | Post-piloto |
| Privacidad de reseñas | Visibilidad de comentarios, moderación, retención y respuesta administrativa | Publicación de valoraciones |
| Responsabilidades legales/operativas | Seguros, cargas prohibidas, condiciones del servicio y revisión local | Antes de operación pública |

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
- La carrera al iniciar el trial, el intento de reiniciar/repetir sus 30 días, la
  frontera exacta de expiración, la transición `trial_free` → `wallet_commission`
  y confundir prueba gratuita con deuda futura requieren pruebas transaccionales.
- La futura creación de registros puede duplicar ingresos/kilómetros si no existe
  unicidad por `job_id` y una estrategia clara de reintentos.
- Guardar detalles variables solo en JSON dificultaría índices y validación; los
  campos de compatibilidad deben permanecer tipados.
- Fotos y ubicaciones aumentan superficie de privacidad, almacenamiento y abuso.
- La dependencia de URL externas de Google puede dejar fotos inaccesibles; la
  estrategia multimedia debe evitar esa dependencia antes de implementación.
- Aplicar estados de propulsión solo en la interfaz y no en validaciones/registros
  produciría métricas incorrectas o valores eléctricos ficticios.
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
  separado Solo Control, Marketplace incluido, saldo, reserva y comisión.
- Una política de inactividad ciega puede penalizar a conductores sin oportunidades
  compatibles; debe observar oferta real antes de desactivar.
- La recarga podría interpretarse como cuota o cobro del servicio si no se comunica
  claramente como saldo del conductor para futuras comisiones.
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
6. Una oportunidad nunca expone WhatsApp, contacto ni foto privada antes de la
   asignación.
7. Dos o más aceptaciones concurrentes producen exactamente un ganador y respuestas
   coherentes para los demás.
8. Repetir una aceptación con la misma idempotency key no crea asignación, reserva,
   evento ni cargo adicional.
9. Durante trial, aceptar no crea reserva ni exige billetera; fuera de trial crea
   reserva exacta del 10 % y exige saldo disponible.
10. Un trabajo `trial_free` termina gratis incluso tras vencer; `wallet_commission`
    produce exactamente un débito y una cancelación válida libera la reserva.
11. Cada transición acepta solo actores y estados permitidos y genera un evento
    append-only con tiempo de servidor.
12. Después de asignar, solo cliente y conductor asignado obtienen los contactos
    autorizados y pueden abrir WhatsApp.
13. RLS y grants impiden lectura cruzada entre clientes, conductores y organizaciones;
    ningún frontend contiene `service_role` ni secretos.
14. Las funciones/RPC privilegiadas validan identidad, fijan `search_path`, tienen
    permisos mínimos y rechazan llamadas no autorizadas.
15. Los listados principales usan índices y cursores y cumplen objetivos de latencia
    acordados con el supuesto técnico inicial de pruebas y dimensionamiento de
    500–1.000 usuarios activos, sin tratarlo como límite de producto.
16. Una caída o duplicación de push no altera la asignación ni genera cobros dobles.
17. Sin internet, Marketplace bloquea mutaciones con un mensaje claro mientras
    registros, gastos, kilometraje, batería, mantenimiento y estadísticas locales
    continúan funcionando.
18. Recuperar conexión reintenta operaciones inciertas con la misma clave y no crea
    duplicados.
19. Ningún respaldo, restauración o dato local modifica trabajos, asignaciones,
    billeteras, reservas, ledger ni estados remotos.
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
25. El onboarding de Marketplace exige categoría y propulsión independientes y
    permite las categorías iniciales Auto ligero, Triciclo, Motocicleta, Furgoneta,
    Camión y Otro, junto con propulsión Eléctrico, Combustión o Híbrido.
26. El perfil del vehículo conserva marca, modelo, año, matrícula/identificación,
    categoría, propulsión, capacidades, carrocería y servicios habilitados sin
    crear un vehículo duplicado ni cambiar su ID existente.
27. El motor de elegibilidad evalúa categoría, servicio, pasajeros, carga,
    volumen/dimensiones, carrocería y características del trabajo; los ejemplos
    por categoría no bloquean combinaciones compatibles verificadas.
28. La propulsión adapta interfaz, formularios, validaciones, registros,
    estadísticas y campos requeridos: eléctrico muestra batería, voltaje, carga y
    energía; combustión no exige valores eléctricos ficticios; e híbrido permite
    ambos cuando corresponda, conservando datos históricos existentes.
29. El onboarding usa la foto de Google como valor inicial cuando exista, permite
    conservarla, cambiarla o subir una foto si falta, sin tratarla como identidad
    verificada ni depender de su URL externa de forma permanente.
30. La foto de conductor y la foto principal de vehículo se mantienen como activos
    independientes y actualizables; Vrixora Admin puede consultar ambas, su origen
    relevante y estado de perfil/verificación según permisos.
31. Antes de asignar, el cliente no recibe foto ni información personal innecesaria
    del conductor; tras asignar, la proyección autorizada incluye foto, nombre,
    reputación disponible, vehículo y los contactos permitidos.
32. La solución técnica de multimedia debe proteger acceso, actualización, respaldo
    y disponibilidad de fotos personalizadas o procedentes de Google antes de su
    despliegue, sin exponer activos privados ni depender de URLs externas caducables.
33. “Comenzar 30 días gratis” inicia una sola prueba exacta de 30 días con tiempo
    de servidor; reintentos, reinstalación o cambios de vehículo no la reinician.
34. Durante trial, activo acepta sin depósito; vencida, una nueva aceptación exige
    depósito confirmado y saldo. Suspendido nunca acepta.
35. Una recarga inicial permanece como saldo; la insuficiencia bloquea nuevas
    aceptaciones `wallet_commission`, no `trial_free`.
36. `trial_free` termina con cero débito; `wallet_commission` genera exactamente
    un débito de comisión del 10 % desde la billetera.
37. Después de liquidar, el cliente puede registrar una única valoración de una a
    cinco estrellas y comentario opcional para ese conductor/servicio; la unicidad
    por trabajo, cliente y conductor impide duplicados y Vrixora Admin puede
    revisarla según permisos.
38. El cliente recibe actualizaciones de asignación, en camino, llegada/recogida,
    en curso, completado, cancelación e incidente sin que la notificación pueda
    alterar el estado del trabajo.
39. La política configurable de inactividad conserva saldo, datos e historial y no
    penaliza automáticamente a quien no recibió oportunidades compatibles; su
    algoritmo considera oferta y disponibilidad real antes de desactivar.

## 28. Condición de salida de la Fase 0

La Fase 0 termina cuando el owner aprueba este alcance, se valida el modelo contra
el backend canónico de Vrixora Admin y quedan cerrados los contratos técnicos que
afectan compatibilidad, entitlement, wallet, trabajos, privacidad e idempotencia.
Las tarifas concretas, proveedor de distancia, evidencia de recarga, retención y
otros parámetros operativos pueden cerrarse antes del piloto sin bloquear el
inicio de la implementación estructural de Fase 1.

La existencia de este documento no autoriza cambios
de código, Supabase, Edge Functions, Android, Web, producción, versiones, secretos,
firma ni `google-services`.
