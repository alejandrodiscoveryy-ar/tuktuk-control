# Seguridad de copias Android — TUKTUK Conductor

## Alcance

TUKTUK conserva registros de jornada, mantenimiento, cola de sincronización y
metadatos en cajas Hive. La inicialización actual no cifra esas cajas. Las
copias automáticas de Android pueden trasladar datos privados sin que el
usuario los sincronice con su cuenta.

## Protección propuesta

- Manifest: `android:allowBackup="false"`.
- Android 11 o anterior: `fullBackupContent` excluye los dominios privados.
- Android 12 o posterior: `dataExtractionRules` excluye esos dominios tanto
  del respaldo de nube como de la transferencia directa entre móviles.
- Se enumeran de forma explícita los dominios `root`, `file`, `database`,
  `sharedpref`, `device_root`, `device_file`, `device_database`,
  `device_sharedpref` y `external`, como defensa en profundidad.
- No modifica ni elimina cajas Hive de instalaciones existentes; no altera
  red, GPS, carreras, mensajes, claxon o servicios remotos.
- La exportación y restauración *manual* de respaldos en la aplicación siguen
  disponibles. La exportación JSON contiene información potencialmente
  sensible y debe guardarse en un lugar seguro.

## Consecuencias para el conductor

Al reinstalar o cambiar de móvil ya no puede depender de la restauración
**automática de Android** para datos que nunca llegaron al servidor. Debe
iniciar sesión y recuperar datos sincronizados; si aún tiene datos locales
sin sincronizar, debe conservar el dispositivo original y sincronizar primero
cuando recupere internet. Una restauración por JSON requiere un respaldo válido.

## Evidencia y límites de verificación

- La WebApp ya superó una prueba manual de guardar sin conexión, sincronizar
  al reconectar y recuperar datos con la misma cuenta en otro entorno.
- Estas pruebas **no verifican** reglas de backup integradas en el APK de
  Android ni restauración del almacenamiento nativo Hive.
- Antes de distribuir una nueva APK, se requiere una compilación autorizada
  de prueba, revisión del Manifest fusionado y prueba en Android real de
  actualización sin pérdida de datos y recuperación con Google.
- `allowBackup=false` por sí solo no desactiva todas las transferencias
  directas en todos los dispositivos Android 12+; por eso se definen reglas
  específicas para transferencia y nube.
- La exclusión de respaldos no cifra el almacenamiento en uso ni impide el
  acceso físico al dispositivo desbloqueado. El cifrado seguro debe
  analizarse por separado con un plan de migración compatible.
- Para transferencias cruzadas Android/iOS de versiones recientes, revisar
  reglas dedicadas si se desarrolla una aplicación iOS; no está habilitada
  ni verificada como funcionalidad de este producto.

Documentación oficial: https://developer.android.com/identity/data/autobackup
