# TukTuk Control

App Flutter para registrar jornadas diarias de un Tuk Tuk y calcular dashboard, historial, ciclos y estadisticas mensuales desde los registros reales.

## Funciones

- Inicio de sesion con Google.
- Guardado local con Hive.
- Sincronizacion/restauracion de la base de datos con Google Drive `appDataFolder`.
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

## Importante para Google Sign-In

Configura Google Cloud para Android con el paquete `com.example.control_tuk_tuk` y registra el SHA-1 de la firma de debug o release.
Si decides usar Firebase para manejar esa configuracion, coloca el `google-services.json` en `android/app/`.

La app usa el alcance privado `drive.appdata`: cada usuario guarda su propio respaldo en Google Drive, oculto dentro del espacio de datos de la app. Al reinstalar e iniciar sesion con el mismo Google, la app recupera y mezcla la base local con la copia de Drive.

El respaldo incluye registros activos y eliminados logicamente. Esto evita que un dato borrado vuelva a aparecer despues de sincronizar otro dispositivo.

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
