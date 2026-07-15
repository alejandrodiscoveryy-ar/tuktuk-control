# Migración de esquema 3: propietario y vehículo

## Objetivo

Incorporar identidad de propietario, vehículo y estado de sincronización sin
eliminar ni reinterpretar datos existentes.

## Campos añadidos

Todos los registros diarios y mantenimientos incluyen:

- `userId`
- `vehicleId`
- `syncStatus`

El esquema también incorpora `VehicleProfile` como representación mínima del
primer vehículo.

## Compatibilidad

Los mapas de esquemas anteriores siguen siendo legibles. Si faltan los campos
nuevos, la migración conserva el identificador, fechas, valores, notas,
`createdAt`, `updatedAt`, `deletedAt` y `deviceId`, y completa únicamente la
identidad ausente.

## Asignación de los datos existentes

1. Antes de iniciar sesión, los datos existentes reciben una identidad local
   estable vinculada al dispositivo.
2. La primera cuenta Google autorizada reclama esa identidad local.
3. Todos los datos históricos se asocian a esa cuenta y a su vehículo
   principal.
4. La asociación queda registrada en `claimedUserId`.
5. Una cuenta Google diferente no puede reclamar, restaurar ni respaldar ese
   mismo espacio local.

## Instalaciones nuevas

Una base completamente nueva no ejecuta la carga de los datos históricos
incrustados. Comienza sin registros y crea únicamente el perfil técnico de su
primer vehículo cuando se establece el usuario.

Los datos históricos permanecen temporalmente en `seed_data.dart` como recurso
de recuperación del propietario. Se retirarán del código solamente después de
probar un respaldo JSON real y confirmar la migración completa.

## Respaldo

El manifiesto de Google Drive incluye `ownerUserId` y `vehicleId`. La
restauración rechaza un manifiesto o registro cuyo propietario no coincide con
la cuenta activa. Drive sigue siendo respaldo y restauración, no base de datos
principal.
