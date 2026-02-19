@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion
title KenV2 Control Center
mode con: cols=120 lines=35

:: ==========================
:: COLORS ANSI
:: ==========================
for /f %%a in ('echo prompt $E^| cmd') do set "ESC=%%a"
set "RESET=%ESC%[0m"
set "RED=%ESC%[91m"
set "GREEN=%ESC%[92m"
set "YELLOW=%ESC%[93m"
set "BLUE=%ESC%[94m"
set "MAGENTA=%ESC%[95m"
set "CYAN=%ESC%[96m"
set "WHITE=%ESC%[97m"
set "GRAY=%ESC%[90m"
set "ORANGE=%ESC%[33m"

:: ==========================
:: CONFIG
:: ==========================
set "APP_NAME=KenV2"
set "VERSION=2.4.0"
set "TARGET=C:\KenV2 Tools"
set "TOOLS_DIR=%TARGET%\Tools"
set "LOG=%TARGET%\kenv2.log"
set "SPEC_FILE=%TARGET%\Specs.txt"
set "ZIP_PAYLOAD=%TARGET%\KenV2Payload.zip"
set "UPDATE_URL=https://raw.githubusercontent.com/27migu/KenV2/main/version.txt"
set "GITHUB_REPO=https://github.com/27migu/KenV2/releases/download"

:: ==========================
:: STARTUP
:: ==========================
call :requireAdmin
call :prepareFolder
call :log "KenV2 gestartet"
call :hardwareCheck
call :downloadPayload
call :menuLoop
exit /b

:: ==========================
:: ADMIN CHECK
:: ==========================
:requireAdmin
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo %YELLOW%Adminrechte erforderlich, starte Batch als Administrator...%RESET%
    powershell -Command "Start-Process cmd -ArgumentList '/c \"%~s0\"' -Verb RunAs"
    exit
)
exit /b

:: ==========================
:: LOGGING
:: ==========================
:log
echo [%date% %time%] %~1>>"%LOG%"
exit /b

:: ==========================
:: PREPARE FOLDER
:: ==========================
:prepareFolder
if exist "%TARGET%" (
    echo %YELLOW%Alter KenV2-Ordner wird entfernt...%RESET%
    rmdir /s /q "%TARGET%"
)
mkdir "%TARGET%"
mkdir "%TOOLS_DIR%"
call :log "Ordnerstruktur erstellt"
exit /b

:: ==========================
:: HARDWARE CHECK
:: ==========================
:hardwareCheck
echo %CYAN%Ermittle Hardware...%RESET%

:: CPU
for /f "usebackq tokens=*" %%a in (`powershell -Command "Get-CimInstance Win32_Processor | Select-Object -ExpandProperty Name"`) do set "CPU=%%a"
echo !CPU! | findstr /i "Intel" >nul && set "CPU_TYPE=Intel"
echo !CPU! | findstr /i "AMD" >nul && set "CPU_TYPE=AMD"

:: GPU
for /f "usebackq tokens=*" %%a in (`powershell -Command "Get-CimInstance Win32_VideoController | Select-Object -ExpandProperty Name"`) do set "GPU=%%a"
echo !GPU! | findstr /i "NVIDIA" >nul && set "GPU_TYPE=NVIDIA"
echo !GPU! | findstr /i "AMD" >nul && set "GPU_TYPE=AMD"

:: RAM
for /f "usebackq tokens=*" %%a in (`powershell -NoProfile -Command "[math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)"`) do set "RAM_GB=%%a"

:: Mainboard
for /f "usebackq tokens=*" %%a in (`powershell -Command "Get-CimInstance Win32_BaseBoard | Select-Object -ExpandProperty Product"`) do set "BOARD=%%a"

:: BIOS
for /f "usebackq tokens=*" %%a in (`powershell -Command "Get-CimInstance Win32_BIOS | Select-Object -ExpandProperty SMBIOSBIOSVersion"`) do set "BIOS=%%a"

:: NICs
set "NICS="
for /f "tokens=*" %%a in ('powershell -Command "Get-CimInstance Win32_NetworkAdapter | Where-Object {$_.NetEnabled -eq $true} | Select-Object -ExpandProperty Name"') do if not "%%a"=="" set "NICS=!NICS!%%a, "
if defined NICS set "NICS=!NICS:~0,-2!"

