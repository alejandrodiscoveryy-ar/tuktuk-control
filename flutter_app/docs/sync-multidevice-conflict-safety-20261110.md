# Revisión de conflictos de sincronización entre dispositivos

## Por qué es necesario

La importación de `sync_entities` comparaba marcas de tiempo y podía
sustituir un registro local pendiente al recibir una versión más reciente
de otro dispositivo, retirando además su operación de la cola. Esto podía
perder una edición sin que el conductor lo supiera.

## Comportamiento propuesto (PR de revisión)

- Si el mismo registro tiene cambios locales pendientes y también se modificó
  desde otro dispositivo de la misma cuenta, se interrumpe esa importación
  sin sobrescribir el registro local ni borrar la operación pendiente.
- La versión remota sigue almacenada en Supabase, sin ninguna mutación.
- El conductor ve un mensaje de conflicto distinto de un fallo de internet.
- Se recomienda exportar respaldo JSON antes de cualquier resolución.
- No se crean registros duplicados ni se modifican ingresos de carreras.
- No se cambia la estructura de la base de datos ni los datos existentes.

## Limitaciones y condición de cierre

Este PR es un cortafuegos conservador, **no un sistema completo de resolución
de conflictos**. Si ocurre un conflicto real, la sincronización de la cuenta
quedará detenida hasta una resolución controlada. Antes de publicar, se
debe definir y probar una interfaz que permita comparar dos versiones y elegir
cuál conservar o fusionar, sin perder la otra.

No integra PR #118 de respaldo Android. No modifica APK, servidores o datos.
