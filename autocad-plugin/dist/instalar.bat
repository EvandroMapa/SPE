@echo off
chcp 1252 >nul
title SPE Plugin - Instalador AutoCAD

:: Mudar para o diretorio do instalador
pushd "%~dp0"

set "LOG=%~dp0instalacao.log"

echo ============================================ > "%LOG%"
echo SPE Plugin - Log de Instalacao >> "%LOG%"
echo Data: %DATE% %TIME% >> "%LOG%"
echo Pasta origem: %~dp0 >> "%LOG%"
echo ============================================ >> "%LOG%"
echo. >> "%LOG%"

echo.
echo   ==========================================
echo   SPE Plugin - Instalador AutoCAD
echo   ==========================================
echo.

:: --- 1. Detectar AutoCAD ---
echo   [1/4] Detectando AutoCAD instalado...
echo [1/4] Detectando AutoCAD... >> "%LOG%"

set "ACAD_ENCONTRADO=0"
set "TEM_2025=0"
set "TEM_2022=0"

if exist "C:\Program Files\Autodesk\AutoCAD 2025" (
    echo     [OK] AutoCAD 2025 encontrado
    echo   [OK] AutoCAD 2025 >> "%LOG%"
    set "ACAD_ENCONTRADO=1"
    set "TEM_2025=1"
) else ( echo   [--] AutoCAD 2025 nao instalado >> "%LOG%" )

if exist "C:\Program Files\Autodesk\AutoCAD 2024" (
    echo     [OK] AutoCAD 2024 encontrado
    echo   [OK] AutoCAD 2024 >> "%LOG%"
    set "ACAD_ENCONTRADO=1"
    set "TEM_2022=1"
) else ( echo   [--] AutoCAD 2024 nao instalado >> "%LOG%" )

if exist "C:\Program Files\Autodesk\AutoCAD 2023" (
    echo     [OK] AutoCAD 2023 encontrado
    echo   [OK] AutoCAD 2023 >> "%LOG%"
    set "ACAD_ENCONTRADO=1"
    set "TEM_2022=1"
) else ( echo   [--] AutoCAD 2023 nao instalado >> "%LOG%" )

if exist "C:\Program Files\Autodesk\AutoCAD 2022" (
    echo     [OK] AutoCAD 2022 encontrado
    echo   [OK] AutoCAD 2022 >> "%LOG%"
    set "ACAD_ENCONTRADO=1"
    set "TEM_2022=1"
) else ( echo   [--] AutoCAD 2022 nao instalado >> "%LOG%" )

if "%ACAD_ENCONTRADO%"=="0" (
    echo     [ERRO] Nenhum AutoCAD encontrado!
    echo   [ERRO] Nenhum AutoCAD encontrado! >> "%LOG%"
    popd & pause & exit /b 1
)

:: --- 2. Verificar DLLs na pasta do instalador ---
echo.
echo   [2/4] Verificando DLLs do plugin...
echo. >> "%LOG%"
echo [2/4] Arquivos na pasta de instalacao: >> "%LOG%"

for %%f in (*.dll) do echo   %%~nxf  [%%~zf bytes] >> "%LOG%"

if exist "SpePlugin2022.dll" (
    echo     [OK] SpePlugin2022.dll encontrada
    echo   [OK] SpePlugin2022.dll presente >> "%LOG%"
) else (
    echo     [ERRO] SpePlugin2022.dll NAO encontrada!
    echo   [ERRO] SpePlugin2022.dll NAO encontrada >> "%LOG%"
    popd & pause & exit /b 1
)

:: --- 3. Instalar bundle ---
echo.
echo   [3/4] Instalando plugin...
echo. >> "%LOG%"
echo [3/4] Instalando bundle... >> "%LOG%"

set "BUNDLE_DIR=%APPDATA%\Autodesk\ApplicationPlugins\SpePlugin.bundle"
set "CONTENTS_DIR=%BUNDLE_DIR%\Contents"

echo   AppData: %APPDATA% >> "%LOG%"
echo   Bundle : %BUNDLE_DIR% >> "%LOG%"
echo   Contents: %CONTENTS_DIR% >> "%LOG%"