:: SPECS FILE
(
echo CPU: !CPU!
echo CPU_TYPE: !CPU_TYPE!
echo GPU: !GPU!
echo GPU_TYPE: !GPU_TYPE!
echo RAM: !RAM_GB! GB
echo Mainboard: !BOARD!
echo BIOS: !BIOS!
echo NICs: !NICS!
) > "%SPEC_FILE%"

echo %GREEN%Hardware erfolgreich erkannt und Specs-Datei erstellt.%RESET%
call :log "Hardware Check OK"
timeout /t 1 >nul
exit /b

:: ==========================
:: DOWNLOAD PAYLOAD mit Fortschrittsbalken
:: ==========================
:downloadPayload
echo %CYAN%Prüfe Payload...%RESET%
set "PAYLOAD_URL=%GITHUB_REPO%/KenV2Payload.zip"
set "HASH_URL=%GITHUB_REPO%/KenV2Payload.sha256"

:: Datei herunterladen
curl -L -o "%ZIP_PAYLOAD%" "%PAYLOAD_URL%" --progress-bar

:: Hash herunterladen & prüfen
curl -L -o "%TARGET%\KenV2Payload.sha256" "%HASH_URL%"
call :verifyHash "%ZIP_PAYLOAD%" "%TARGET%\KenV2Payload.sha256"
if errorlevel 1 (
    echo %RED%Payload Hashprüfung fehlgeschlagen!%RESET%
    pause
    exit /b
)

:: Extrahieren
echo %CYAN%Entpacke Payload...%RESET%
powershell -Command "Expand-Archive -Force '%ZIP_PAYLOAD%' '%TOOLS_DIR%'" >>"%LOG%" 2>&1
del "%ZIP_PAYLOAD%"
echo %GREEN%Payload installiert.%RESET%
call :log "Payload installiert"
exit /b

:: ==========================
:: HASH VERIFICATION
:: ==========================
:verifyHash
set "FILE=%~1"
set "HASHFILE=%~2"
for /f %%H in ('certutil -hashfile "%FILE%" SHA256 ^| findstr /R "^[0-9A-F]"') do set "DOWN_HASH=%%H"
set /p EXPECTED_HASH=<"%HASHFILE%"
if /I "%DOWN_HASH%"=="%EXPECTED_HASH%" (
    exit /b 0
) else (
    exit /b 1
)

:: ==========================
:: HEADER + ASCII SIGNATURE
:: ==========================
:printHeader
echo.
echo.
echo.
echo %CYAN%          ╔═══════════════════════════════════════════════════════════════════════╗%RESET%
echo %CYAN%          ║%RESET%   %BLUE%██╗  ██╗███████╗███╗   ██╗██╗   ██╗██████╗ %RESET%                 %CYAN%        ║%RESET%
echo %CYAN%          ║%RESET%   %BLUE%██║ ██╔╝██╔════╝████╗  ██║██║   ██║╚════██╗%RESET%                 %CYAN%        ║%RESET%
echo %CYAN%          ║%RESET%   %BLUE%█████╔╝ █████╗  ██╔██╗ ██║██║   ██║ █████╔╝%RESET%                  %CYAN%       ║%RESET%
echo %CYAN%          ║%RESET%   %BLUE%██╔═██╗ ██╔══╝  ██║╚██╗██║╚██╗ ██╔╝██╔═══╝ %RESET%                 %CYAN%        ║%RESET%
echo %CYAN%          ║%RESET%   %BLUE%██║  ██╗███████╗██║ ╚████║ ╚████╔╝ ███████╗%RESET%                 %CYAN%        ║%RESET%
echo %CYAN%          ║%RESET%   %BLUE%╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝  ╚═══╝  ╚══════╝%RESET%                  %CYAN%       ║%RESET%
echo %CYAN%          ║%RESET%   %GRAY%v%VERSION%%RESET%                                                        %CYAN%      ║
echo %CYAN%          ╚═══════════════════════════════════════════════════════════════════════╝%RESET%
echo.
echo.
exit /b

