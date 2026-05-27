# ═══════════════════════════════════════════════
# SPE Plugin — Build + Deploy (desenvolvimento)
# Compila a DLL que o AutoCAD carrega via NETLOAD
# ═══════════════════════════════════════════════
$ErrorActionPreference = "Stop"

$projetoDir = "d:\DESENVOLVIMENTO\SPE\autocad-plugin\SpePlugin"
$dllPath = "$projetoDir\bin\Release\SpePlugin.dll"

Write-Host ""
Write-Host "=== SPE Plugin: Build + Deploy ===" -ForegroundColor Cyan
Write-Host ""

# 1. Compilar
Write-Host "[1/2] Compilando..." -ForegroundColor Yellow
$result = & C:\dotnet\dotnet.exe build "$projetoDir" -c Release 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERRO] Falha na compilacao!" -ForegroundColor Red
    $result | Write-Host
    exit 1
}
Write-Host "  Compilado com sucesso!" -ForegroundColor Green

# 2. Verificar
Write-Host "[2/2] Verificando..." -ForegroundColor Yellow
$dll = Get-Item $dllPath
Write-Host "  SpePlugin.dll — $([math]::Round($dll.Length/1024, 1)) KB — $($dll.LastWriteTime)" -ForegroundColor Green

Write-Host ""
Write-Host "=== Deploy concluido! ===" -ForegroundColor Cyan
Write-Host "  DLL: $dllPath" -ForegroundColor White
Write-Host "  Feche e reabra o AutoCAD para carregar a nova versao." -ForegroundColor White
Write-Host ""
