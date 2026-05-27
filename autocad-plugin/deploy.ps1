# ═══════════════════════════════════════════════
# SPE Plugin - Build + Deploy (desenvolvimento)
# Compila ambos os targets e copia pro autoloader
# ═══════════════════════════════════════════════
$ErrorActionPreference = "Stop"

$projetoDir = "d:\DESENVOLVIMENTO\SPE\autocad-plugin\SpePlugin"
$bundleDir = "$env:APPDATA\Autodesk\ApplicationPlugins\SpePlugin.bundle\Contents"

Write-Host ""
Write-Host "=== SPE Plugin: Build + Deploy ===" -ForegroundColor Cyan
Write-Host ""

# 1. Compilar .NET 8 (AutoCAD 2025)
Write-Host "[1/3] Compilando net8.0 (AutoCAD 2025)..." -ForegroundColor Yellow
$result = & C:\dotnet\dotnet.exe build "$projetoDir" -c Release -f net8.0-windows 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "  [ERRO] Falha!" -ForegroundColor Red
    $result | Select-String "error" | Write-Host
    exit 1
}
$dll2025 = Get-Item "$projetoDir\bin\Release\net8.0-windows\SpePlugin.dll"
Write-Host "  [OK] $([math]::Round($dll2025.Length/1024, 1)) KB" -ForegroundColor Green

# 2. Compilar .NET 4.8 (AutoCAD 2022) - se tiver as DLLs
$libs2022 = "d:\DESENVOLVIMENTO\SPE\autocad-plugin\libs\acad2022"
$tem2022 = (Test-Path "$libs2022\acmgd.dll")

if ($tem2022) {
    Write-Host "[2/3] Compilando net48 (AutoCAD 2022)..." -ForegroundColor Yellow
    $result = & C:\dotnet\dotnet.exe build "$projetoDir" -c Release -f net48 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [AVISO] Falha no net48" -ForegroundColor Yellow
        $result | Select-String "error" | Write-Host
    } else {
        $dll2022 = Get-Item "$projetoDir\bin\Release\net48\SpePlugin.dll"
        Write-Host "  [OK] $([math]::Round($dll2022.Length/1024, 1)) KB" -ForegroundColor Green
    }
} else {
    Write-Host "[2/3] net48 (AutoCAD 2022) - pulando (DLLs do 2022 nao encontradas)" -ForegroundColor Yellow
    Write-Host "  Copie acmgd.dll, accoremgd.dll, acdbmgd.dll para:" -ForegroundColor White
    Write-Host "  $libs2022" -ForegroundColor White
}

# 3. Deploy para o bundle
Write-Host "[3/3] Deploy..." -ForegroundColor Yellow
if (Test-Path $bundleDir) {
    try {
        Copy-Item "$projetoDir\bin\Release\net8.0-windows\SpePlugin.dll" "$bundleDir\SpePlugin.dll" -Force
        Write-Host "  [OK] DLL 2025 copiada para o bundle" -ForegroundColor Green

        if ($tem2022 -and (Test-Path "$projetoDir\bin\Release\net48\SpePlugin.dll")) {
            Copy-Item "$projetoDir\bin\Release\net48\SpePlugin.dll" "$bundleDir\SpePlugin2022.dll" -Force
            Write-Host "  [OK] DLL 2022 copiada para o bundle" -ForegroundColor Green
        }
    } catch {
        Write-Host "  [!] Nao conseguiu copiar (AutoCAD aberto?)" -ForegroundColor Yellow
    }
} else {
    Write-Host "  Bundle nao encontrado. Rode 'instalar.bat' primeiro." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Deploy concluido! ===" -ForegroundColor Cyan
Write-Host "  Feche e reabra o AutoCAD." -ForegroundColor White
Write-Host ""
