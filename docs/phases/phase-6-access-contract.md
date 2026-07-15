# Fase 6: autorización y capacidades SaaS

## Objetivo

Preparar las reglas de acceso y los límites comerciales futuros sin activar
organizaciones, pagos o suscripciones en la experiencia personal actual.

## Roles preparados

- `owner`: propietario de sus datos y vehículos;
- `driver`: accede únicamente a los vehículos que le fueron asignados dentro
  de su organización;
- `organizationAdmin`: administra recursos de su propia organización;
- `platformAdmin`: rol reservado para administración futura de la plataforma.

Una membresía puede estar invitada, activa o suspendida. Solo las membresías
activas obtienen acceso.

## Aislamiento

La política comprueba identidad, vehículo asignado y organización. Un usuario
propietario accede a sus propios recursos. Un conductor no puede cambiar de
vehículo ni de organización por modificar solamente un identificador local.

Estas reglas del cliente sirven para navegación, presentación y pruebas, pero
no son una frontera de seguridad. El proveedor remoto deberá volver a validar
cada operación con la identidad autenticada y políticas ejecutadas en el
servidor. El rol `platformAdmin` nunca debe concederse desde el dispositivo.

## Planes y capacidades

Se preparan los planes `free`, `professional` y `business`, junto con
capacidades independientes: operación offline, sincronización, reportes
avanzados y administración de organizaciones. También se admiten límites de
vehículos y fecha de vencimiento.

El plan gratuito predeterminado permite un vehículo y operación offline. Esta
estructura todavía no bloquea pantallas ni crea cobros; solo establece un
contrato comprobable para fases posteriores.

## Compatibilidad

- no se modifica el esquema Hive ni los registros existentes;
- no se crean usuarios, organizaciones o suscripciones reales;
- no se añaden dependencias, credenciales ni servicios externos;
- la aplicación personal continúa funcionando con el mismo comportamiento.
