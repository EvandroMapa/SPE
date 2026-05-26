# ═══════════════════════════════════════════════
# SPE Plugin — Instalador para AutoCAD 2025
# Execute este script no computador destino
# ═══════════════════════════════════════════════
$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "  ╔══════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║   SPE Plugin — Instalador v2.0   ║" -ForegroundColor Cyan
Write-Host "  ║   Para AutoCAD 2025              ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Verificar AutoCAD
$acadPath = "C:\Program Files\Autodesk\AutoCAD 2025"
if (-not (Test-Path $acadPath)) {
    Write-Host "[ERRO] AutoCAD 2025 nao encontrado em:" -ForegroundColor Red
    Write-Host "  $acadPath" -ForegroundColor Red
    Write-Host "  Instale o AutoCAD 2025 primeiro." -ForegroundColor Yellow
    Read-Host "Pressione Enter para sair"
    exit 1
}
Write-Host "[OK] AutoCAD 2025 encontrado" -ForegroundColor Green

# Pasta do bundle
$bundleDir = "$env:APPDATA\Autodesk\ApplicationPlugins\SpePlugin.bundle"
$contentsDir = "$bundleDir\Contents"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Verificar se os arquivos existem na pasta do instalador
$dllOrigem = Join-Path $scriptDir "SpePlugin.dll"
if (-not (Test-Path $dllOrigem)) {
    Write-Host "[ERRO] SpePlugin.dll nao encontrado na pasta do instalador!" -ForegroundColor Red
    Write-Host "  Esperado em: $dllOrigem" -ForegroundColor Yellow
    Read-Host "Pressione Enter para sair"
    exit 1
}

# Criar estrutura
Write-Host ""
Write-Host "[1/3] Criando estrutura..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path $contentsDir -Force | Out-Null

# Copiar PackageContents.xml
Write-Host "[2/3] Instalando plugin..." -ForegroundColor Yellow

$packageXml = @"
<?xml version="1.0" encoding="utf-8"?>
<ApplicationPackage
  SchemaVersion="1.0"
  AppVersion="2.0"
  ProductCode="{SPE-PLUGIN-AUTOCAD-2025}"
  Name="SPE Plugin"
  Description="Captura de armaduras do AutoCAD para o app SPE"
  Author="SPE">
  <CompanyDetails Name="SPE" />
  <Components>
    <RuntimeRequirements OS="Win64" Platform="AutoCAD" SeriesMin="R25.0" />
    <ComponentEntry AppName="SpePlugin" Version="2.0"
      ModuleName="./Contents/SpePlugin.dll"
      AppDescription="SPE - Captura de Armaduras"
      LoadOnAutoCADStartup="True" />
  </Components>
</ApplicationPackage>
"@
Set-Content -Path "$bundleDir\PackageContents.xml" -Value $packageXml -Encoding UTF8

# Copiar DLL
Copy-Item $dllOrigem "$contentsDir\SpePlugin.dll" -Force

# Copiar PDB se existir
$pdbOrigem = Join-Path $scriptDir "SpePlugin.pdb"
if (Test-Path $pdbOrigem) {
    Copy-Item $pdbOrigem "$contentsDir\SpePlugin.pdb" -Force
}

# Verificar
Write-Host "[3/3] Verificando instalacao..." -ForegroundColor Yellow
$dll = Get-Item "$contentsDir\SpePlugin.dll"
Write-Host ""
Write-Host "  Instalado em: $bundleDir" -ForegroundColor White
Write-Host "  DLL: $([math]::Round($dll.Length/1024, 1)) KB" -ForegroundColor White
Write-Host ""

Write-Host "  ╔══════════════════════════════════╗" -ForegroundColor Green
Write-Host "  ║   Instalacao concluida!           ║" -ForegroundColor Green
Write-Host "  ║                                   ║" -ForegroundColor Green
Write-Host "  ║   Abra o AutoCAD 2025 e           ║" -ForegroundColor Green
Write-Host "  ║   digite SPE no terminal.         ║" -ForegroundColor Green
Write-Host "  ╚══════════════════════════════════╗" -ForegroundColor Green
Write-Host ""
Read-Host "Pressione Enter para sair"
