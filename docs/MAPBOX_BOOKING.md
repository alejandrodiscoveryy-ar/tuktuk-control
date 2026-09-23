# Solicitud Marketplace con Mapbox

La WebApp cliente usa `flutter_map` para mostrar tiles Mapbox. El token público
se inyecta en la compilación con `MAPBOX_PUBLIC_TOKEN`; nunca se guarda en Git.
El script `flutter_app/tool/build_customer_web.ps1` lee esa variable y genera
`flutter_app/build/customer-web` con base `/cliente/tuk/`.

El cliente envía búsqueda, geocodificación inversa, ruta y creación de solicitud
a `marketplace-map-gateway`. El secreto `MAPBOX_SERVER_TOKEN` y el secreto HMAC
`MARKETPLACE_ROUTE_SIGNING_SECRET` se configuran solo en el entorno de la Edge
Function. La ruta se consulta una vez por pareja origen/destino; los cambios de
opciones usan `price_quote` con la distancia firmada. La función SQL de preview
reutiliza el motor de precios de creación y no escribe datos.

Para una prueba local con Mapbox real hacen falta:

1. Aplicar la nueva migración al Supabase **local/de prueba** con las tarifas
   activas aprobadas, sin tocar producción.
2. Configurar `MAPBOX_SERVER_TOKEN`, `MARKETPLACE_ROUTE_SIGNING_SECRET` y el
   secreto existente `MARKETPLACE_RATE_LIMIT_SECRET` solo en ese entorno.
3. Configurar `MAPBOX_PUBLIC_TOKEN` restringido al dominio o aplicación de
   prueba antes de compilar el cliente.
4. Servir localmente ambas Edge Functions y verificar búsqueda, GPS denegado,
   ruta, precios y confirmación desde navegador móvil y escritorio.
5. Ejecutar `supabase/verification/20260922_customer_mapbox_quote.sql` del
   backend contra la base de prueba para comprobar 3900 CUP a 9 km en Pasajeros
   y 800 CUP a 3 km en Mensajería.

Las funciones esenciales de TukTuk Control conservan su almacenamiento y
sincronización existentes. Crear solicitudes Marketplace requiere conexión.