:: ==========================
:: SHOW HARDWARE (ASCII Kachel + Farben)
:: ==========================
:showHardware
cls
call :printHeader
echo.
echo %CYAN%================== Hardware Übersicht ==================%RESET%
echo.
echo  ╔══════════════════════════════════════════════════════════════╗
echo  ║ CPU:      !CPU!   Typ: !CPU_TYPE!%RESET%
echo  ║ GPU:      !GPU!   Typ: !GPU_TYPE!%RESET%
echo  ║ RAM:      !RAM_GB! GB%RESET%
echo  ║ Mainboard:!BOARD!%RESET%
echo  ║ BIOS:     !BIOS!%RESET%
echo  ║ NICs:     !NICS!%RESET%
echo  ╚══════════════════════════════════════════════════════════════╝
echo.
echo.
echo.
echo.
pause
exit /b

:: ==========================
:: MENU LOOP
:: ==========================
:menuLoop
set "PAGE=1"
set "TOTALPAGES=5"
:menuStart
cls
call :printHeader

:: Mini Dashboard
set "CPU_DISPLAY=!CPU!"
if "!CPU_TYPE!"=="Intel" set "CPU_DISPLAY=%BLUE%!CPU!%RESET%"
if "!CPU_TYPE!"=="AMD" set "CPU_DISPLAY=%RED%!CPU!%RESET%"
set "GPU_DISPLAY=!GPU!"
if "!GPU_TYPE!"=="NVIDIA" set "GPU_DISPLAY=%GREEN%!GPU!%RESET%"
if "!GPU_TYPE!"=="AMD" set "GPU_DISPLAY=%RED%!GPU!%RESET%"
set "RAM_DISPLAY=%MAGENTA%!RAM_GB! GB%RESET%"

echo %CYAN%CPU:%RESET% !CPU_DISPLAY!    %CYAN%GPU:%RESET% !GPU_DISPLAY!    %CYAN%RAM:%RESET% !RAM_DISPLAY!
echo.

echo %GRAY%Seite %PAGE% von %TOTALPAGES%%RESET%
echo ───────────────────────────────────────────────

:: Page Content
if %PAGE%==1 call :page1
if %PAGE%==2 call :page2
if %PAGE%==3 call :page3
if %PAGE%==4 call :page4
if %PAGE%==5 call :page5

echo ───────────────────────────────────────────────
echo [1-3] Option   [N] Next   [P] Previous   [Q] Quit   [H] Hardware
choice /c 123NPQH /n /m "Auswahl: "
set "sel=%errorlevel%"

if %sel%==4 (
    set /a PAGE+=1
    if %PAGE% gtr %TOTALPAGES% set PAGE=1
    goto menuStart
)
if %sel%==5 (
    set /a PAGE-=1
    if %PAGE% lss 1 set PAGE=%TOTALPAGES%
    goto menuStart
)
if %sel%==6 exit /b
if %sel%==7 call :showHardware
if %sel% lss 4 (
    if %PAGE%==1 call :handlePage1 %sel%
    if %PAGE%==2 call :handlePage2 %sel%
    if %PAGE%==3 call :handlePage3 %sel%
    if %PAGE%==4 call :handlePage4 %sel%
    if %PAGE%==5 call :handlePage5 %sel%
)
goto menuStart






:: ==========================
:: PAGE CONTENT
:: ==========================

:page1
:: Hardware Tweaks (CPU/GPU/RAM)
echo [1] CPU Tweaks
echo [2] GPU Tweaks
echo [3] RAM / Power Tweaks
exit /b





:page2
:: ==========================
:: HARDWARE SEITE (nur Kategorien)
:: ==========================
cls
call :printHeader
echo.
echo %CYAN%================== Hardware Kategorien ==================%RESET%
echo.

:: Kategorien nebeneinander
echo.
echo   ╔══════════════╗  ╔══════════════╗  ╔══════════════╗  ╔══════════════╗
echo   ║  [1] CPU     ║  ║  [2] GPU     ║  ║  [3] RAM     ║  ║  [4] Storage ║
echo   ╚══════════════╝  ╚══════════════╝  ╚══════════════╝  ╚══════════════╝
echo.
echo.
echo.
echo.
echo %WHITE%[N] Next Page   [P] Previous Page   [Q] Hauptmenü%RESET%

:: Auswahl treffen
choice /c 1234NPQ /n /m "Auswahl: "
set "sel=%errorlevel%"

