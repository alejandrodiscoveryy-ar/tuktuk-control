# Registros personales de TukTuk Conductor: no borrar en limpiezas de Trabajo

Alcance: correccion del bucle de sincronizacion y proteccion de datos historicos.

- Los ingresos/gastos/odometros introducidos manualmente pertenecen al usuario y no forman parte de las pruebas de Trabajo.
- Una limpieza de pruebas SOLO puede actuar sobre ingresos de `dailyRecord` cuyo `entity_id` comienza `marketplace-job-` y cuyo trabajo este explicitamente verificado como prueba eliminada; la falta de fila de servidor no implica prueba eliminada.
- En `sync_entities` no se permiten limpiezas masivas por tipo `dailyRecord` ni operaciones que mezclen registros manuales con automaticos.
- Antes de cualquier cambio remoto de datos se exige conteo, respaldo, filtro por propietario/proyecto y verificacion del resultado.
- La sincronizacion sin novedades no debe volver a programar una nueva sincronizacion por su propio recalculo.
- Una PR o un build sin errores no significan que el comportamiento en web o Android este validado.

Entrega de esta rama: ajustar solo recalculo de odometros automaticos cuando hay diferencias reales, con pruebas. Sin migraciones, sin cambio de APK, sin desplegar en produccion.
