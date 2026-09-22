<#
.SYNOPSIS
    Inicialización automatizada de la infraestructura de geocodificación local.
.DESCRIPTION
    Verifica dependencias del sistema, prepara directorios de persistencia,
    descarga el extracto vectorial OSM y despliega el contenedor con Docker Compose.
#>

[CmdletBinding()]
param (
    [string]$EnvFile = "../.env"
)

# 1. Validación de Docker CLI
try {
    $dockerVersion = docker --version
    Write-Host "[OK] Docker detectado: $dockerVersion" -ForegroundColor Green
} catch {
    Write-Error "ERROR TÉCNICO: Docker no está reconocido en el PATH. Inicia Docker Desktop o verifica tu instalación de WSL 2."
    exit 1
}

# 2. Carga y parseo de variables de entorno
$dataDir = Join-Path $PSScriptRoot "..\data"
if (!(Test-Path $dataDir)) {
    New-Item -ItemType Directory -Force -Path $dataDir | Out-Null
    Write-Host "[OK] Directorio de datos creado en: $dataDir" -ForegroundColor Cyan
}

$envPath = Join-Path $PSScriptRoot $EnvFile
if (!(Test-Path $envPath)) {
    $examplePath = Join-Path $PSScriptRoot "../.env.example"
    Copy-Item $examplePath $envPath
    Write-Host "[WARN] .env no encontrado. Se generó a partir de .env.example" -ForegroundColor Yellow
}

# Leer parámetros
Get-Content $envPath | ForEach-Object {
    if ($_ -match "^\s*([^#][^=]+)=(.*)$") {
        [System.Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim(), [System.EnvironmentVariableTarget]::Process)
    }
}

$pbfUrl = [System.Environment]::GetEnvironmentVariable("OSM_PBF_URL")
$pbfFileName = [System.Environment]::GetEnvironmentVariable("PBF_FILENAME")
$targetPbf = Join-Path $dataDir $pbfFileName

# 3. Descarga controlada de datos vectoriales si no existen en almacenamiento local
if (!(Test-Path $targetPbf)) {
    Write-Host "[INFO] Descargando extracto cartográfico: $pbfUrl..." -ForegroundColor Cyan
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    # Descarga binaria nativa
    Invoke-WebRequest -Uri $pbfUrl -OutFile $targetPbf -UseBasicParsing
    
    $stopwatch.Stop()
    $sizeMB = (Get-Item $targetPbf).Length / 1MB
    Write-Host (("[OK] Descarga completada: {0:N2} MB en {1:N2} segundos.") -f $sizeMB, $stopwatch.Elapsed.TotalSeconds) -ForegroundColor Green
} else {
    Write-Host "[OK] Extracto PBF existente en disco: $targetPbf" -ForegroundColor Green
}

# 4. Despliegue de la infraestructura
Write-Host "[INFO] Levantando contenedor con Docker Compose..." -ForegroundColor Cyan
Push-Location (Join-Path $PSScriptRoot "..")
docker compose up -d

Write-Host "[INFO] Supervisando proceso de inicialización e indexación espacial..." -ForegroundColor Cyan
Write-Host "Ejecuta el siguiente comando para ver el progreso detallado:" -ForegroundColor Yellow
Write-Host "docker compose logs -f nominatim-engine" -ForegroundColor White
Pop-Location