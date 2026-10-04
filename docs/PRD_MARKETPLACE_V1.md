# PRD — TUKTUK Marketplace / TUKTUK 2.0

**Producto:** Suite TUKTUK Control + TUKTUK Trabajos

**Componentes:** TUKTUK Control / Prestador, TUKTUK Cliente y Vrixora Admin

**Versión del documento:** 2.0

**Fecha:** 4 de octubre de 2026

**Estado:** Marketplace con componentes desplegados; modelo comercial TUKTUK 2.0 aprobado y pendiente de implementación/verificación completa

**Rama documental:** `docs/marketplace-business-model-v2-20261004`

**Base técnica verificada:** `06567abd84b69703a94d2ac6a4023c403e3f5816`

---

## 1. Propósito y relación con el producto actual

Este documento formaliza el contrato funcional de **TUKTUK Trabajos / Marketplace** dentro de TUKTUK 2.0.

Marketplace amplía TUKTUK Control, pero no sustituye ni degrada sus capacidades de control económico y operativo. Los registros diarios, ingresos, gastos, kilometraje, batería cuando corresponda, mantenimiento, estadísticas, Hive, respaldo/restauración local, sincronización incremental, Google Sign-In y soporte continúan disponibles conforme a sus contratos.

La regla comercial vigente cambia respecto de versiones anteriores:

- una cuenta autenticada es un **usuario TUKTUK**;
- ser usuario no significa ser conductor;
- Control y Estadísticas son permanentes y no vencen;
- el usuario se convierte en conductor cuando completa el alta operativa requerida de Trabajos;
- al completar esa alta se inicia automáticamente una promoción inicial de **X días**, configurada desde Gestión Comercial;
- durante la promoción no se cobra comisión por los trabajos aceptados bajo ese modo;
- después de la promoción, nuevas aceptaciones requieren saldo disponible suficiente para cubrir la comisión aplicable;
- el saldo puede proceder de recargas pagadas o de recompensas por referidos;
- no existe depósito inicial mínimo obligatorio;
- no existe compra, renovación ni vencimiento de licencia como condición para usar Control.

Los nombres técnicos existentes, como `trial_free`, pueden conservarse temporalmente por compatibilidad interna, pero en producto representan la **promoción comercial inicial**, no una licencia de Control.

Este PRD está subordinado a `vrixora-admin-canvas/docs/PRD_MASTER.md` y al PRD específico del Centro de Control cuando se trate de reglas generales o administrativas.

## 2. Objetivos

- Conectar solicitudes reales de pasajeros, carga, mensajería y turismo con conductores y vehículos compatibles.
- Permitir que un cliente solicite el servicio desde TUKTUK Cliente sin depender de una APK.
- Asignar cada trabajo de forma atómica, auditable y segura al primer conductor elegible que lo confirme.
- Proteger los datos de contacto del cliente hasta que exista una asignación.
- Mantener Control y Estadísticas permanentemente disponibles para el usuario.
- Convertir al usuario en conductor solo cuando complete el onboarding operativo requerido.
- Iniciar automáticamente una promoción inicial configurable al completar el alta válida.
- Cobrar, fuera de promoción, la comisión configurada mediante `wallet_commission`, con billetera prepago y operaciones transaccionales de servidor.
- Permitir que saldo real o saldo promocional por referidos cubran comisiones.
- Mantener las funciones esenciales de Control disponibles sin conexión.
- Usar 500–1.000 usuarios activos únicamente como supuesto técnico inicial de pruebas y dimensionamiento, nunca como límite del producto.

## 3. Principios obligatorios

1. El servidor es la autoridad para asignaciones, transiciones de estado, compatibilidad, promoción, comisiones, reservas, liquidaciones y anulaciones.
2. Ningún frontend usa `service_role`, decide quién ganó un trabajo ni escribe directamente saldos financieros.
3. El ledger y los eventos de trabajo son trazables; las correcciones usan asientos o eventos compensatorios.
4. Toda mutación crítica admite reintentos idempotentes.
5. Los datos de contacto se exponen por capacidad y estado, no por conocer un ID.
6. Control permanente, promoción de Trabajos y billetera son conceptos distintos.
7. La promoción de Trabajos no se inicia por botón manual: comienza automáticamente cuando el backend valida un onboarding operativo completo.
8. Marketplace requiere conexión para publicar, aceptar y cambiar estados. Una caché local nunca autoriza una operación crítica.
9. Las listas usan paginación, filtros e índices y no crean filas permanentes por cada conductor potencial.
10. Se reutilizan identidades y datos canónicos; no se crean copias innecesarias de perfiles, vehículos o registros.
11. El saldo disponible puede componerse de recargas pagadas y recompensas promocionales; ninguna fuente exige una recarga mínima previa para ser utilizable.
12. Las reglas comerciales configurables se congelan mediante snapshots cuando una operación ya ha adquirido efectos.

