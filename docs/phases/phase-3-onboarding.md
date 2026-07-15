# Fase 3: onboarding y vehículo activo

## Comportamiento para instalaciones nuevas

Una instalación sin datos ni vehículo muestra una pantalla de bienvenida antes
del dashboard. El usuario configura:

- nombre del vehículo;
- matrícula o identificador opcional;
- lectura actual del odómetro opcional.

Si proporciona un odómetro mayor que cero, se crea un registro inicial de cero
ingresos asociado al usuario y al vehículo. No se cargan datos históricos del
propietario original.

El usuario puede iniciar sesión con Google antes de configurar el vehículo o
trabajar primero con una identidad local. La arquitectura conserva el enfoque
offline-first.

## Comportamiento para instalaciones existentes

Los datos migrados en el esquema 3 ya tienen vehículo principal. Esas
instalaciones entran directamente al dashboard y no vuelven a ver el
onboarding.

## Administración básica

La sección Usuario permite editar el nombre y la matrícula del vehículo activo.
El identificador interno no se puede editar para evitar romper asociaciones con
registros existentes.

## Respaldo

El perfil del vehículo se incorpora al manifiesto de Google Drive. Al restaurar:

1. se valida que el propietario coincida con la cuenta activa;
2. se conserva la versión local más reciente comparando `updatedAt`;
3. se restauran nombre, matrícula y odómetro inicial;
4. no se acepta un vehículo perteneciente a otra cuenta.

## Alcance pendiente

Esta fase administra un solo vehículo activo. Múltiples vehículos, selección de
vehículo, conductores y organizaciones pertenecen a fases posteriores.
