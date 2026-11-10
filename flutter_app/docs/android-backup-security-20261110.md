# Seguridad local: respaldos Android — TUKTUK Conductor

## Riesgo y alcance

La aplicación usa cajas Hive para registros de jornada, mantenimiento, cola de
sincronización y metadatos, incluidos identificadores o tokens de notificaciones.
La inicialización actual no configura cifrado de esas cajas. Android permite por
defecto que datos privados entren en copias automáticas y transferencias a otro
dispositivo, según versión y fabricante.

## Endurecimiento propuesto

- `android:allowBackup="false"` impide la copia automática habitual.
- Android 11 y anteriores: `fullBackupContent` excluye datos privados.
- Android 12+: `dataExtractionRules` excluye explícitamente datos privados de
  la copia en nube y de la transferencia entre dispositivos.
- No afecta el inicio de sesión, GPS, carreras, mensajería, claxon o servicios remotos.
- No cifra aún las cajas existentes ni borra datos instalados.
- La exportación y restauración MANUAL de respaldos JSON/CSV en la aplicación
  permanece disponible. No confundir con respaldo automático del sistema Android.

## Impacto de producto que debe aprobar el propietario

Al reinstalar o cambiar de teléfono, los datos exclusivamente locales ya no
se restaurarán automáticamente por Android. El conductor necesitará iniciar
sesión y recuperar lo sincronizado, o usar un respaldo manual válido para
información que solo esté en el dispositivo. Verificar funcionamiento real en
una futura compilación APK autorizada antes de su distribución.

## Evidencia

Guía oficial Android:
https://developer.android.com/identity/data/autobackup

La protección de la copia de seguridad NO sustituye una futura migración de
almacenamiento sensible hacia cifrado y gestión segura de claves en Android.