## 4. Componentes del sistema

### 4.1. TUKTUK Control / Prestador

Es la aplicación actual ampliada con una sección principal **Trabajos**.

Cualquier usuario autenticado puede utilizar Control y Estadísticas permanentemente.

**Trabajos** permite iniciar el alta como conductor. El usuario completa los datos requeridos de conductor, vehículo y fotografías. Cuando el backend determina que el onboarding operativo está completo, consolida su condición de conductor e inicia automáticamente una única promoción comercial inicial con la duración configurada en Gestión Comercial.

No existe un botón independiente para iniciar manualmente la promoción ni una licencia de Control que deba agotarse antes de entrar en Trabajos.

Navegación prevista:

1. Inicio.
2. Registros.
3. Trabajos.
4. Estadísticas.
5. Más.

La sección **Tienda** pasa a **Más → Tienda**; no se elimina ni pierde funciones.

**Trabajos** contiene:

- **Disponibles:** oportunidades compatibles con conductor, vehículo, disponibilidad y reglas de acceso.
- **Activos / Mis trabajos:** trabajo aceptado y flujo operativo actual.
- **Programados:** trabajos aceptados cuya fecha/hora es futura.
- **Historial:** trabajos completados, liquidados, cancelados, expirados o con incidencia.

La aplicación distingue funciones locales de funciones que requieren internet. Sin conexión, Control continúa funcionando y Marketplace queda en lectura cacheada/no actualizada, sin permitir aceptar ni cambiar estados.

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
- Conductor 360 con perfil, vehículos, promoción, billetera, recargas, referidos, trabajos, comisiones, valoraciones, incidencias y auditoría;
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
- Bicicleta.
- Furgoneta.
- Camión.
- Otro.

Los tipos iniciales de propulsión son:

- Eléctrico.
- Combustión.
- Híbrido.
- Humana / sin motor.

La arquitectura conserva ambos como catálogos configurables con códigos estables,
estado y orden de presentación, no como restricciones rígidas dispersas en el
cliente. Así se podrán añadir nuevas categorías o propulsiones sin rediseñar el
modelo ni reescribir reglas históricas. La categoría **Otro** requiere una
descripción operativa y queda sujeta a las mismas capacidades declaradas o
verificadas que cualquier otra.

Ejemplos válidos de combinaciones: Triciclo + Eléctrico, Triciclo + Combustión,
Auto ligero + Combustión, Auto ligero + Eléctrico, Motocicleta + Eléctrico,
Bicicleta + Humana/sin motor, Bicicleta + Eléctrico, Furgoneta + Combustión y
Camión + Combustión.

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
- **Humana / sin motor:** no exige batería de tracción, combustible ni valores eléctricos ficticios; mantiene kilometraje, mantenimiento y los datos operativos que correspondan.

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

El perfil de Trabajos tiene estados operativos propios: **incompleto**, **activo** y **suspendido**.

Un usuario todavía no es conductor operativo mientras su onboarding requerido esté incompleto.

Como mínimo para completar el alta de Trabajos requiere nombre/perfil válido, WhatsApp, foto del conductor, vehículo, categoría, propulsión, marca, modelo, matrícula/identificación cuando aplique, capacidades, servicios habilitados y foto principal del vehículo.

Cuando el backend confirma que los requisitos están completos:

1. consolida la condición de conductor;
2. activa el perfil de Trabajos cuando corresponda;
3. inicia automáticamente y de forma idempotente una única promoción inicial por conductor/proyecto;
4. calcula inicio y fin con tiempo de servidor;
5. congela la duración configurada vigente en Gestión Comercial.

La promoción no depende de la antigüedad de la cuenta ni del uso de Control.

