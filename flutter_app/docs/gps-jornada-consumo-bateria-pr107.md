# GPS de jornada — revisión energética del PR #107

## Alcance y estado

Auditoría **estática** del seguimiento Android de conductores; no equivale a una medición de consumo real.
El PR permanece en una rama de prueba. No implica despliegue a Play Store.

## Configuración auditada

| Estado | Configuración | Impacto esperado |
| --- | --- | --- |
| Descansar, sin carrera | No publicar GPS operativo | No consume batería por el seguimiento operativo de jornada |
| Trabajar, disponible | Geolocator Android `medium`, intervalo 60 s, umbral de envío 75 m, heartbeat 120 s | Menor frecuencia que durante la carrera, pero uso sostenido de ubicación y red |
| Carrera activa | `high`, intervalo 15 s, umbral de envío 15 m, heartbeat 30 s | Precisión superior a costa de mayor consumo |
| Disponible | `enableWakeLock: false` | Evita solicitar un bloqueo de activación adicional para esta modalidad |
| Carrera activa | `enableWakeLock: true` | Prioriza la continuidad durante el servicio; revisar el impacto medido |
| Pantalla bloqueada | Servicio de ubicación Android visible | Está preparado para continuar; debe verificarse en cada dispositivo |

## Riesgos y observaciones

1. El `distanceFilter` del modo disponible es 0 para permitir que lleguen eventos incluso sin desplazamiento; esto favorece la frescura, pero puede mantener trabajo periódico del proveedor de ubicación.
2. La aplicación puede enviar aproximadamente 30 heartbeats por hora en espera, frente a los 15 por hora de la configuración anterior, siempre que el stream entregue posiciones y la red permita enviarlas. Son **frecuencias teóricas**, no mediciones.
3. Los intervalos solicitados al sistema no garantizan frecuencia exacta: Android, batería adaptable, permisos, cobertura y fabricante pueden retrasar entregas.
4. Nunca se debe mostrar una coordenada antigua como si fuera actual ni contabilizar una repetición sin GPS fresco como posición nueva.
5. No prometer seguimiento después de que el usuario fuerce la detención de la aplicación o desactive permisos de ubicación.
6. El cierre de la ventana de Flutter que posee la suscripción detiene el stream; comprobar rutas y ciclos de vida con pruebas físicas.
7. Si conviven la notificación del botón flotante y la del GPS, revisar experiencia y consumo de ambos servicios Android.

## Ajustes preparados para la siguiente revision (sin APK)

- En Android disponible, intervalo GPS 60 s y heartbeat 120 s (antes 45/90). Admin considera fresca una posicion disponible hasta unos 300 s; este ajuste conserva margen, pero la bateria y la disponibilidad deben validarse en un telefono real.
- No publicar fixes GPS con marcas de tiempo antiguas (>120 s disponible o >45 s con carrera), ni adelantadas mas de 5 s.
- Al detectar GPS desactivado o un stream interrumpido, reintentar con backoff solo en primer plano; al reabrir la app, reanudar. Android puede impedir iniciar un nuevo FGS de ubicacion desde segundo plano, por lo que no se promete recuperacion autonoma en ese estado.
- La frecuencia de eventos del proveedor y los heartbeats publicados no son iguales: las cifras por hora son estimaciones, no mediciones energeticas.

## Protocolo reproducible de batería (prueba física pendiente)

1. Instalar la APK firmada de **este commit** del PR, sin publicarla en Play Store.
2. Desactivar carga eléctrica (si se usa ADB, conectar por Wi-Fi o registrar el porcentaje a mano), mantener brillo/volumen, cobertura, trayecto y resto de apps lo más constantes posible.
3. Medir un escenario de referencia `Descansar` durante un tramo de 45–60 min.
4. Medir `Trabajar` con pantalla bloqueada durante otro tramo de 45–60 min.
5. Medir con carrera activa en una ruta comparable, sin crear viajes de producción no autorizados.
6. Registrar porcentaje de batería inicial/final, temperatura, duración, modelo, versión Android, estado de ahorro de batería y número/frescura de posiciones que Admin recibe.
7. Comparar caída porcentual por hora entre los escenarios. Si el equipo carga o los periodos son muy cortos, declarar la medición no concluyente.
8. Comprobar en Admin que las ubicaciones antiguas no se presenten como actuales y que al pulsar `Descansar` deje de circular GPS operativo.

El uso de `adb shell dumpsys battery` y `adb shell dumpsys batterystats --charged com.alejandrocruz.tuktukcontrol` permite capturar evidencia local; los contadores acumulados de `batterystats` **no** deben interpretarse como consumo exclusivo del periodo si no se aísla el intervalo. Evitar borrar estadísticas de batería del usuario. Referencias: Android Developers, `Optimize location use for battery life` y `dumpsys` (https://developer.android.com/develop/sensors-and-location/location/battery/optimize; https://developer.android.com/tools/dumpsys).

## Criterio de aceptación antes de integrar

- CI `flutter analyze` y `flutter test` correctas después del commit de limpieza.
- Ensayo con pantalla bloqueada, minimizada y cambios de pestaña exitoso.
- Al pulsar `Descansar`, no quedan envíos operativos indebidos.
- Consumo y temperatura aceptables frente al escenario de referencia en el dispositivo de prueba.
- Revisar consumo de datos y el comportamiento con cobertura intermitente en Cuba.
- Mantener `main`, Supabase, Cliente, Admin y Play Store inalterados durante la prueba.
