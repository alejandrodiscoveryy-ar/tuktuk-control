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
