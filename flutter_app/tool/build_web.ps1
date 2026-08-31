$ErrorActionPreference = 'Stop'

Push-Location (Join-Path $PSScriptRoot '..')
try {
  dart run tool/sync_project_branding.dart --web
  if ($LASTEXITCODE -ne 0) {
    throw "La sincronización de identidad terminó con código $LASTEXITCODE."
  }

  flutter build web --release --base-href "/tuktuk/app/"
  if ($LASTEXITCODE -ne 0) {
    throw "La compilación web terminó con código $LASTEXITCODE."
  }
} finally {
  Pop-Location
}