:: Unterseiten aufrufen
if %sel%==1 call :hardwareCPU
if %sel%==2 call :hardwareGPU
if %sel%==3 call :hardwareRAM
if %sel%==4 call :hardwareStorage

:: Seitenwechsel
if %sel%==5 (
    set /a PAGE+=1
    if %PAGE% gtr %TOTALPAGES% set PAGE=1
    goto menuStart
)
if %sel%==6 (
    set /a PAGE-=1
    if %PAGE% lss 1 set PAGE=%TOTALPAGES%
    goto menuStart
)
if %sel%==7 goto menuStart
goto page2

:: ==========================
:: CPU Unterseite
:: ==========================
:hardwareCPU
cls
call :printHeader
echo.
echo %CYAN%================== CPU Tweaks ==================%RESET%
echo.
echo CPU: !CPU!
echo Typ: !CPU_TYPE!
echo.

:: Herstellerabhängige Anzeige
if /I "!CPU_TYPE!"=="Intel" (
    echo   ╔══════════════════════╗
    echo   ║  [1] Intel Tweaks    ║
    echo   ╚══════════════════════╝
    echo   ╔══════════════════════╗
    echo   ║  [2] Allgemeine CPU  ║
    echo   ╚══════════════════════╝
    echo.
    echo %GRAY%[B] Zurück%RESET%
    choice /c 12B /n /m "Auswahl: "
    
    if errorlevel 3 goto page2
    if errorlevel 2 echo Allgemeine CPU Tweaks ausgeführt.
    if errorlevel 1 echo Intel CPU Tweaks ausgeführt.
)

if /I "!CPU_TYPE!"=="AMD" (
    echo   ╔══════════════════════╗
    echo   ║  [1] AMD Tweaks      ║
    echo   ╚══════════════════════╝
    echo   ╔══════════════════════╗
    echo   ║  [2] Allgemeine CPU  ║
    echo   ╚══════════════════════╝
    echo.
    echo %GRAY%[B] Zurück%RESET%
    choice /c 12B /n /m "Auswahl: "
    
    if errorlevel 3 goto page2
    if errorlevel 2 echo Allgemeine CPU Tweaks ausgeführt.
    if errorlevel 1 echo AMD CPU Tweaks ausgeführt.
)

pause
goto hardwareCPU

:: ==========================
:: GPU Unterseite
:: ==========================
:hardwareGPU
cls
call :printHeader
echo.
echo %CYAN%================== GPU Tweaks ==================%RESET%
echo.
echo GPU: !GPU!
echo Typ: !GPU_TYPE!
echo.

:: NVIDIA
if /I "!GPU_TYPE!"=="NVIDIA" (
    echo   ╔══════════════════════╗
    echo   ║  [1] NVIDIA Tweaks   ║
    echo   ╚══════════════════════╝
    echo   ╔══════════════════════╗
    echo   ║  [2] Allgemeine GPU  ║
    echo   ╚══════════════════════╝
    echo.
    echo %GRAY%[B] Zurück%RESET%
    choice /c 12B /n /m "Auswahl: "
    
    if errorlevel 3 goto page2
    if errorlevel 2 echo Allgemeine GPU Tweaks ausgeführt.
    if errorlevel 1 echo NVIDIA Tweaks ausgeführt.
)

:: AMD
if /I "!GPU_TYPE!"=="AMD" (
    echo   ╔══════════════════════╗
    echo   ║  [1] AMD Tweaks      ║
    echo   ╚══════════════════════╝
    echo   ╔══════════════════════╗
    echo   ║  [2] Allgemeine GPU  ║
    echo   ╚══════════════════════╝
    echo.
    echo %GRAY%[B] Zurück%RESET%
    choice /c 12B /n /m "Auswahl: "
    
    if errorlevel 3 goto page2
    if errorlevel 2 echo Allgemeine GPU Tweaks ausgeführt.
    if errorlevel 1 echo AMD Tweaks ausgeführt.
)

:: Intel GPU (falls vorhanden)
if /I "!GPU_TYPE!"=="INTEL" (
    echo   ╔══════════════════════╗
    echo   ║  [1] Intel iGPU      ║
    echo   ╚══════════════════════╝
    echo   ╔══════════════════════╗
    echo   ║  [2] Allgemeine GPU  ║
    echo   ╚══════════════════════╝
    echo.
    echo %GRAY%[B] Zurück%RESET%
    choice /c 12B /n /m "Auswahl: "
    
    if errorlevel 3 goto page2
    if errorlevel 2 echo Allgemeine GPU Tweaks ausgeführt.
    if errorlevel 1 echo Intel GPU Tweaks ausgeführt.
)

