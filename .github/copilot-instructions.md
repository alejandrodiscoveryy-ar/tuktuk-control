# Instrucciones de Copilot — TukTuk Control

Antes de analizar, proponer o modificar código, leer:

- `AGENTS.md`
- `docs/PRD_MASTER.md`
- `docs/architecture.md`
- `docs/data-baseline.md`

La fuente oficial del PRD se encuentra en:

`vrixora-admin-canvas/docs/PRD_MASTER.md`

La copia de este repositorio es solo una referencia sincronizada y no debe editarse directamente.

## Alcance

Este repositorio corresponde a TukTuk Control e incluye:

- Flutter y Dart;
- autenticación con Google;
- perfiles y vehículos;
- ingresos y gastos;
- kilometraje;
- voltaje de batería;
- mantenimiento;
- estadísticas;
- almacenamiento local;
- funcionamiento sin conexión;
- sincronización con Supabase;
- licencias;
- prueba inicial de 30 días;
- referidos;
- soporte;
- contacto para pago o renovación;
- compilación y publicación Android.

No implementar aquí funciones administrativas pertenecientes al Centro de Control, como gestión de empleados, creación de planes, registro administrativo de pagos, recibos, auditoría general o ajustes manuales de licencias.

## Reglas obligatorias

- Cada usuario tendrá una sola licencia por aplicación.
- El primer registro genera una prueba de 30 días.
- La primera compra sustituye la prueba sin acumular los días restantes.
- Una renovación pagada activa conserva los días restantes.
- Una licencia vencida comienza desde la confirmación del nuevo pago.
- Las actualizaciones no deben eliminar los datos locales.
- El modo sin conexión debe seguir funcionando para las operaciones esenciales.
- La sincronización no debe generar duplicados.
- No utilizar `service_role` en el frontend.
- No desactivar RLS.
- No modificar datos reales sin autorización.

## WhatsApp

Diferenciar:

1. Atención al cliente.
2. Pagar, activar o renovar.

Aunque utilicen el mismo número, deben generar mensajes distintos.

El mensaje de pago debe incluir automáticamente:

- nombre;
- correo;
- licencia;
- aplicación;
- plan actual;
- plan solicitado;
- vencimiento;
- tipo de solicitud.

El número y las plantillas deben obtenerse de la configuración remota y conservarse localmente para funcionar sin conexión.

## Forma de trabajo

Antes de modificar código:

1. Ejecutar `git status`.
2. Confirmar la rama.
3. Leer el PRD y la documentación relacionada.
4. Identificar el impacto en almacenamiento local, backend y sincronización.
5. Documentar cualquier contradicción con el PRD.
6. Trabajar en una rama.
7. No hacer `force push`.
8. No desplegar ni publicar sin autorización.

No considerar una función terminada solo porque exista una pantalla o porque compile.

Verificar cuando corresponda:

- interfaz;
- lógica;
- almacenamiento local;
- backend;
- migraciones;
- RPC;
- RLS;
- permisos;
- sincronización;
- funcionamiento sin conexión;
- pruebas;
- compilación;
- dispositivo real.
