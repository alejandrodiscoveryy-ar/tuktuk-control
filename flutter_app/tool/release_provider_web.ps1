$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$flutter = Join-Path $repo "flutter_app"

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"

$registrantRepo =
    "flutter_app/android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java"

function Restore-WebGeneratedAndroidResidue {
    Set-Location $repo

    git restore --source=HEAD --worktree -- $registrantRepo

    if ($LASTEXITCODE -ne 0) {
        throw "STOP: no se pudo restaurar GeneratedPluginRegistrant."
    }

    Set-Location $flutter
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "TUKTUK PRESTADOR - RELEASE OFICIAL" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Set-Location $repo

git fetch origin
if ($LASTEXITCODE -ne 0) {
    throw "STOP: git fetch fallo."
}

if (@(git status --porcelain).Count -ne 0) {
    git status --short
    throw "STOP: el repositorio no esta limpio."
}

$head = (git rev-parse HEAD).Trim()
$remoteMain = (git rev-parse origin/main).Trim()

if ($head -ne $remoteMain) {
    throw "STOP: el codigo local no coincide con GitHub main. HEAD=$head MAIN=$remoteMain"
}

git diff --check
if ($LASTEXITCODE -ne 0) {
    throw "STOP: git diff --check fallo."
}

Set-Location $flutter

Write-Host "`n=== IDENTIDAD WEB ===" -ForegroundColor Cyan

dart run tool/sync_project_branding.dart --web
if ($LASTEXITCODE -ne 0) {
    throw "STOP: sincronizacion de identidad fallo."
}

Set-Location $repo

if (@(git status --porcelain).Count -ne 0) {
    git status --short
    throw "STOP: identidad Web genero cambios no guardados en GitHub."
}

Set-Location $flutter

Write-Host "`n=== FLUTTER ANALYZE ===" -ForegroundColor Cyan

flutter analyze --no-fatal-infos
if ($LASTEXITCODE -ne 0) {
    throw "STOP: flutter analyze fallo."
}

Write-Host "`n=== FLUTTER TEST ===" -ForegroundColor Cyan

flutter test
if ($LASTEXITCODE -ne 0) {
    throw "STOP: flutter test fallo."
}

# Flutter puede regenerar este archivo Android incluso en trabajo Web.
# Como esta entrega no modifica APK, siempre se restaura desde Git.
Restore-WebGeneratedAndroidResidue

Set-Location $repo

if (@(git status --porcelain).Count -ne 0) {
    git status --short
    throw "STOP: las pruebas dejaron cambios inesperados."
}

Set-Location $flutter

$buildDir =
    Join-Path $env:TEMP "tuktuk-provider-build-$stamp"

$stage =
    Join-Path $env:TEMP "tuktuk-provider-stage-$stamp"

$stageApp =
    Join-Path $stage "tuktuk\app"

if (Test-Path $buildDir) {
    Remove-Item $buildDir -Recurse -Force
}

if (Test-Path $stage) {
    Remove-Item $stage -Recurse -Force
}

Write-Host "`n=== BUILD PRODUCTIVO ===" -ForegroundColor Cyan

flutter build web `
    --release `
    --base-href "/tuktuk/app/" `
    --output "$buildDir" `
    --no-tree-shake-icons

if ($LASTEXITCODE -ne 0) {
    throw "STOP: build productivo fallo."
}

Restore-WebGeneratedAndroidResidue

Set-Location $repo

if (@(git status --porcelain).Count -ne 0) {
    git status --short
    throw "STOP: el build dejo cambios inesperados."
}

$localJs = Join-Path $buildDir "main.dart.js"

if (-not (Test-Path $localJs)) {
    throw "STOP: main.dart.js no existe en el build."
}

$localHash =
    (Get-FileHash $localJs -Algorithm SHA256).Hash

New-Item `
    -ItemType Directory `
    -Force `
    -Path $stageApp |
    Out-Null

Copy-Item `
    "$buildDir\*" `
    $stageApp `
    -Recurse `
    -Force

Write-Host "`n=== CLOUDFLARE DEPLOY ===" -ForegroundColor Cyan

Set-Location $flutter

$deployOutput = @(
    npx.cmd --yes wrangler@4.115.0 deploy `
        --name "tuktuk-webapp" `
        --assets "$stage" `
        --route "www.vrixora.com/tuktuk/app/*" `
        --compatibility-date 2026-09-22 `
        --keep-vars 2>&1
)

$deployExit = $LASTEXITCODE

$deployOutput | ForEach-Object {
    Write-Host $_
}

if ($deployExit -ne 0) {
    throw "STOP: Cloudflare deploy fallo."
}

$deployText = $deployOutput | Out-String
$versionId = "NO_CAPTURADO"

if ($deployText -match 'Current Version ID:\s*([0-9a-fA-F-]+)') {
    $versionId = $Matches[1]
}
elseif ($deployText -match 'Version ID:\s*([0-9a-fA-F-]+)') {
    $versionId = $Matches[1]
}

Write-Host "`n=== VERIFICACION PRODUCCION ===" -ForegroundColor Cyan

$homeUrl =
    "https://www.vrixora.com/tuktuk/app/?release=$stamp"

$jsUrl =
    "https://www.vrixora.com/tuktuk/app/main.dart.js?release=$stamp"

$homeResponse = Invoke-WebRequest `
    -Uri $homeUrl `
    -Headers @{ "Cache-Control" = "no-cache" } `
    -UseBasicParsing `
    -TimeoutSec 30 `
    -ErrorAction Stop

if ($homeResponse.StatusCode -ne 200) {
    throw "STOP: la pagina productiva no devuelve HTTP 200."
}

$remoteFile =
    Join-Path $env:TEMP "tuktuk-provider-main-$stamp.dart.js"

Invoke-WebRequest `
    -Uri $jsUrl `
    -Headers @{ "Cache-Control" = "no-cache" } `
    -UseBasicParsing `
    -TimeoutSec 90 `
    -OutFile $remoteFile `
    -ErrorAction Stop

$remoteHash =
    (Get-FileHash $remoteFile -Algorithm SHA256).Hash

if ($localHash -ne $remoteHash) {
    throw "STOP: hash remoto distinto al build local. LOCAL=$localHash REMOTO=$remoteHash"
}

Set-Location $repo

$releaseTag = "provider-web-$stamp"

git tag `
    -a $releaseTag `
    $head `
    -m "TUKTUK Provider Web | Cloudflare $versionId | SHA256 $remoteHash"

if ($LASTEXITCODE -eq 0) {
    git push origin $releaseTag

    if ($LASTEXITCODE -ne 0) {
        Write-Host "RELEASE_TAG=PUSH_FALLO" -ForegroundColor Yellow
    }
    else {
        Write-Host "RELEASE_TAG=$releaseTag" -ForegroundColor Green
    }
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "TUKTUK PRODUCCION VERIFICADA" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "URL=https://www.vrixora.com/tuktuk/app/"
Write-Host "GITHUB_COMMIT=$head"
Write-Host "CLOUDFLARE_VERSION=$versionId"
Write-Host "HTTP=200"
Write-Host "LOCAL_SHA256=$localHash"
Write-Host "REMOTE_SHA256=$remoteHash"
Write-Host "HASH_LOCAL_REMOTO=IGUAL"
Write-Host "APK=NO_MODIFICADA"
Write-Host "========================================" -ForegroundColor Green