Durante la promoción, un conductor activo y elegible puede aceptar trabajos sin reserva de comisión. Después, puede continuar si su saldo disponible cubre la comisión aplicable.

No existe depósito inicial mínimo obligatorio. Una recarga pagada o una recompensa por referido pueden, por separado o combinadas, proporcionar saldo suficiente.

Una suspensión puede impedir participar en Trabajos, pero no bloquea Control y Estadísticas.

Un conductor es elegible solo si, al consultar y nuevamente al aceptar:

- su identidad y relación con el vehículo están activas;
- su perfil de Trabajos está activo;
- conductor y vehículo están disponibles;
- el tipo de servicio está habilitado;
- la categoría cumple las reglas configurables;
- las capacidades requeridas satisfacen la solicitud;
- no existe un trabajo activo incompatible;
- cumple la política de billetera aplicable cuando la promoción ya terminó;
- no está suspendido ni bloqueado por riesgo u operación.

La validación definitiva ocurre dentro de la transacción de aceptación. La lista vista por el conductor es informativa y puede quedar obsoleta.

La categoría es una señal del motor de elegibilidad, no una regla absoluta. Las reglas pueden combinar servicio, categoría, pasajeros, carga, volumen/dimensiones, carrocería y características solicitadas. Los ejemplos por modalidad orientan configuración, pero no se codifican como límites inamovibles.

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

TUKTUK Cliente debe permitir definir origen y destino mediante búsqueda/mapa y,
cuando el dispositivo lo permita, utilizar ubicación con autorización del usuario.
Si la ubicación no está disponible o no se concede permiso, debe existir selección
manual sin bloquear la solicitud.

La ruta, la distancia y la cotización se obtienen mediante el proveedor de mapas
configurado detrás del gateway/adaptador de Marketplace. La integración vigente
utiliza Mapbox, pero la lógica de negocio no debe depender directamente del token
ni del proveedor: una sustitución futura no debe obligar a reconstruir el flujo.

Antes de publicar, el cliente debe poder revisar la ruta disponible, la distancia
calculada y el precio correspondiente. Si no existe una distancia confiable, la
interfaz debe indicarlo y aplicar un fallback explícito; nunca debe fingir precisión.

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

El primer conductor elegible que confirma obtiene el trabajo. La aceptación se implementa como una única operación transaccional de servidor, conceptualmente `accept_job(job_id, vehicle_id, idempotency_key)`.

Dentro de una transacción corta, la operación debe:

1. autenticar al actor y validar que controla la relación conductor–vehículo;
2. bloquear o actualizar condicionalmente el trabajo solo si continúa publicado, no expiró y no tiene ganador;
3. reevaluar compatibilidad, disponibilidad, estado activo de Trabajos y bloqueos;
4. congelar el modo económico: promoción sin comisión si la promoción estaba activa al aceptar, o `wallet_commission` si ya terminó;
5. en promoción no bloquear billetera ni crear reserva; fuera de promoción comprobar que el saldo disponible cubre la comisión;
6. crear una reserva solo en `wallet_commission`;
7. crear la asignación ganadora con snapshots inmutables, incluida la regla de comisión;
8. actualizar trabajo, disponibilidad y estado a **Aceptado**;
9. añadir el evento auditable;
10. devolver el mismo resultado ante un reintento con la misma clave.

La fuente del saldo no altera la elegibilidad financiera: saldo real y saldo promocional utilizable forman parte del saldo disponible conforme al ledger.

Una restricción única impide más de una asignación ganadora por trabajo y otra impide más de una reserva de comisión activa por trabajo. El cambio condicional de estado y esas restricciones son defensas complementarias.

WhatsApp, push y otros servicios externos se ejecutan después del commit mediante cola/outbox.

### 11.1. Decisión sobre “Reservado” y “Aceptado”

Para el MVP se simplifican como un único estado de negocio: **Aceptado**.

“Reservado” se conserva únicamente como concepto técnico futuro de asignación temporal si se incorpora un flujo de dos pasos. No aparece en la interfaz ni en la máquina de estados actual.

Esta decisión no afecta al **saldo reservado** de la billetera, que es un concepto financiero distinto y sí existe.

## 12. Máquina de estados

### 12.1. Estados canónicos del MVP

