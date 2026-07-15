# TukTuk Control

Aplicación para registrar la operación diaria de un Tuk Tuk: ganancias,
odómetro, ciclos de carga, mantenimientos, historial y estadísticas. El
repositorio incluye la aplicación Flutter y una vista web de referencia usada
para validar la experiencia y los cálculos.

## Estado del proyecto

- Aplicación principal: Flutter para Android y web.
- Persistencia local: Hive.
- Inicio de sesión: Google.
- Respaldo por usuario: Google Drive `appDataFolder`.
- Vista web de referencia: HTML, CSS y JavaScript sin dependencias externas.
- Registros asociados a propietario y vehículo desde el esquema local 3.

## Requisitos

- [Git](https://git-scm.com/downloads).
- [Flutter](https://docs.flutter.dev/get-started/install) compatible con Dart
  3.4 o superior.
- Android Studio o Android SDK para compilar la aplicación Android.
- Un navegador moderno para ejecutar Flutter Web o la vista de referencia.
- Node.js es opcional y solo se utiliza para servir `web_preview/` localmente.

Comprueba la instalación de Flutter con:

```bash
flutter doctor
```

## Instalación

Clona el repositorio y descarga las dependencias:

```bash
git clone https://github.com/alejandrodiscoveryy-ar/tuktuk-control.git
cd tuktuk-control/flutter_app
flutter pub get
```

No copies las carpetas generadas (`build`, `.dart_tool`) desde otra
computadora. Flutter las reconstruye automáticamente.

## Ejecución

### Aplicación Flutter

Lista los dispositivos disponibles y ejecuta la aplicación:

```bash
flutter devices
flutter run
```

Para ejecutarla en un navegador:

```bash
flutter run -d chrome
```

Para generar un APK o un Android App Bundle de producción:

```bash
flutter build apk --release
flutter build appbundle --release
```

Los archivos generados quedan dentro de `flutter_app/build/` y no se guardan
en Git.

### Vista web de referencia

Desde la raíz del repositorio:

```bash
node web_preview/serve-preview.cjs
```

Después abre `http://127.0.0.1:8090/`.

## Configuración y credenciales

El repositorio no requiere variables de entorno para ejecutar su estado
actual. Los archivos `.env`, certificados, claves de firma y credenciales de
Google están excluidos mediante `.gitignore`.

Para usar Google Sign-In y Google Drive en Android, cada desarrollador debe:

1. Configurar un proyecto en Google Cloud para el paquete
   `com.example.control_tuk_tuk`.
2. Registrar el SHA-1 correspondiente a su firma de desarrollo o producción.
3. Si utiliza Firebase, colocar su propio `google-services.json` en
   `flutter_app/android/app/`.
4. Mantener las claves de firma y `key.properties` fuera del repositorio.

Nunca confirmes en Git archivos `.env`, claves privadas, certificados,
`google-services.json`, `key.properties`, APK o AAB.

## Estructura

```text
tuktuk-control/
|-- flutter_app/        Aplicación principal Flutter
|   |-- android/        Configuración de Android
|   |-- lib/            Código Dart modular de la aplicación
|   |-- test/           Pruebas de dominio e integridad de datos
|   `-- web/            Archivos base de Flutter Web
|-- web_preview/        Referencia web funcional y servidor local
|-- docs/               Arquitectura y líneas base de migración
|-- backups/            Respaldos locales ignorados por Git
|-- .gitignore          Exclusiones de seguridad y archivos generados
`-- README.md           Documentación del proyecto
```

## Comprobaciones recomendadas

Antes de compartir cambios:

```bash
cd flutter_app
flutter pub get
flutter analyze
flutter test
```

Las pruebas actuales verifican serialización, borrado lógico y cálculos de
métricas. Consulta también [la arquitectura evolutiva](docs/architecture.md) y
[la línea base de datos](docs/data-baseline.md) antes de modificar modelos o
migraciones. La asignación inicial de propietario y vehículo está documentada
en [la migración del esquema 3](docs/migrations/schema-v3.md).

## Flujo de actualización

Descarga los cambios más recientes antes de comenzar:

```bash
git switch main
git pull --ff-only
```

Trabaja en una rama descriptiva:

```bash
git switch -c feature/nombre-del-cambio
```

Guarda y publica el trabajo:

```bash
git add <archivos>
git commit -m "Descripción breve del cambio"
git push -u origin feature/nombre-del-cambio
```

Después crea un Pull Request en GitHub para integrar la rama en `main`.

## Protección de datos

- Los datos operativos permanecen locales y pueden respaldarse en el espacio
  privado `appDataFolder` de Google Drive.
- Cada registro debe conservar `ownerUserId` para evitar cruces entre usuarios.
- Antes de cambios grandes, exporta los datos de la aplicación y conserva un
  respaldo fuera del repositorio.
- La carpeta local `backups/` no se sube a GitHub y no debe eliminarse sin una
  verificación manual.

## Licencia

Proyecto privado. No se concede permiso de distribución o reutilización fuera
de los colaboradores autorizados.