pause
goto hardwareGPU



:: ==========================
:: RAM Unterseite
:: ==========================
:hardwareRAM
cls
call :printHeader
echo.
echo %CYAN%================== RAM / Power Tweaks ==================%RESET%
echo.
echo RAM: !RAM_GB! GB
echo [1] RAM Tweaks
echo [2] Power Tweaks
echo.
echo %GRAY%[B] Zurück zur Hardware Übersicht%RESET%
choice /c 12B /n /m "Auswahl: "
set "sel=%errorlevel%"
if %sel%==1 echo RAM Tweaks ausgeführt.
if %sel%==2 echo Power Tweaks ausgeführt.
if %sel%==3 goto page2
pause
goto hardwareRAM

:: ==========================
:: Storage Unterseite
:: ==========================
:hardwareStorage
cls
call :printHeader
echo.
echo %CYAN%================== Storage Tweaks ==================%RESET%
echo.
echo [1] SSD Optimierungen
echo [2] HDD Optimierungen
echo [3] Allgemeine Storage Tweaks
echo.
echo %GRAY%[B] Zurück zur Hardware Übersicht%RESET%
choice /c 123B /n /m "Auswahl: "
set "sel=%errorlevel%"
if %sel%==1 echo SSD Tweaks ausgeführt.
if %sel%==2 echo HDD Tweaks ausgeführt.
if %sel%==3 echo Allgemeine Storage Tweaks ausgeführt.
if %sel%==4 goto page2
pause
goto hardwareStorage








:page3
:: Peripherals Tweaks
echo [1] Tastatur / Maus Tweaks
echo [2] Controller Tweaks
echo [3] USB Tweaks
exit /b

:page4
:: 3rd Party Software Tools
echo [1] 3rd Party Tools installieren
echo [2] Tools Update prüfen
echo [3] Installierte Tools auflisten
exit /b

:page5
:: Clean & Extras
echo [1] Logs & Temp Files löschen
echo [2] Autostart bereinigen
echo [3] Dienste optimieren / Extras
exit /b

:: ==========================
:: HANDLE PAGE ACTIONS
:: ==========================

:handlePage1
:: Hardware Tweaks ausführen
if %1==1 (
    if "!CPU_TYPE!"=="Intel" echo Intel CPU Tweaks ausgeführt. (Platzhalter)
    if "!CPU_TYPE!"=="AMD" echo AMD CPU Tweaks ausgeführt. (Platzhalter)
)
if %1==2 (
    if "!GPU_TYPE!"=="NVIDIA" echo NVIDIA GPU Tweaks ausgeführt. (Platzhalter)
    if "!GPU_TYPE!"=="AMD" echo AMD GPU Tweaks ausgeführt. (Platzhalter)
)
if %1==3 echo RAM / Power Tweaks ausgeführt. (Platzhalter)
pause
exit /b

:handlePage2
if %1==1 echo Windows Debloat / Telemetry entfernt. (Platzhalter)
if %1==2 del /s /q C:\Windows\Temp\* >nul 2>&1 & echo Temp Dateien bereinigt.
if %1==3 echo Systemoptimierungen durchgeführt. (Platzhalter)
pause
exit /b

:handlePage3
if %1==1 echo Tastatur / Maus Tweaks ausgeführt. (Platzhalter)
if %1==2 echo Controller Tweaks ausgeführt. (Platzhalter)
if %1==3 echo USB Tweaks ausgeführt. (Platzhalter)
pause
exit /b

:handlePage4
if %1==1 echo 3rd Party Tools installiert. (Platzhalter)
if %1==2 echo Tools Update geprüft. (Platzhalter)
if %1==3 echo Installierte Tools aufgelistet. (Platzhalter)
pause
exit /b

:handlePage5
if %1==1 echo Logs & Temp Files gelöscht. (Platzhalter)
if %1==2 echo Autostart bereinigt. (Platzhalter)
if %1==3 echo Dienste optimiert / Extras ausgeführt. (Platzhalter)
pause
exit /b





























