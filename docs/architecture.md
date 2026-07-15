# Arquitectura evolutiva

## Fases implementadas

La aplicación sigue siendo local y personal. La Fase 1 divide el código en
módulos de una misma biblioteca Dart mediante `part`. La Fase 2 añade identidad
de propietario, vehículo y estado de sincronización con lectura compatible de
los esquemas anteriores.

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
siguiente fase añadirá onboarding visible y administración del primer vehículo.

Google Drive continuará siendo un servicio de respaldo y restauración, no la
base de datos principal.