if not exist "%CONTENTS_DIR%" (
    mkdir "%CONTENTS_DIR%"
    echo   [OK] Pasta Contents criada >> "%LOG%"
) else (
    echo   [OK] Pasta Contents ja existe >> "%LOG%"
)

:: Verificar se a pasta foi criada
if not exist "%CONTENTS_DIR%" (
    echo   [ERRO] Nao foi possivel criar a pasta Contents!
    echo   [ERRO] Falha ao criar Contents >> "%LOG%"
    popd & pause & exit /b 1
)

:: Copiar TODAS as DLLs com xcopy (mais robusto com caminhos especiais)
echo   Copiando DLLs... >> "%LOG%"
xcopy /Y /Q "*.dll" "%CONTENTS_DIR%\" >> "%LOG%" 2>&1
echo   Retorno xcopy: %ERRORLEVEL% >> "%LOG%"
echo     [OK] DLLs copiadas para o bundle

:: Gerar PackageContents.xml
(
echo ^<?xml version="1.0" encoding="utf-8"?^>
echo ^<ApplicationPackage
echo   SchemaVersion="1.0" AppVersion="2.0"
echo   ProductCode="{SPE-PLUGIN-AUTOCAD}"
echo   Name="SPE Plugin"
echo   Description="Captura de armaduras do AutoCAD para o app SPE"
echo   Author="SPE"^>
echo   ^<CompanyDetails Name="SPE" /^>
echo   ^<Components^>
echo     ^<RuntimeRequirements OS="Win64" Platform="AutoCAD" /^>
) > "%BUNDLE_DIR%\PackageContents.xml"

if "%TEM_2025%"=="1" if exist "%CONTENTS_DIR%\SpePlugin.dll" (
    (
    echo     ^<ComponentEntry AppName="SpePlugin" Version="2.0"
    echo       ModuleName="./Contents/SpePlugin.dll"
    echo       AppDescription="SPE - Captura de Armaduras"
    echo       SeriesMin="R25.0" LoadOnAutoCADStartup="True" /^>
    ) >> "%BUNDLE_DIR%\PackageContents.xml"
    echo   [OK] Entrada AutoCAD 2025 no XML >> "%LOG%"
)

if "%TEM_2022%"=="1" if exist "%CONTENTS_DIR%\SpePlugin2022.dll" (
    (
    echo     ^<ComponentEntry AppName="SpePlugin2022" Version="2.0"
    echo       ModuleName="./Contents/SpePlugin2022.dll"
    echo       AppDescription="SPE - Captura de Armaduras"
    echo       SeriesMin="R24.0" SeriesMax="R24.3" LoadOnAutoCADStartup="True" /^>
    ) >> "%BUNDLE_DIR%\PackageContents.xml"
    echo   [OK] Entrada AutoCAD 2022 no XML >> "%LOG%"
)

(
echo   ^</Components^>
echo ^</ApplicationPackage^>
) >> "%BUNDLE_DIR%\PackageContents.xml"

echo   [OK] PackageContents.xml criado >> "%LOG%"
echo     [OK] PackageContents.xml criado

:: --- 4. Verificar bundle final ---
echo.
echo   [4/4] Verificando bundle instalado...
echo. >> "%LOG%"
echo [4/4] Arquivos em Contents apos instalacao: >> "%LOG%"
for %%f in ("%CONTENTS_DIR%\*.*") do echo   %%~nxf  [%%~zf bytes] >> "%LOG%"

:: --- Resultado ---
echo.
echo   ==========================================
echo   Instalacao concluida!
echo   ==========================================
echo.
echo   IMPORTANTE: Feche e reabra o AutoCAD.
echo.
echo   Log salvo em:
echo   %LOG%
echo.
if "%TEM_2025%"=="1" echo   [OK] AutoCAD 2025 - pronto
if "%TEM_2022%"=="1" echo   [OK] AutoCAD 2022 - pronto
echo.

echo. >> "%LOG%"
echo ============================================ >> "%LOG%"
echo Instalacao finalizada: %DATE% %TIME% >> "%LOG%"
echo ============================================ >> "%LOG%"

popd
pause