| Estado | Significado | Transiciones principales |
|---|---|---|
| Solicitado | Borrador validable aún no visible a conductores | Publicado, Cancelado por cliente |
| Publicado | Disponible para conductores elegibles | Aceptado, Cancelado por cliente, Expirado |
| Aceptado | Conductor asignado; modo económico congelado. Durante promoción no hay reserva; fuera de promoción se reserva comisión | En camino, Cancelado por cliente, Cancelado por conductor, Incidente |
| En camino | Conductor se dirige al origen | Recogida, Cancelado, Incidente |
| Recogida | Llegó o inició la recogida/abordaje | En curso, Cancelado, Incidente |
| En curso | Servicio en ejecución | Completado, Incidente |
| Completado | El conductor finalizó; si fue aceptado bajo promoción no hay comisión, y en wallet_commission el servidor liquida la reserva | Liquidado, Incidente |
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

### 14.1. Modelo comercial vigente

TUKTUK Control y Estadísticas son permanentes para cualquier usuario autenticado.

TUKTUK Trabajos monetiza mediante:

1. una **promoción comercial inicial de X días**;
2. una **billetera**;
3. una **comisión por trabajo** después de la promoción.

No existe plan periódico, renovación ni vencimiento de Control como condición de uso.

La promoción comienza automáticamente cuando el backend valida el onboarding operativo completo. La duración se obtiene de Gestión Comercial, se calcula con tiempo de servidor y queda congelada al inicio.

El nombre técnico `trial_free` puede mantenerse temporalmente para compatibilidad con código y datos existentes, pero representa el modo económico promocional.

### 14.2. Promoción y continuidad

Durante la promoción:

- aceptar no exige saldo;
- no se crea reserva de comisión;
- no se genera deuda retroactiva;
- un trabajo aceptado bajo promoción conserva ese modo aunque la promoción finalice antes de completar el servicio.

Después de la promoción:

- una nueva aceptación usa `wallet_commission`;
- el servidor calcula la comisión aplicable;
- verifica saldo disponible;
- reserva exactamente el importe correspondiente;
- si no alcanza, rechaza únicamente la aceptación y muestra un mensaje comprensible.

No existe depósito inicial mínimo.

El conductor puede recargar antes, durante o después de la promoción. Una recarga no inicia, reinicia, amplía ni termina la promoción.

### 14.3. Fuentes y saldos

La billetera puede recibir:

1. **recargas pagadas y confirmadas** → saldo real;
2. **recompensas por referidos** → saldo promocional;
3. reversos o ajustes autorizados.

Ambos tipos de saldo pueden cubrir comisiones.

Un conductor con saldo pagado cero y saldo promocional suficiente puede aceptar después de la promoción.

Conceptos visibles:

- **Saldo real**.
- **Saldo promocional**.
- **Saldo reservado**.
- **Saldo disponible**.

Los saldos cacheados pueden utilizarse para rendimiento, pero deben reconciliarse con ledger y reservas.

El orden exacto de consumo entre saldo real y promocional se rige por el contrato técnico vigente o por una regla explícitamente aprobada; la interfaz no lo inventa.

### 14.4. Comisión y pago del cliente

En el modelo actual, el cliente paga directamente al conductor por el medio acordado. TUKTUK no procesa el pago del servicio dentro del Marketplace.

La comisión de TUKTUK:

- se configura desde Gestión Comercial;
- se congela mediante snapshot al aceptar el trabajo;
- no se aplica a trabajos aceptados bajo promoción;
- se reserva al aceptar en `wallet_commission`;
- se liquida cuando corresponde al completar/cerrar el trabajo;
- se libera en cancelaciones válidas;
- usa asiento compensatorio si ya existió un débito que debe revertirse.

`job_id` y el tipo de operación utilizan restricciones de unicidad para impedir doble reserva o doble comisión.

### 14.5. Recargas y facturación

Una solicitud de recarga no modifica saldo.

Al confirmar un pago, una única operación transaccional e idempotente debe:

1. confirmar la recarga;
2. acreditar exactamente una vez saldo real;
3. registrar el movimiento de ledger;
4. generar exactamente un documento financiero;
5. registrar actor, referencia y auditoría;
6. actualizar métricas.

El documento conserva número único, conductor, importe, moneda, concepto, método, referencia, fechas, identificador de recarga y snapshot del emisor.

