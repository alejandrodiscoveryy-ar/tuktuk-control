# Arquitectura evolutiva

## Fases implementadas

La aplicación sigue siendo local y personal. La Fase 1 divide el código en
módulos de una misma biblioteca Dart mediante `part`. La Fase 2 añade identidad
de propietario, vehículo y estado de sincronización con lectura compatible de
los esquemas anteriores. La Fase 3 incorpora onboarding para instalaciones
nuevas y administración básica del vehículo activo. La Fase 4 añade una cola
local de operaciones para preparar sincronización offline-first. La Fase 5
define el contrato del servicio remoto, el procesamiento por lotes y una regla
determinista para resolver conflictos, sin elegir todavía un proveedor. La
Fase 6 añade contratos neutrales de membresía, roles, planes y aislamiento por
usuario, vehículo y organización.

```text
lib/
|-- main.dart
|-- data/
|   |-- record_store.dart
|   |-- sync_queue.dart
|   `-- seed_data.dart
|-- domain/
|   |-- access.dart
|   |-- entities.dart
|   |-- metrics.dart
|   `-- sync.dart
|-- services/
|   `-- sync_coordinator.dart
`-- presentation/
    |-- screens.dart
    `-- widgets.dart
```

## Límites de responsabilidad

- `domain/entities.dart`: estructuras persistidas y serialización.
- `domain/access.dart`: roles, membresías, planes y políticas de autorización.
- `domain/metrics.dart`: cálculos derivados de los registros.
- `data/record_store.dart`: Hive, migraciones y respaldo actual en Drive.
- `data/sync_queue.dart`: persistencia y estado de operaciones pendientes.
- `data/seed_data.dart`: datos históricos temporales pendientes de migración.
- `domain/sync.dart`: contratos remotos y política de conflictos.
- `services/sync_coordinator.dart`: envío por lotes y actualización de la cola.
- `presentation/screens.dart`: navegación, pantallas y formularios.
- `presentation/widgets.dart`: componentes visuales reutilizables.
- `main.dart`: arranque, tema y composición principal.

## Próximas fases

La separación con `part` es transitoria. Los módulos se convertirán en
bibliotecas independientes con repositorios e interfaces desacopladas. La
siguiente fase podrá evaluar e integrar un proveedor remoto concreto. Antes de
activarlo deberá reproducir y reforzar estas políticas en el servidor, añadir
cursores de descarga persistentes y superar pruebas de aislamiento de datos.

Google Drive continuará siendo un servicio de respaldo y restauración, no la
base de datos principal.
