# Fase 4: cola local offline-first

## Objetivo

Registrar cada cambio local como una operación pendiente independiente del
respaldo de Google Drive. Esta cola será la entrada de una futura sincronización
con una base remota SaaS.

## Operaciones cubiertas

- crear o actualizar un registro diario;
- eliminar lógicamente un registro diario;
- crear, actualizar o eliminar un mantenimiento;
- crear o editar el vehículo activo;
- modificar ajustes de mantenimiento;
- restaurar entidades desde un respaldo.

Cada operación conserva:

- tipo e identificador de entidad;
- acción `upsert` o `delete`;
- `userId` y `vehicleId`;
- fecha de creación y actualización;
- número de intentos y último error, preparados para la fase remota.

## Consolidación

La cola utiliza una clave estable por entidad. Varias ediciones del mismo
registro se consolidan en una sola operación. Una eliminación posterior
reemplaza la actualización pendiente sin perder la fecha original de entrada a
la cola.

## Migración de identidad

Si el usuario comienza localmente y después enlaza Google, las operaciones
pendientes cambian de propietario junto con los registros. Los identificadores
de entidad permanecen intactos.

## Separación de responsabilidades

Google Drive continúa respaldando y restaurando archivos. Completar un respaldo
no vacía la cola ni marca entidades como sincronizadas con la futura base SaaS.
La cola se procesará únicamente cuando exista un servicio remoto con reglas de
autorización por usuario y vehículo.

## Persistencia

La caja Hive `sync_queue` se crea junto con las demás cajas locales. Al actualizar
una instalación existente, se genera una operación inicial por entidad para que
los datos históricos puedan enviarse posteriormente a la base remota.
