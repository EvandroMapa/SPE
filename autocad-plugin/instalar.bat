@echo off
chcp 65001 >nul
title SPE Plugin - Instalador AutoCAD

echo.
echo   ==========================================
echo   SPE Plugin - Instalador AutoCAD
echo   ==========================================
echo.

:: --- Detectar AutoCAD ---
echo   [1/3] Detectando AutoCAD instalado...

set "ACAD_ENCONTRADO=0"
set "TEM_2025=0"
set "TEM_2022=0"

if exist "C:\Program Files\Autodesk\AutoCAD 2025" (
    echo     [OK] AutoCAD 2025 encontrado
    set "ACAD_ENCONTRADO=1"
    set "TEM_2025=1"
)
if exist "C:\Program Files\Autodesk\AutoCAD 2024" (
    echo     [OK] AutoCAD 2024 encontrado
    set "ACAD_ENCONTRADO=1"
    set "TEM_2022=1"
)
if exist "C:\Program Files\Autodesk\AutoCAD 2023" (
    echo     [OK] AutoCAD 2023 encontrado
    set "ACAD_ENCONTRADO=1"
    set "TEM_2022=1"
)
if exist "C:\Program Files\Autodesk\AutoCAD 2022" (
    echo     [OK] AutoCAD 2022 encontrado
    set "ACAD_ENCONTRADO=1"
    set "TEM_2022=1"
)

if "%ACAD_ENCONTRADO%"=="0" (
    echo     [ERRO] Nenhum AutoCAD encontrado!
    pause
    exit /b 1
)

:: --- Localizar DLLs ---
echo.
echo   [2/3] Localizando DLLs do plugin...

set "SCRIPT_DIR=%~dp0"

:: DLL para AutoCAD 2025 (.NET 8)
set "DLL_2025="
if exist "%SCRIPT_DIR%SpePlugin\bin\Release\net8.0-windows\SpePlugin.dll" (
    set "DLL_2025=%SCRIPT_DIR%SpePlugin\bin\Release\net8.0-windows\SpePlugin.dll"
) else if exist "%SCRIPT_DIR%SpePlugin.dll" (
    set "DLL_2025=%SCRIPT_DIR%SpePlugin.dll"
)

:: DLL para AutoCAD 2022 (.NET 4.8)
set "DLL_2022="
if exist "%SCRIPT_DIR%SpePlugin\bin\Release\net48\SpePlugin.dll" (
    set "DLL_2022=%SCRIPT_DIR%SpePlugin\bin\Release\net48\SpePlugin.dll"
) else if exist "%SCRIPT_DIR%SpePlugin2022.dll" (
    set "DLL_2022=%SCRIPT_DIR%SpePlugin2022.dll"
)

if "%TEM_2025%"=="1" (
    if defined DLL_2025 (
        echo     [OK] DLL AutoCAD 2025: %DLL_2025%
    ) else (
        echo     [!] DLL para AutoCAD 2025 nao encontrada
    )
)

if "%TEM_2022%"=="1" (
    if defined DLL_2022 (
        echo     [OK] DLL AutoCAD 2022: %DLL_2022%
    ) else (
        echo     [!] DLL para AutoCAD 2022 nao encontrada
    )
)

:: --- Criar bundle ---
echo.
echo   [3/3] Instalando plugin...

set "BUNDLE_DIR=%APPDATA%\Autodesk\ApplicationPlugins\SpePlugin.bundle"
set "CONTENTS_DIR=%BUNDLE_DIR%\Contents"

if not exist "%CONTENTS_DIR%" mkdir "%CONTENTS_DIR%"

