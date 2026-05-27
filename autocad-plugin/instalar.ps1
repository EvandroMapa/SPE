# ═══════════════════════════════════════════════════════════
# SPE Plugin - Instalador para AutoCAD
# Detecta versoes instaladas e configura o autoloader
# ═══════════════════════════════════════════════════════════
param(
    [string]$DllPath = ""
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "  SPE Plugin - Instalador AutoCAD" -ForegroundColor Cyan
Write-Host ""

# --- 1. Detectar versoes do AutoCAD ---
$versoes = @()
$autocadPaths = @{}
$autocadPaths["2022"] = "C:\Program Files\Autodesk\AutoCAD 2022"
$autocadPaths["2023"] = "C:\Program Files\Autodesk\AutoCAD 2023"
$autocadPaths["2024"] = "C:\Program Files\Autodesk\AutoCAD 2024"
$autocadPaths["2025"] = "C:\Program Files\Autodesk\AutoCAD 2025"

Write-Host "  [1/4] Detectando AutoCAD instalado..." -ForegroundColor Yellow
foreach ($ver in $autocadPaths.Keys | Sort-Object) {
    if (Test-Path $autocadPaths[$ver]) {
        $versoes += $ver
        Write-Host "    [OK] AutoCAD $ver encontrado" -ForegroundColor Green
    }
}

if ($versoes.Count -eq 0) {
    Write-Host "    [!] Nenhum AutoCAD encontrado!" -ForegroundColor Red
    exit 1
}

# --- 2. Localizar DLL ---
Write-Host ""
Write-Host "  [2/4] Localizando DLL do plugin..." -ForegroundColor Yellow

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$dllRelease = Join-Path $scriptDir "SpePlugin\bin\Release\SpePlugin.dll"

if ($DllPath -and (Test-Path $DllPath)) {
    $dllOrigem = $DllPath
} elseif (Test-Path $dllRelease) {
    $dllOrigem = $dllRelease
} else {
    Write-Host "    [!] SpePlugin.dll nao encontrada!" -ForegroundColor Red
    Write-Host "    Compile o projeto primeiro (dotnet build -c Release)" -ForegroundColor White
    exit 1
}

$dllInfo = Get-Item $dllOrigem
Write-Host "    DLL: $dllOrigem" -ForegroundColor White
Write-Host "    Data: $($dllInfo.LastWriteTime) - $([math]::Round($dllInfo.Length/1024, 1)) KB" -ForegroundColor White

# --- 3. Criar bundle ---
Write-Host ""
Write-Host "  [3/4] Instalando plugin..." -ForegroundColor Yellow

$bundleDir = "$env:APPDATA\Autodesk\ApplicationPlugins\SpePlugin.bundle"
$contentsDir = "$bundleDir\Contents"

if (-not (Test-Path $contentsDir)) {
    New-Item -ItemType Directory -Path $contentsDir -Force | Out-Null
}

# Montar XML
$componentEntries = ""

$temNovo = $versoes | Where-Object { $_ -eq "2025" }
$temAntigo = $versoes | Where-Object { $_ -in @("2022", "2023", "2024") }

if ($temNovo) {
    $componentEntries += "`n    <ComponentEntry AppName=`"SpePlugin`" Version=`"2.0`""
    $componentEntries += "`n      ModuleName=`"./Contents/SpePlugin.dll`""
    $componentEntries += "`n      AppDescription=`"SPE - Captura de Armaduras`""
    $componentEntries += "`n      SeriesMin=`"R25.0`""
    $componentEntries += "`n      LoadOnAutoCADStartup=`"True`" />"
}

if ($temAntigo) {
    $componentEntries += "`n    <ComponentEntry AppName=`"SpePlugin2022`" Version=`"2.0`""
    $componentEntries += "`n      ModuleName=`"./Contents/SpePlugin2022.dll`""
    $componentEntries += "`n      AppDescription=`"SPE - Captura de Armaduras`""
    $componentEntries += "`n      SeriesMin=`"R24.0`" SeriesMax=`"R24.3`""
    $componentEntries += "`n      LoadOnAutoCADStartup=`"True`" />"
}

$xmlContent = "<?xml version=`"1.0`" encoding=`"utf-8`"?>`n"
$xmlContent += "<ApplicationPackage`n"
$xmlContent += "  SchemaVersion=`"1.0`"`n"
$xmlContent += "  AppVersion=`"2.0`"`n"
$xmlContent += "  ProductCode=`"{SPE-PLUGIN-AUTOCAD}`"`n"
$xmlContent += "  Name=`"SPE Plugin`"`n"
$xmlContent += "  Description=`"Captura de armaduras do AutoCAD para o app SPE`"`n"
$xmlContent += "  Author=`"SPE`">`n`n"
$xmlContent += "  <CompanyDetails Name=`"SPE`" />`n`n"
$xmlContent += "  <Components>`n"
$xmlContent += "    <RuntimeRequirements OS=`"Win64`" Platform=`"AutoCAD`" />"
$xmlContent += $componentEntries
$xmlContent += "`n  </Components>`n`n"
$xmlContent += "</ApplicationPackage>`n"

$xmlContent | Out-File "$bundleDir\PackageContents.xml" -Encoding UTF8

# Copiar DLL
Copy-Item $dllOrigem "$contentsDir\SpePlugin.dll" -Force

# Copiar PDB se existir
$pdbOrigem = $dllOrigem -replace "\.dll$", ".pdb"
if (Test-Path $pdbOrigem) {
    Copy-Item $pdbOrigem "$contentsDir\SpePlugin.pdb" -Force
}

Write-Host "    [OK] Bundle criado em:" -ForegroundColor Green
Write-Host "    $bundleDir" -ForegroundColor White

if ($temAntigo) {
    $dll2022 = "$contentsDir\SpePlugin2022.dll"
    if (-not (Test-Path $dll2022)) {
        Write-Host ""
        Write-Host "    [!] AVISO: DLL para AutoCAD 2022 nao encontrada!" -ForegroundColor Yellow
        Write-Host "    Compile a versao net48 e copie para:" -ForegroundColor White
        Write-Host "    $dll2022" -ForegroundColor White
    }
}

# --- 4. Verificar ---
Write-Host ""
Write-Host "  [4/4] Verificando instalacao..." -ForegroundColor Yellow

$dllInstalada = Get-Item "$contentsDir\SpePlugin.dll"
Write-Host "    SpePlugin.dll - $([math]::Round($dllInstalada.Length/1024, 1)) KB - $($dllInstalada.LastWriteTime)" -ForegroundColor Green

if (Test-Path "$bundleDir\PackageContents.xml") {
    Write-Host "    PackageContents.xml - OK" -ForegroundColor Green
}

Write-Host ""
Write-Host "  Instalacao concluida!" -ForegroundColor Cyan
Write-Host "  Feche e reabra o AutoCAD." -ForegroundColor White
Write-Host "  O plugin sera carregado automaticamente." -ForegroundColor White
Write-Host ""

foreach ($v in $versoes) {
    if ($v -eq "2025") {
        Write-Host "  [OK] AutoCAD $v - pronto" -ForegroundColor Green
    } elseif (Test-Path "$contentsDir\SpePlugin2022.dll") {
        Write-Host "  [OK] AutoCAD $v - pronto" -ForegroundColor Green
    } else {
        Write-Host "  [~] AutoCAD $v - aguardando DLL net48" -ForegroundColor Yellow
    }
}
Write-Host ""
