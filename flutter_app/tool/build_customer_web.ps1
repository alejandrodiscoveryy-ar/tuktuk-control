$ErrorActionPreference = 'Stop'

Push-Location (Join-Path $PSScriptRoot '..')
try {
  dart run tool/sync_project_branding.dart --web
  if ($LASTEXITCODE -ne 0) {
    throw "La sincronización de identidad terminó con código $LASTEXITCODE."
  }

  # Keep this package distinct from the provider build in build/web.
  $mapboxArgs = @()
  if ($env:MAPBOX_PUBLIC_TOKEN) {
    $mapboxArgs += "--dart-define=MAPBOX_PUBLIC_TOKEN=$($env:MAPBOX_PUBLIC_TOKEN)"
  }
  flutter build web --release --base-href "/cliente/tuk/" --output build/customer-web @mapboxArgs
  if ($LASTEXITCODE -ne 0) {
    throw "La compilación web del cliente terminó con código $LASTEXITCODE."
  }

  Write-Host "Artefacto Web de clientes: $((Join-Path (Get-Location) 'build/customer-web'))"
  Write-Host 'No publique este directorio sobre /tuktuk/app/.'
} finally {
  Pop-Location
}