:: Copiar DLLs e dependencias NuGet
if "%TEM_2025%"=="1" if defined DLL_2025 (
    copy /Y "%DLL_2025%" "%CONTENTS_DIR%\SpePlugin.dll" >nul
    :: Copiar dependencias da mesma pasta (ex: System.Text.Json.dll, etc.)
    for %%f in ("%~dp0SpePlugin\bin\Release\net8.0-windows\*.dll") do (
        if /I not "%%~nxf"=="SpePlugin.dll" (
            copy /Y "%%f" "%CONTENTS_DIR%\" >nul 2>nul
        )
    )
    echo     [OK] DLL 2025 e dependencias copiadas
)

if "%TEM_2022%"=="1" if defined DLL_2022 (
    copy /Y "%DLL_2022%" "%CONTENTS_DIR%\SpePlugin2022.dll" >nul
    :: Copiar todas as dependencias NuGet da pasta net48 (System.Text.Json, etc.)
    set "SRC_DIR2022="
    if exist "%~dp0SpePlugin\bin\Release\net48\SpePlugin.dll" (
        set "SRC_DIR2022=%~dp0SpePlugin\bin\Release\net48"
    ) else (
        set "SRC_DIR2022=%~dp0"
    )
    for %%f in ("%SRC_DIR2022%\*.dll") do (
        if /I not "%%~nxf"=="SpePlugin.dll" (
            copy /Y "%%f" "%CONTENTS_DIR%\" >nul 2>nul
        )
    )
    echo     [OK] DLL 2022 e dependencias copiadas
)

:: Criar PackageContents.xml - somente com entradas para DLLs instaladas
(
echo ^<?xml version="1.0" encoding="utf-8"?^>
echo ^<ApplicationPackage
echo   SchemaVersion="1.0"
echo   AppVersion="2.0"
echo   ProductCode="{SPE-PLUGIN-AUTOCAD}"
echo   Name="SPE Plugin"
echo   Description="Captura de armaduras do AutoCAD para o app SPE"
echo   Author="SPE"^>
echo   ^<CompanyDetails Name="SPE" /^>
echo   ^<Components^>
echo     ^<RuntimeRequirements OS="Win64" Platform="AutoCAD" /^>
) > "%BUNDLE_DIR%\PackageContents.xml"

if "%TEM_2025%"=="1" if defined DLL_2025 (
    (
    echo     ^<ComponentEntry AppName="SpePlugin" Version="2.0"
    echo       ModuleName="./Contents/SpePlugin.dll"
    echo       AppDescription="SPE - Captura de Armaduras"
    echo       SeriesMin="R25.0"
    echo       LoadOnAutoCADStartup="True" /^>
    ) >> "%BUNDLE_DIR%\PackageContents.xml"
)

if "%TEM_2022%"=="1" if defined DLL_2022 (
    (
    echo     ^<ComponentEntry AppName="SpePlugin2022" Version="2.0"
    echo       ModuleName="./Contents/SpePlugin2022.dll"
    echo       AppDescription="SPE - Captura de Armaduras"
    echo       SeriesMin="R24.0" SeriesMax="R24.3"
    echo       LoadOnAutoCADStartup="True" /^>
    ) >> "%BUNDLE_DIR%\PackageContents.xml"
)

(
echo   ^</Components^>
echo ^</ApplicationPackage^>
) >> "%BUNDLE_DIR%\PackageContents.xml"

echo     [OK] PackageContents.xml criado

:: --- Resultado ---
echo.
echo   ==========================================
echo   Instalacao concluida!
echo   ==========================================
echo.
echo   Feche e reabra o AutoCAD.
echo   O plugin sera carregado automaticamente.
echo.

if "%TEM_2025%"=="1" (
    if defined DLL_2025 (
        echo   [OK] AutoCAD 2025 - pronto
    ) else (
        echo   [!!] AutoCAD 2025 - DLL nao encontrada
    )
)
if "%TEM_2022%"=="1" (
    if defined DLL_2022 (
        echo   [OK] AutoCAD 2022 - pronto
    ) else (
        echo   [!!] AutoCAD 2022 - DLL nao encontrada
    )
)
echo.

pause
