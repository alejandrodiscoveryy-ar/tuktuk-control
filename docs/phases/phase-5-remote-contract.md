# Fase 5: contrato remoto neutral

## Objetivo

Definir cómo la aplicación enviará y recibirá cambios sin acoplar el dominio a
Firebase, Supabase u otro proveedor. Esta fase no transmite datos por red: deja
el punto de integración preparado y comprobado.

## Contrato del gateway

`RemoteSyncGateway` expone dos operaciones:

- `push`: envía un lote de operaciones locales y devuelve cuáles fueron
  aceptadas y cuáles rechazadas;
- `pull`: solicita cambios remotos de un usuario desde un cursor y devuelve el
  próximo cursor.

El gateway también declara si está configurado. Cuando no lo está, el
coordinador no toca la cola y reporta que la sincronización fue omitida.

## Lotes y reintentos

El coordinador procesa como máximo 50 operaciones por ejecución, salvo que el
llamador indique otro límite. Las operaciones aceptadas se eliminan de la cola.
Las rechazadas permanecen pendientes, incrementan su contador de intentos y
guardan el último error. Si falla todo el envío, el lote completo permanece
pendiente con el error registrado.

## Resolución determinista de conflictos

La política compara candidatos locales y remotos en este orden:

1. gana el cambio con `updatedAt` más reciente;
2. con la misma fecha, una eliminación gana sobre una actualización;
3. si todavía hay empate, gana el identificador de dispositivo
   lexicográficamente mayor.

La última regla evita resultados diferentes cuando dos clientes procesan el
mismo conflicto. Un proveedor futuro podrá aplicar esta política tanto al
descargar cambios como en pruebas de integración.

## Seguridad requerida para la integración

El proveedor remoto deberá validar la identidad en el servidor y limitar cada
lectura o escritura al `userId` autenticado y a vehículos autorizados. El
cliente no debe considerarse una frontera de seguridad. También será necesario
almacenar el cursor por usuario y probar que dos cuentas no puedan compartir
datos accidentalmente.

## Alcance actual

- no se eligió ni configuró un proveedor remoto;
- no se añadieron credenciales ni variables de entorno;
- Google Drive continúa siendo únicamente respaldo y restauración;
- la lógica visible y los datos históricos de la aplicación no cambian.
