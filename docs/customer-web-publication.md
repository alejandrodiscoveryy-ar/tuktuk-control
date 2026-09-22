# Publicación de TUKTUK Cliente mediante el Worker de Cloudflare

## Estado comprobado

- El 22 de septiembre de 2026, `https://www.vrixora.com/tuktuk/app/` respondió `200` a través de Cloudflare.
- En esa misma comprobación, `https://www.vrixora.com/cliente/tuk/` respondió `404`; no hubo redirección.
- La evidencia operativa del proyecto identifica el Worker actual como `tuktuk-webapp` y asocia `www.vrixora.com/tuktuk/app/*` a ese Worker.
- No hay configuración versionada del Worker ni de sus Assets en este repositorio. Los detalles remotos —binding de Assets, regla SPA, directorio de empaquetado y orden de rutas— siguen pendientes de verificación en la configuración de `tuktuk-webapp`; este documento no los inventa.

## Generación de paquetes

Desde `flutter_app`, ejecute uno de estos comandos:

```powershell
.\tool\build_web.ps1
.\tool\build_customer_web.ps1
```

El build de prestadores conserva `build/web` y el `base href` `/tuktuk/app/`.
El build de clientes queda en `build/customer-web` y usa `/cliente/tuk/`.
No se deben intercambiar esos directorios al preparar una publicación.

## Topología de Worker que se debe preparar

Prepare un único directorio de publicación con estas dos raíces, sin mover
la segunda bajo `/tuktuk`:

```text
<directorio-de-publicacion>/
├── tuktuk/app/       # contenido de build/web
└── cliente/tuk/      # contenido de build/customer-web
```

`tuktuk-webapp` debe conservar la ruta actual:

```text
www.vrixora.com/tuktuk/app/*
```

Sin desplegar ni crear todavía la ruta, deberá prepararse una segunda asociación
al mismo Worker:

```text
www.vrixora.com/cliente/tuk/*
```

El paquete de publicación podrá contener ambas raíces. La implementación remota
debe servir los archivos existentes antes de cualquier fallback SPA, para que
`flutter_bootstrap.js`, `main.dart.js`, `canvaskit/`, `assets/`,
`manifest.json`, iconos y los service workers se sirvan directamente desde
`/cliente/tuk/`.

No cree ninguna regla de redirección hacia `/tuktuk/`. La ruta del cliente
debe servirse directamente y permanece fuera del App Link Android `/tuktuk`;
este cambio no modifica
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
