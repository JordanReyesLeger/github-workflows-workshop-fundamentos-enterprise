<#
.SYNOPSIS
    Crea TU copia del taller dentro de tu organizacion y sube el codigo.

.DESCRIPTION
    Funciona tambien con cuentas Enterprise Managed User (EMU), que no pueden
    usar "Use this template" contra repositorios de fuera de la empresa.

    Descarga el contenido sin usar tus credenciales, crea un repositorio nuevo
    en tu organizacion y lo sube. No deja historia ajena: empieza limpio.

.EXAMPLE
    pwsh scripts/crear-mi-repo.ps1 -Organizacion tspjrldemo -Nombre taller-workflows-jordan
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Organizacion,
    [Parameter(Mandatory)][string]$Nombre,
    [ValidateSet('private','internal')][string]$Visibilidad = 'private',
    [string]$Origen = 'JordanReyesLeger/github-workflows-workshop-fundamentos-enterprise',
    [string]$Rama = 'main'
)

$ErrorActionPreference = 'Stop'

function Paso($n, $t) { Write-Host "`n[$n] $t" -ForegroundColor Cyan }

foreach ($cmd in 'git', 'gh') {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        throw "Falta $cmd. Instalalo antes de continuar."
    }
}

gh auth status *> $null
if ($LASTEXITCODE -ne 0) { throw "No has iniciado sesion. Ejecuta: gh auth login" }

$destino = Join-Path (Get-Location) $Nombre
if (Test-Path $destino) { throw "Ya existe la carpeta '$Nombre'. Borrala o usa otro nombre." }

Paso 1 "Descargando el contenido del taller..."
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("taller-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $tmp | Out-Null
$zip = Join-Path $tmp 'taller.zip'

# Sin credenciales: evita que un token EMU intervenga en la descarga.
Invoke-WebRequest -Uri "https://codeload.github.com/$Origen/zip/refs/heads/$Rama" -OutFile $zip -UseBasicParsing
Expand-Archive $zip -DestinationPath $tmp -Force
$extraido = Get-ChildItem $tmp -Directory | Select-Object -First 1
Move-Item $extraido.FullName $destino
Remove-Item -Recurse -Force $tmp

Paso 2 "Preparando el repositorio local..."
Push-Location $destino
try {
    git init -q -b $Rama
    git add -A
    git commit -q -m "chore: taller de GitHub Actions"

    Paso 3 "Creando $Organizacion/$Nombre y subiendo..."
    gh repo create "$Organizacion/$Nombre" "--$Visibilidad" --source=. --push
    if ($LASTEXITCODE -ne 0) { throw "No se pudo crear el repositorio. Revisa que puedas crear repos en '$Organizacion'." }

    Write-Host "`nListo." -ForegroundColor Green
    Write-Host "  Repositorio : https://github.com/$Organizacion/$Nombre"
    Write-Host "  Carpeta     : $destino"
    Write-Host "`nSigue con el Modulo 1 del README.`n"
}
finally { Pop-Location }