# Publicación de TUKTUK Cliente en Cloudflare Pages

## Estado comprobado

- La metadata local de Wrangler identifica el proyecto Pages `vrixora-digital-solutions`.
- El 22 de septiembre de 2026, `https://www.vrixora.com/tuktuk/app/` respondió `200` a través de Cloudflare.
- En esa misma comprobación, `https://www.vrixora.com/cliente/tuk/` respondió `404`; no hubo redirección.
- No hay configuración versionada de Worker ni de Assets en este repositorio que permita atribuir la ruta actual a un Worker concreto. La configuración debe conservar Pages como fuente de los archivos estáticos, salvo que el owner confirme otra topología desde el panel de Cloudflare.

## Generación de paquetes

Desde `flutter_app`, ejecute uno de estos comandos:

```powershell
.\tool\build_web.ps1
.\tool\build_customer_web.ps1
```

El build de prestadores conserva `build/web` y el `base href` `/tuktuk/app/`.
El build de clientes queda en `build/customer-web` y usa `/cliente/tuk/`.
No se deben intercambiar esos directorios al preparar una publicación.

## Configuración de Pages requerida

Prepare un único directorio de publicación con estas dos raíces, sin mover
la segunda bajo `/tuktuk`:

```text
<directorio-de-publicacion>/
├── tuktuk/app/       # contenido de build/web
└── cliente/tuk/      # contenido de build/customer-web
```

En el proyecto Pages `vrixora-digital-solutions`, publique ese directorio y
configure una regla SPA específica:

```text
/cliente/tuk/*  /cliente/tuk/index.html  200
```

Los archivos existentes deben prevalecer sobre ese fallback, para que
`flutter_bootstrap.js`, `main.dart.js`, `canvaskit/`, `assets/`,
`manifest.json`, iconos y los service workers se sirvan directamente desde
`/cliente/tuk/`.

No cree ninguna regla de redirección hacia `/tuktuk/`. La ruta del cliente
permanece fuera del App Link Android `/tuktuk`; este cambio no modifica
`AndroidManifest.xml`.

## PWA y scopes

El manifiesto y los service workers usan rutas relativas y el build inserta
`<base href="/cliente/tuk/">`. Por tanto, el service worker registrado desde
`/cliente/tuk/firebase-messaging-sw.js` queda limitado al scope
`/cliente/tuk/`; no puede controlar `/tuktuk/app/`. El build de prestadores
mantiene análogamente el scope `/tuktuk/app/`.

Antes de un despliegue autorizado, verificar en un entorno de preview que la
respuesta de `/cliente/tuk/` sea `200` sin `Location`, que sus recursos se
resuelvan bajo `/cliente/tuk/`, y que DevTools > Application muestre scopes
separados para ambas WebApps.
