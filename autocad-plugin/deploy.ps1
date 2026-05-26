# ═══════════════════════════════════════════════
# SPE Plugin — Build + Deploy (desenvolvimento)
# Compila e copia pro autoloader do AutoCAD
# ═══════════════════════════════════════════════
$ErrorActionPreference = "Stop"

$projetoDir = "d:\DESENVOLVIMENTO\SPE\autocad-plugin\SpePlugin"
$bundleDir = "$env:APPDATA\Autodesk\ApplicationPlugins\SpePlugin.bundle\Contents"

Write-Host ""
Write-Host "=== SPE Plugin: Build + Deploy ===" -ForegroundColor Cyan
Write-Host ""

# 1. Compilar
Write-Host "[1/3] Compilando..." -ForegroundColor Yellow
$result = & C:\dotnet\dotnet.exe build "$projetoDir" -c Release 2>&1
$erros = $result | Select-String "Erro\(s\)" | Select-Object -First 1
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERRO] Falha na compilacao!" -ForegroundColor Red
    $result | Write-Host
    exit 1
}
Write-Host "  Compilado com sucesso!" -ForegroundColor Green

# 2. Criar pasta bundle se nao existir
if (-not (Test-Path $bundleDir)) {
    New-Item -ItemType Directory -Path $bundleDir -Force | Out-Null
}

# 3. Copiar arquivos
Write-Host "[2/3] Copiando para o autoloader..." -ForegroundColor Yellow
Copy-Item "$projetoDir\bin\Release\SpePlugin.dll" "$bundleDir\SpePlugin.dll" -Force
Copy-Item "$projetoDir\bin\Release\SpePlugin.pdb" "$bundleDir\SpePlugin.pdb" -Force
Write-Host "  Copiado para: $bundleDir" -ForegroundColor Green

# 3. Verificar
Write-Host "[3/3] Verificando..." -ForegroundColor Yellow
$dll = Get-Item "$bundleDir\SpePlugin.dll"
Write-Host "  SpePlugin.dll — $([math]::Round($dll.Length/1024, 1)) KB — $($dll.LastWriteTime)" -ForegroundColor Green

Write-Host ""
Write-Host "=== Deploy concluido! ===" -ForegroundColor Cyan
Write-Host "  Feche e reabra o AutoCAD para carregar a nova versao." -ForegroundColor White
Write-Host ""
