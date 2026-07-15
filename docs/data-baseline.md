# Línea base de datos — Fase 0

Fecha de verificación: 2026-07-15

Esta línea base protege la migración futura de los datos históricos que aún
están incrustados en el código. No sustituye el respaldo JSON exportado desde
la aplicación del usuario.

## Datos históricos incrustados

| Métrica | Valor |
|---|---:|
| Registros iniciales | 97 |
| Ingresos acumulados | 377,920 CUP |
| Eventos de carga hasta 80 V | 40 |
| Odómetro máximo | 3,980 km |
| Mantenimientos iniciales | 1 |
| Odómetro del mantenimiento inicial | 526 km |
| Próximo mantenimiento calculado | 5,526 km |

## Integridad de los archivos previos

- SHA-256 de `flutter_app/lib/main.dart` antes de la Fase 1:
  `ECC3F00F23CE142EA4C96FC8CE592DC988F94FB454C5029060C78E2E024CF9FB`
- SHA-256 del respaldo fuente local:
  `38451498C8F107F1BE960DF2DA362E042EDE2B36DFBA793784A6038EA297C4D0`

El respaldo fuente permanece en `backups/`, fuera de Git. No debe eliminarse
hasta completar y verificar la migración de propietario y vehículo.

## Condiciones de aceptación para migraciones futuras

1. Conservar los 97 registros y el mantenimiento inicial.
2. Conservar identificadores, fechas, importes, odómetros y cargas.
3. Mantener eliminaciones lógicas y metadatos de sincronización existentes.
4. Asociar los datos a un único `userId` y `vehicleId` del propietario.
5. Verificar nuevamente las métricas anteriores antes de retirar los datos del
   código.
6. Probar restauración desde un respaldo JSON real antes de distribuir la
   aplicación a otros usuarios.