Las correcciones conservan el documento original y utilizan reverso/documento correctivo o nota de crédito cuando corresponda.

Los créditos promocionales por referidos no generan factura de pago porque no representan dinero recibido del conductor.

### 14.6. Referidos

Por cada referido válido que complete su primer trabajo válido, el referente recibe la recompensa configurada en saldo promocional.

Valor inicial de referencia: **100 CUP**, configurable por importe, moneda y activación.

Mientras el programa esté activo no existe un límite de referidos válidos, salvo
que el owner apruebe posteriormente una regla comercial diferente y versionada.

La recompensa:

- se genera exactamente una vez;
- entra mediante ledger como crédito promocional;
- puede cubrir comisiones sin una recarga pagada previa;
- no es retirable ni transferible como efectivo;
- no altera la promoción;
- no genera factura de pago;
- impide autorreferido, duplicaciones y abuso mediante cuentas duplicadas;
- conserva referente, referido, trabajo de cualificación, importe, moneda, versión e idempotencia.

Un primer trabajo válido califica cuando alcanza `settled` o, si pasó por incidencia, cuando la resolución administrativa es `completed`. No califican cancelaciones ni expiraciones.

### 14.7. Inactividad

No habrá desactivación automática por inactividad en el lanzamiento.

Nunca se confisca saldo ni se borra historia. Cualquier política futura requiere aprobación separada y debe considerar oportunidades realmente disponibles para el conductor.

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
| `marketplace_work_trials` | Persistencia técnica de la promoción inicial | Una por conductor/proyecto; inicio automático, duración configurable congelada; nombre técnico heredado permitido temporalmente |
| `job_events` | Historial append-only de transiciones y acciones | Orden por `(job_id, created_at, id)`; no editable por clientes |
| `vehicles` | Proyección relacional canónica para Trabajos usando exactamente el `vehicle_id text` existente; propietario, categoría, propulsión, marca, modelo, año, matrícula/identificación, capacidades, servicios y foto principal | No sustituye `VehicleProfile`/`sync_entities`; el puente legacy actualiza solo campos legacy y nunca borra campos de Trabajos |
| `driver_availability` | Relación conductor–vehículo, disponible/ocupado, ventanas y futura zona | Un estado actual por relación; solapes controlados; las capacidades físicas permanecen en `vehicles` |
| `driver_profiles` | Extensión de Trabajos del perfil autenticado: foto vigente, estado, suspensión y requisitos de activación | Relación 1:1 con `profiles`; WhatsApp permanece canónico en `profiles.phone` y no se duplica |
| `media_assets` | Referencia controlada a fotos de conductor y vehículo, propietario, tipo, estado, versión y metadatos mínimos | Acceso privado y proyecciones autorizadas; no depende indefinidamente de URL externa de Google |
| `wallets` | Billetera por conductor/usuario y moneda en el MVP, saldos cacheados/revisión | Una por `profiles.id` y moneda; no editable desde frontend; propiedad por organización queda para una evolución posterior |
| `wallet_transactions` | Ledger inmutable: recarga, `referral_credit`, comisión, ajuste, reverso; importe firmado y referencia | Claves únicas de idempotencia y origen; nunca hard delete |
| `commission_reservations` | Retención por job, importe, estado abierta/consumida/liberada y expiración | Una reserva canónica por job y wallet |
| `topups` | Solicitud, validación y conciliación de recargas pagadas | Confirmación crea exactamente un crédito real de ledger y un documento financiero |
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

Las licencias existentes de TUKTUK son infraestructura heredada y dejan de formar parte del contrato comercial activo de Control y Trabajos.

No se crea una licencia Marketplace.

Control y Estadísticas no consultan plan, vencimiento ni licencia como condición de acceso.

Antes de eliminar tablas, RPC o campos heredados se deberá:

- inventariar dependencias;
- verificar usuarios y datos reales;
- retirar bloqueos de interfaz/backend;
- migrar o reemplazar referencias necesarias;
- probar que Control y Marketplace siguen funcionando;
- obtener autorización para la eliminación.

Los datos exclusivamente de prueba no requieren migración comercial, pero ninguna limpieza destructiva se ejecutará sin autorización.

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

