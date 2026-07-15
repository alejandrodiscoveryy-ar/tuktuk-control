# Arquitectura evolutiva

## Fases implementadas

La aplicación sigue siendo local y personal. La Fase 1 divide el código en
módulos de una misma biblioteca Dart mediante `part`. La Fase 2 añade identidad
de propietario, vehículo y estado de sincronización con lectura compatible de
los esquemas anteriores. La Fase 3 incorpora onboarding para instalaciones
nuevas y administración básica del vehículo activo.

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

La separación con `part` es transitoria. Los módulos se convertirán en
bibliotecas independientes con repositorios e interfaces desacopladas. La
siguiente fase separará repositorios e introducirá una cola explícita de
operaciones pendientes antes de conectar una base remota.

Google Drive continuará siendo un servicio de respaldo y restauración, no la
base de datos principal.
