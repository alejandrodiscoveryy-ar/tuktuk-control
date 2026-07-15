# Arquitectura evolutiva

## Fase actual

La aplicación sigue siendo local y personal. La Fase 1 divide el código en
módulos de una misma biblioteca Dart mediante `part`. Esta técnica conserva el
comportamiento y el acceso a símbolos privados mientras reduce el riesgo del
primer cambio estructural.

```text
lib/
|-- main.dart
|-- data/
|   |-- record_store.dart
|   `-- seed_data.dart
|-- domain/
|   |-- entities.dart
|   `-- metrics.dart
`-- presentation/
    |-- screens.dart
    `-- widgets.dart
```

## Límites de responsabilidad

- `domain/entities.dart`: estructuras persistidas y serialización.
- `domain/metrics.dart`: cálculos derivados de los registros.
- `data/record_store.dart`: Hive, migraciones y respaldo actual en Drive.
- `data/seed_data.dart`: datos históricos temporales pendientes de migración.
- `presentation/screens.dart`: navegación, pantallas y formularios.
- `presentation/widgets.dart`: componentes visuales reutilizables.
- `main.dart`: arranque, tema y composición principal.

## Próximas fases

La separación con `part` es transitoria. Después de añadir `userId` y
`vehicleId` mediante una migración verificada, los módulos se convertirán en
bibliotecas independientes con repositorios e interfaces desacopladas.

Google Drive continuará siendo un servicio de respaldo y restauración, no la
base de datos principal.