Toda mutación crítica —publicación, aceptación, transición, cancelación, liquidación,
recarga, recompensa de referido y ajuste— utiliza una `idempotency_key` dentro de
su contrato correspondiente. El servidor guarda actor, operación, hash del payload,
estado y respuesta.

Repetir exactamente una solicitud con la misma clave devuelve el resultado
original y no duplica efectos. Reutilizar la misma clave con un payload diferente
debe rechazarse.

La auditoría registra como mínimo:

- actor y rol efectivo;
- acción y entidad;
- valores anterior y nuevo pertinentes;
- motivo;
- fecha/hora de servidor;
- idempotency key y correlation ID;
- origen;
- resultado.

Los eventos de dominio no reemplazan la auditoría de seguridad y viceversa.

Los procesos de conciliación verifican periódicamente:

- un ganador máximo por trabajo;
- modo promocional: assignment válido, modo económico promocional, cero `commission_reservation` y cero débito de comisión;
- `wallet_commission`: assignment válido, reserva canónica, reserva consumida al liquidar y exactamente un débito de comisión;
- saldos cacheados contra ledger y reservas;
- recargas confirmadas contra créditos reales únicos;
- recompensas de referido contra créditos promocionales únicos;
- documentos financieros contra recargas confirmadas;
- ausencia de integraciones duplicadas.

El nombre técnico `trial_free` puede seguir apareciendo en contratos existentes mientras represente exclusivamente el modo promocional y no una licencia ni una duración fija.

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

## 21. Fases y estado

El Marketplace ya dispone de componentes implementados y algunos desplegados. Este documento no declara por ello que todo TUKTUK 2.0 esté completamente verificado.

### Fase A — Alineación comercial 2.0

- retirar bloqueo de Control por licencia;
- iniciar promoción automáticamente al completar onboarding;
- sustituir duración fija por configuración de Gestión Comercial;
- eliminar el depósito inicial mínimo;
- permitir saldo real o promocional para comisiones;
- integrar referidos con wallet;
- alinear recargas y documentos financieros;
- adaptar mensajes, métricas y Admin.

### Fase B — Marketplace operativo

- TUKTUK Cliente;
- publicación de trabajos;
- cotización;
- filtrado compatible;
- notificaciones;
- aceptación atómica;
- contacto posterior a asignación;
- flujo hasta completado/liquidado;
- valoraciones;
- incidencias;
- wallet/ledger/reservas;
- conciliación.

### Fase C — Integración automática con Control

- creación idempotente de ingreso y kilómetros desde trabajo completado;
- representación contable de comisión sin doble conteo;
- incorporación a estadísticas;
- sincronización incremental compatible con offline-first.

### Fase D — Expansión

- geolocalización y radio/zona;
- empresas y hoteles;
- trabajos recurrentes;
- valoraciones mutuas;
- carga avanzada;
- optimización de precios;
- nuevas modalidades.

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

1. TUKTUK integra Control/Prestador, TUKTUK Cliente y Vrixora Admin.
2. Control y Estadísticas permanecen disponibles sin licencia temporal.
3. Un usuario se convierte en conductor solo al completar el alta de Trabajos.
4. El onboarding exige conductor, vehículo y fotografías conforme al contrato operativo.
5. La promoción inicial comienza automáticamente y una sola vez cuando el backend valida el onboarding completo.
6. La duración promocional es configurable y queda congelada al iniciarse.
7. No existe botón separado para comenzar manualmente una promoción que ya corresponde por alta.
8. No existe depósito inicial mínimo obligatorio.
9. Después de la promoción, saldo real y saldo promocional pueden cubrir comisiones.
10. El saldo de referidos puede ser suficiente por sí solo.
11. La comisión es configurable y se congela al aceptar; el modo promocional no cobra ni genera deuda retroactiva.
12. Wallet y comisión usan ledger/reservas, nunca edición directa de balance.
13. El cliente paga directamente al conductor en el modelo actual; el pago digital del servicio dentro de TUKTUK queda fuera del MVP.
14. Solo conductores compatibles reciben/consultan oportunidades.
15. El primer conductor elegible que confirma gana mediante transacción de servidor.
16. **Reservado** no es un estado durable visible de trabajo; el saldo reservado sí existe.
17. El contacto permanece oculto hasta asignar.
18. No hay chat interno en el MVP.
19. Marketplace requiere conexión; Control conserva su funcionamiento offline.
20. La categoría del vehículo y la propulsión son dimensiones independientes y configurables.
21. La elegibilidad usa capacidades reales y reglas versionadas, no una lista rígida de vehículos.
22. La foto del conductor y la foto principal del vehículo son activos independientes.
23. Las fotos privadas se gestionan mediante almacenamiento controlado y acceso autorizado.
24. TUKTUK Cliente puede recibir después de asignar la proyección autorizada del conductor/vehículo.
25. Las recargas pagadas generan saldo real y documento financiero al confirmarse.
26. Las recompensas por referido generan saldo promocional, no factura de pago.
27. Un referido válido recompensa exactamente una vez al completar su primer trabajo válido.
28. No hay desactivación automática por inactividad en lanzamiento.
29. Las notificaciones reflejan eventos del servidor y nunca cambian el estado por sí mismas.
30. La valoración básica Cliente → Conductor de 1 a 5 estrellas con comentario opcional pertenece al alcance actual.
31. Las licencias y planes heredados no son el modelo comercial vigente de TUKTUK y se retirarán solo después de auditar dependencias.

