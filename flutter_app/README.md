# TukTuk Control

App Flutter para registrar jornadas diarias de un Tuk Tuk y calcular dashboard, historial, ciclos y estadisticas mensuales desde los registros reales.

## Funciones

- Inicio de sesion con Google.
- Guardado local con Hive.
- Funcionamiento offline con cola local de cambios pendientes.
- Sincronizacion y recuperacion de datos con Supabase al restablecerse la conexion.
- Dashboard con ganancia, odometro, ciclos y actividad reciente.
- Registro diario.
- Historial editable y eliminable.
- Estadisticas mensuales y por ciclo.
- Eventos de carga hasta 80 V.
- Mantenimiento general cada 5,000 km por defecto, calculado desde el ultimo mantenimiento registrado.
- Registro editable de mantenimientos con costo opcional.
- Salud de datos para detectar odometros faltantes o lecturas que bajan.
- Base robusta con cajas separadas para registros diarios y mantenimientos.
- Versionado de esquema, identificador de dispositivo y borrado logico con `deletedAt`.
- Sincronizacion por mezcla usando `updatedAt`, para evitar pisar datos mas nuevos.

## Importante para Google Sign-In y Firebase

Configura Google Cloud para Android con el paquete `com.alejandrocruz.tuktukcontrol` y registra el SHA-1 de la firma de debug o release.
Coloca la configuracion Firebase correspondiente en `android/app/google-services.json` y mantenla fuera del repositorio.

La autenticacion con Google se realiza mediante Supabase Auth. Los datos se conservan localmente en Hive; cada cambio pendiente permanece en una cola offline y se sincroniza con Supabase. Si la conexion falla, la app mantiene los datos locales y reintenta la sincronizacion posteriormente.

La sincronizacion incluye registros activos y eliminados logicamente para evitar que un dato borrado vuelva a aparecer al combinar cambios.

## Compilar APK

Con Flutter instalado:

```bash
flutter pub get
flutter build apk --release
```

El APK quedara en:

```text
build/app/outputs/flutter-apk/app-release.apk
```
