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

  # IDENTIDAD_CLIENTE_PWA
  # El cliente comparte fuentes web con el conductor.
  # Ajustar solo el artefacto generado, nunca el manifest fuente.
  $clienteOutput = Join-Path (Get-Location) "build/customer-web"
  $manifestPath = Join-Path $clienteOutput "manifest.json"
  $indexPath = Join-Path $clienteOutput "index.html"

  if (-not (Test-Path $manifestPath) -or -not (Test-Path $indexPath)) {
    throw "Faltan recursos web del cliente."
  }

  $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
  $manifest.name = "TukTuk Cliente"
  $manifest.short_name = "TukTuk Cliente"

  $utf8Cliente = New-Object System.Text.UTF8Encoding($false)

  $jsonCliente = $manifest | ConvertTo-Json -Depth 30
  [IO.File]::WriteAllText($manifestPath, $jsonCliente, $utf8Cliente)

  $indexCliente = [IO.File]::ReadAllText($indexPath)

  if (-not $indexCliente.Contains("<title>TukTuk Conductor</title>")) {
    throw "Titulo HTML inesperado en build de cliente."
  }

  $indexCliente = $indexCliente.Replace(
    "<title>TukTuk Conductor</title>",
    "<title>TukTuk Cliente</title>"
  )

  $indexCliente = $indexCliente.Replace(
    'content="TukTuk Conductor"',
    'content="TukTuk Cliente"'
  )

  [IO.File]::WriteAllText($indexPath, $indexCliente, $utf8Cliente)

  Write-Host "IDENTIDAD_CLIENTE_PWA=OK"
  Write-Host "Artefacto Web de clientes: $((Join-Path (Get-Location) 'build/customer-web'))"
  Write-Host 'No publique este directorio sobre /tuktuk/app/.'
} finally {
  Pop-Location
}
