param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('apk', 'appbundle')]
  [string]$Target
)

$ErrorActionPreference = 'Stop'

Push-Location (Join-Path $PSScriptRoot '..')
try {
  dart run tool/sync_project_branding.dart --android
  if ($LASTEXITCODE -ne 0) {
    throw "La sincronización de identidad Android terminó con código $LASTEXITCODE."
  }

  if ($Target -eq 'apk') {
    flutter build apk --release
  } else {
    flutter build appbundle --release
  }
  if ($LASTEXITCODE -ne 0) {
    throw "La compilación Android terminó con código $LASTEXITCODE."
  }
} finally {
  Pop-Location
}