## 24. Decisiones pendientes

| Decisión | Opciones/impacto | Debe cerrarse antes de |
|---|---|---|
| Evolución del proveedor de mapas/distancia | Mapbox es la integración vigente detrás de un gateway/adaptador; puede sustituirse sin acoplar el negocio | Antes de cambiar proveedor o contrato |
| Configuración comercial inicial | Tarifas, mínimos de servicio, umbrales, comisión y redondeo se administran por configuración | Operación comercial estable |
| Canales/evidencia de recarga | Definir métodos y comprobantes aceptados por operación | Dinero real a escala |
| Orden de consumo de saldos | Saldo real vs promocional; debe respetar contrato técnico aprobado | Cambiar algoritmo de consumo |
| Privacidad y retención | PII, fotos, ubicaciones, notificaciones y auditoría | Operación pública estable |
| SLA de incidentes | Tiempos, escalamiento y cierre | Operación/piloto |
| Verificaciones posteriores | Suspensión/revisión documental | Operación/piloto |
| Política de inactividad futura | No automatizar en lanzamiento | Post-piloto |
| Privacidad de reseñas | Moderación, visibilidad y retención | Publicación ampliada |
| Responsabilidades legales/operativas | Seguros, cargas prohibidas y condiciones | Operación pública |
| Tratamiento fiscal del documento de recarga | Denominación, impuestos y requisitos por jurisdicción | Facturación fiscal formal |

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
- La carrera al iniciar automáticamente la promoción, el intento de reiniciarla, la
  frontera exacta de expiración y la transición del modo promocional → `wallet_commission`
  y confundir promoción comercial con deuda futura requieren pruebas transaccionales.
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
- Promoción, wallet, saldo real, saldo promocional, reserva y comisión pueden confundirse; la interfaz y soporte deben explicar
  estos conceptos por separado.
- Una política de inactividad ciega puede penalizar a conductores sin oportunidades
  compatibles; debe observar oferta real antes de desactivar.
- La recarga podría interpretarse como cuota o cobro del servicio si no se comunica
  claramente como saldo del conductor para futuras comisiones.
- Falta definir responsabilidades legales, privacidad, seguros y artículos/cargas
  prohibidas antes de operación pública.

## 27. Criterios de aceptación del modelo TUKTUK 2.0

El modelo se considera correctamente implementado solo cuando las pruebas estáticas y dinámicas necesarias demuestren:

