# Directriz permanente de TukTuk Control

## Objetivo de capacidad

TukTuk Control debe soportar inicialmente entre 500 y 1.000 usuarios
activos sin necesidad de rediseñar la arquitectura. Toda implementación debe
facilitar el crecimiento progresivo por encima de 1.000 usuarios activos.

## Reglas obligatorias

- Mantener una arquitectura modular, desacoplada y fácil de mantener.
- Evitar soluciones temporales o específicas para un solo caso de uso.
- Diseñar la base de datos y las consultas para soportar al menos 1.000
  usuarios activos con buen rendimiento.
- Optimizar las sincronizaciones para transferir únicamente los cambios
  necesarios.
- Minimizar el consumo de memoria, CPU, batería y tráfico de red.
- Evitar duplicación de código y reutilizar componentes y servicios existentes.
- Mantener compatibilidad con Hive, Supabase, Google Sign-In, respaldos y
  versiones anteriores.
- Diseñar cada nueva funcionalidad para que pueda ampliarse sin modificar la
  arquitectura principal.
- Utilizar índices y consultas eficientes en Supabase cuando sea necesario.
- Preparar la aplicación para soportar múltiples vehículos por usuario y
  futuras funcionalidades sin cambios estructurales importantes.
- No introducir dependencias innecesarias ni aumentar la complejidad sin una
  justificación técnica.
- Antes de finalizar cualquier tarea, verificar que el cambio no afecte
  negativamente el rendimiento, la seguridad, la escalabilidad ni la
  mantenibilidad.
- Si existe una solución más escalable con un costo de implementación
  razonable, priorizar esa solución.
- Si una solicitud compromete la escalabilidad, explicar el problema y proponer
  una alternativa antes de implementarla.

## Criterio de finalización

Ningún cambio se considera terminado hasta revisar su impacto en rendimiento,
seguridad, escalabilidad, mantenibilidad, compatibilidad offline y
sincronización incremental.

# Instrucciones para agentes — TukTuk Control

## Fuente oficial de requisitos

Antes de analizar, modificar o implementar cualquier función, leer:

- `docs/PRD_MASTER.md`
- `docs/architecture.md`
- `docs/data-baseline.md`
- la documentación relevante dentro de `docs/phases/` y `docs/migrations/`

`docs/PRD_MASTER.md` es una copia sincronizada de referencia.

La fuente oficial del PRD está en:

`vrixora-admin-canvas/docs/PRD_MASTER.md`

No editar directamente la copia del PRD en este repositorio. Cuando cambie la fuente oficial, sincronizar esta copia.

## Alcance de este repositorio

Este repositorio corresponde a TukTuk Control, la aplicación utilizada por propietarios y conductores de triciclos.

Su alcance incluye:

- autenticación con Google;
- perfil del usuario;
- vehículos;
- registros diarios;
- ingresos;
- gastos y categorías;
- kilometraje;
- voltaje de batería;
- mantenimiento;
- estadísticas;
- funcionamiento sin conexión;
- almacenamiento local;
- sincronización con Supabase;
- licencia del cliente;
- prueba inicial;
- referidos;
- soporte;
- contacto para pago o renovación;
- compilación Android;
- actualizaciones sin pérdida de datos.

No implementar aquí funciones administrativas que pertenecen al Centro de Control, como:

- gestión de empleados;
- creación de planes;
- registro administrativo de pagos;
- generación administrativa de recibos;
- ajuste manual de vigencias;
- cambio manual de estados de licencias;
- auditoría administrativa completa;
- configuración de roles y permisos del personal.

## Reglas de producto obligatorias

- Cada usuario debe tener una sola licencia por aplicación.
- Al registrarse por primera vez recibe una prueba de 30 días.
- Cuando compra un plan, se actualiza la misma licencia.
- La primera compra sustituye la prueba y no acumula los días restantes de prueba.
- Una renovación pagada activa conserva los días restantes.
- Una licencia vencida inicia desde la confirmación del nuevo pago.
- El estado vencido debe derivarse de la fecha y no seleccionarse manualmente.
- La aplicación debe conservar datos locales durante actualizaciones.
- Las funciones esenciales deben seguir disponibles sin conexión.
- La sincronización no debe crear duplicados ni borrar datos válidos.
- El frontend no debe usar `service_role`.

## WhatsApp y soporte

TukTuk Control debe diferenciar dos vías:

1. Atención al cliente.
2. Pagar, activar o renovar.

Aunque ambas puedan utilizar el mismo número, deben generar mensajes distintos.

El mensaje de pago o renovación debe incluir automáticamente:

- nombre;
- correo;
- licencia;
- aplicación;
- plan actual;
- plan solicitado, cuando corresponda;
- vencimiento;
- tipo de solicitud.

El número y las plantillas deben obtenerse de la configuración remota del proyecto y conservarse localmente para funcionar sin conexión.

No implementar identificación automática del número del cliente mediante la API de WhatsApp en la primera versión.

## Criterio para considerar una función implementada

No considerar una función terminada únicamente porque exista una pantalla, un botón o porque el proyecto compile.

Verificar, cuando corresponda:

- interfaz;
- lógica;
- almacenamiento local;
- backend;
- tablas;
- migraciones;
- RPC;
- RLS;
- sincronización;
- manejo sin conexión;
- permisos;
- pruebas;
- compilación;
- funcionamiento real en un dispositivo.

## Funciones existentes no documentadas

Si existe una función que no aparece en el PRD:

1. No eliminarla ni modificarla automáticamente.
2. Documentar qué hace y dónde está.
3. Identificar dependencias, datos, permisos y pruebas.
4. Clasificarla como necesaria, técnica, posiblemente obsoleta, contradictoria o no verificable.
5. Solicitar decisión del owner antes de cambiarla.

## Seguridad y datos

- No borrar bases de datos locales durante actualizaciones.
- No eliminar historial de usuario sin autorización.
- No desactivar RLS.
- No exponer secretos ni claves.
- No usar `service_role` en la aplicación.
- Evitar operaciones duplicadas.
- Mantener compatibilidad con datos existentes y migraciones previas.
- No modificar datos reales durante pruebas sin autorización expresa.

## Forma de trabajo

Antes de modificar código:

1. Ejecutar `git status`.
2. Confirmar la rama.
3. Revisar el PRD y la documentación relacionada.
4. Identificar archivos, modelos y servicios afectados.
5. Explicar cualquier contradicción con el PRD.
6. Trabajar en una rama, salvo instrucción expresa distinta.
7. No reescribir historial publicado.
8. No hacer force push.
9. No desplegar ni publicar sin autorización.

Después de una implementación relevante:

- ejecutar análisis estático;
- ejecutar pruebas;
- compilar;
- revisar funcionamiento sin conexión cuando corresponda;
- informar archivos modificados;
- informar riesgos;
- informar rama, commit y Pull Request.