1. TUKTUK Control conserva todos sus módulos y datos tras actualizar.
2. Control y Estadísticas funcionan sin licencia, plan o vencimiento.
3. Inicio, Registros, Trabajos, Estadísticas y Más funcionan en los anchos soportados.
4. Un usuario con onboarding incompleto no es tratado como conductor operativo.
5. Completar conductor + vehículo + fotos inicia automáticamente una sola promoción con tiempo de servidor.
6. La duración de esa promoción procede de Gestión Comercial y queda congelada.
7. Reintentos, reinstalación y cambios de vehículo no reinician la promoción.
8. Durante promoción, aceptar no crea reserva ni exige saldo.
9. Un trabajo aceptado bajo promoción termina sin comisión aunque la promoción venza después.
10. Fuera de promoción, `wallet_commission` calcula la comisión configurada y exige solo saldo disponible suficiente.
11. No existe depósito inicial mínimo obligatorio.
12. Saldo procedente únicamente de referidos puede cubrir una comisión.
13. Una recarga pagada puede cubrir una comisión aunque no exista saldo promocional.
14. Saldo insuficiente bloquea únicamente la nueva aceptación que requiere comisión, no Control.
15. Suspendido no acepta trabajos, pero sigue pudiendo usar Control y Estadísticas.
16. Una solicitud de recarga pendiente no altera el saldo.
17. Confirmar una recarga acredita exactamente una vez saldo real y genera exactamente un documento financiero.
18. Un crédito de referido acredita exactamente una vez saldo promocional y no genera factura de pago.
19. Un referido solo cualifica por primer trabajo válido y no por instalación, registro u onboarding.
20. Dos o más aceptaciones concurrentes producen exactamente un ganador.
21. Repetir una aceptación con la misma idempotency key no duplica asignación, reserva, evento ni débito.
22. Una cancelación válida libera reserva; una corrección posterior usa asiento compensatorio.
23. Cada transición acepta solo actor y estado permitidos y genera evento append-only con tiempo de servidor.
24. Antes de asignar no se expone WhatsApp ni PII innecesaria.
25. Después de asignar solo las partes autorizadas obtienen contactos y proyección permitida.
26. RLS y grants impiden lectura cruzada; ningún frontend contiene `service_role`.
27. RPC privilegiadas validan identidad, fijan `search_path` y tienen permisos mínimos.
28. Listados usan índices y cursores y cumplen objetivos acordados de rendimiento.
29. Una caída o duplicación de push no altera asignación ni dinero.
30. Sin internet, Marketplace bloquea mutaciones mientras Control local continúa.
31. Reintentos con red inestable reutilizan la misma clave y no duplican efectos.
32. Ningún respaldo o restauración local modifica jobs, wallet, ledger o estados remotos.
33. Vrixora Admin puede localizar trabajos, conductores, reservas, recargas, documentos e incidentes con permisos.
34. La conciliación detecta diferencias entre trabajo, assignment, reserva, ledger, saldo y documentos.
35. Se ejecutan análisis estático, unitarias, integración RLS/RPC, concurrencia, offline y compilaciones necesarias antes de declarar cierre.
36. Existe rollback que no destruye datos financieros ni datos locales.
37. Categoría y propulsión permanecen independientes y configurables, incluyendo Bicicleta y propulsión Humana/sin motor sin exigir datos eléctricos ficticios.
38. El motor de elegibilidad evalúa capacidades y requisitos reales.
39. La propulsión adapta interfaz, validaciones, registros y estadísticas sin inventar valores eléctricos.
40. La foto de Google puede iniciar la foto del conductor, pero el sistema no depende permanentemente de su URL externa.
41. Foto de conductor y vehículo permanecen independientes.
42. La valoración Cliente → Conductor es única por trabajo válido y auditable.
43. Las notificaciones de estado nunca constituyen autoridad para cambiar el trabajo.
44. La política de inactividad conserva saldo, datos e historial.
45. Las referencias a licencias/planes heredados no pueden bloquear Control ni Trabajo bajo el nuevo contrato.
46. TUKTUK Cliente obtiene ruta/distancia mediante el proveedor de mapas configurado, conserva fallback manual y no acopla la lógica de negocio al token del proveedor.
47. Una repetición exacta con la misma idempotency key devuelve el resultado original y la misma clave con payload diferente es rechazada.

## 28. Condición de cierre documental y paso a implementación

Esta versión 2.0 queda documentalmente cerrada cuando:

- el owner aprueba el modelo;
- PRD Maestro, Centro de Control y Marketplace no se contradicen;
- el estado real de código/backend se audita contra este contrato;
- se identifica qué partes ya están implementadas, cuáles requieren adaptación y cuáles siguen pendientes;
- cualquier migración o retirada de legado tiene un plan incremental y reversible.

La aprobación de este documento no autoriza por sí sola:

- migraciones remotas;
- eliminación de tablas o datos;
- merge a `main`;
- despliegues;
- publicación Android/Web;
- cambios de secretos;
- cambios de firma;
- cambios de `google-services`.

Cada operación de implementación o producción requiere su verificación y autorización correspondiente.
