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
echo.
echo Drücke eine taste zum Fortfahren!
    pause > NUL
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
set "TOTALPAGES=6"
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
if %PAGE%==6 call :page6

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
    if %PAGE%==6 call :handlePage6 %sel%
)
goto menuStart






:: ==========================
:: MAIN MENU
:: ==========================

:page1
cls
call :printHeader

echo %CYAN%================ Windows & System Tweaks =================%RESET%
echo.
echo   [1] Windows Debloat / Bloatware entfernen
echo   [2] BIOS Safe Settings Tweaks
echo.
echo %GRAY%B = Zurück ins Hauptmenü%RESET%
echo.

set /p "CHOICE=Auswahl: "

if /i "%CHOICE%"=="1" goto windowsDebloat
if /i "%CHOICE%"=="2" goto biosTweaks
if /i /i "%CHOICE%"=="B" goto menuStart
goto page1



:windowsDebloat
cls
call :printHeader
echo %CYAN%===== Windows Debloat & Tweaks =====%RESET%
echo.

:: --- Restore Point ---
echo   [R] Restore Point erstellen
echo.

:: --- Debloat Optionen ---
echo   [1] Telemetrie & Tracking deaktivieren
echo   [2] Cortana deaktivieren
echo   [3] OneDrive deinstallieren
echo   [4] Store Apps entfernen
echo   [5] Delete Temp / Log / Old Files
echo   [6] Activity History deaktivieren
echo   [7] Consumer Features deaktivieren
echo   [8] Hibernation deaktivieren
echo   [9] Location Tracking deaktivieren
echo  [10] Biometrics deaktivieren
echo  [11] Widgets entfernen
echo  [12] PowerShell 7 Telemetry deaktivieren
echo  [13] Browser Debloat (Edge, Chrome, Brave)
echo  [14] Disable FSE / Defender Performance Hits
echo  [15] Netzwerk Tweaks (IPv6, Teredo, Prefer IPv4)
echo  [16] Remove MC Edge / Home from Explorer
echo  [17] Game DVR & Game Mode deaktivieren
echo  [18] User Tracking komplett deaktivieren
echo.
echo %GRAY%B = Zurück%RESET%
echo.

set /p "DEB_CHOICE=Auswahl: "

:: ==========================
:: Restore Point
:: ==========================
if /i "%DEB_CHOICE%"=="R" (
    echo Erstelle Restore Point...
    powershell -Command "Checkpoint-Computer -Description 'KenV2 Backup' -RestorePointType 'MODIFY_SETTINGS'"
    echo Restore Point erstellt.
    pause
    goto windowsDebloat
)

:: ==========================
:: Telemetrie & Tracking
:: ==========================
if /i "%DEB_CHOICE%"=="1" (
    echo Deaktiviere Telemetrie & Tracking...
    sc stop "DiagTrack" >nul 2>&1
    sc config "DiagTrack" start=disabled >nul 2>&1
    sc stop "dmwappushservice" >nul 2>&1
    sc config "dmwappushservice" start=disabled >nul 2>&1
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f >nul 2>&1
    echo Telemetrie & Tracking deaktiviert.
    pause
    goto windowsDebloat
)

:: ==========================
:: Cortana
:: ==========================
if /i "%DEB_CHOICE%"=="2" (
    echo Deaktiviere Cortana...
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v AllowCortana /t REG_DWORD /d 0 /f >nul 2>&1
    echo Cortana deaktiviert.
    pause
    goto windowsDebloat
)

:: ==========================
:: OneDrive
:: ==========================
if /i "%DEB_CHOICE%"=="3" (
    echo OneDrive deinstallieren...
    taskkill /f /im OneDrive.exe >nul 2>&1
    %SystemRoot%\SysWOW64\OneDriveSetup.exe /uninstall >nul 2>&1
    echo OneDrive deinstalliert.
    pause
    goto windowsDebloat
)

:: ==========================
:: Store Apps
:: ==========================
if /i "%DEB_CHOICE%"=="4" (
    echo Entferne Store Apps...
    powershell -Command "Get-AppxPackage -AllUsers | Remove-AppxPackage" >nul 2>&1
    echo Store Apps entfernt.
    pause
    goto windowsDebloat
)

:: ==========================
:: Temp / Log / Old Files löschen
:: ==========================
if /i "%DEB_CHOICE%"=="5" (
    echo Lösche Temp, Log & Old Files...
    rd /s /q "%TEMP%" >nul 2>&1
    rd /s /q "%SystemRoot%\Temp" >nul 2>&1
    del /f /s /q "%USERPROFILE%\AppData\Local\Temp\*" >nul 2>&1
    del /f /s /q "%USERPROFILE%\AppData\Local\Microsoft\Windows\INetCache\*" >nul 2>&1
    echo Temporäre Dateien gelöscht.
    pause
    goto windowsDebloat
)

:: ==========================
:: Activity History
:: ==========================
if /i "%DEB_CHOICE%"=="6" (
    echo Activity History deaktivieren...
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Privacy" /v LetAppsAccessAccountInfo /t REG_DWORD /d 0 /f >nul 2>&1
    echo Activity History deaktiviert.
    pause
    goto windowsDebloat
)

:: ==========================
:: Consumer Features
:: ==========================
if /i "%DEB_CHOICE%"=="7" (
    echo Consumer Features deaktivieren...
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableConsumerFeatures /t REG_DWORD /d 1 /f >nul 2>&1
    echo Consumer Features deaktiviert.
    pause
    goto windowsDebloat
)

:: ==========================
:: Hibernation
:: ==========================
if /i "%DEB_CHOICE%"=="8" (
    echo Hibernation deaktivieren...
    powercfg -h off
    echo Hibernation deaktiviert.
    pause
    goto windowsDebloat
)

:: ==========================
:: Location Tracking
:: ==========================
if /i "%DEB_CHOICE%"=="9" (
    echo Location Tracking deaktivieren...
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" /v DisableLocation /t REG_DWORD /d 1 /f >nul 2>&1
    echo Location Tracking deaktiviert.
    pause
    goto windowsDebloat
)

:: ==========================
:: Biometrics
:: ==========================
if /i "%DEB_CHOICE%"=="10" (
    echo Biometrics deaktivieren...
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Biometrics" /v Enabled /t REG_DWORD /d 0 /f >nul 2>&1
    echo Biometrics deaktiviert.
    pause
    goto windowsDebloat
)

:: ==========================
:: Widgets entfernen
:: ==========================
if /i "%DEB_CHOICE%"=="11" (
    echo Widgets entfernen...
    powershell -Command "Get-AppxPackage MicrosoftWindows.Client.WebExperience | Remove-AppxPackage" >nul 2>&1
    echo Widgets entfernt.
    pause
    goto windowsDebloat
)

:: ==========================
:: PowerShell 7 Telemetry
:: ==========================
if /i "%DEB_CHOICE%"=="12" (
    echo PowerShell 7 Telemetrie deaktivieren...
    reg add "HKLM\SOFTWARE\Policies\Microsoft\PowerShell" /v EnableTelemetry /t REG_DWORD /d 0 /f >nul 2>&1
    echo PowerShell 7 Telemetrie deaktiviert.
    pause
    goto windowsDebloat
)

:: ==========================
:: Browser Debloat
:: ==========================
if /i "%DEB_CHOICE%"=="13" (
    echo Browser Debloat (Edge, Chrome, Brave)...
    powershell -Command "Get-AppxPackage *Edge* | Remove-AppxPackage" >nul 2>&1
    powershell -Command "Get-AppxPackage *Brave* | Remove-AppxPackage" >nul 2>&1
    echo Browser Debloat ausgeführt.
    pause
    goto windowsDebloat
)

:: ==========================
:: FSE / Defender Performance Hits
:: ==========================
if /i "%DEB_CHOICE%"=="14" (
    echo Disable FSE / Defender Performance Hits...
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Scan" /v DisableRealtimeMonitoring /t REG_DWORD /d 1 /f >nul 2>&1
    echo Defender Performance Tweaks ausgeführt.
    pause
    goto windowsDebloat
)

:: ==========================
:: Netzwerk Tweaks
:: ==========================
if /i "%DEB_CHOICE%"=="15" (
    echo Netzwerk Tweaks anwenden...
    netsh interface ipv6 set teredo disabled
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" /v DisabledComponents /t REG_DWORD /d 0x20 /f >nul 2>&1
    echo IPv6 / Teredo / Prefer IPv4 over IPv6 angewendet.
    pause
    goto windowsDebloat
)

:: ==========================
:: Remove MC Edge / Home from Explorer
:: ==========================
if /i "%DEB_CHOICE%"=="16" (
    echo MC Edge & Home aus Explorer entfernen...
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel" /v {F4E57C4C-61B3-41F2-97AC-800F0F3B22D9} /t REG_DWORD /d 1 /f
    echo Entfernt.
    pause
    goto windowsDebloat
)

:: ==========================
:: Game DVR & Game Mode
:: ==========================
if /i "%DEB_CHOICE%"=="17" (
    echo Game DVR & Game Mode deaktivieren...
    reg add "HKLM\SOFTWARE\Microsoft\PolicyManager\default\GameDVR" /v AllowGameDVR /t REG_DWORD /d 0 /f
    reg add "HKLM\SOFTWARE\Microsoft\PolicyManager\default\GameDVR" /v AllowGameMode /t REG_DWORD /d 0 /f
    echo Game DVR & Game Mode deaktiviert.
    pause
    goto windowsDebloat
)

:: ==========================
:: User Tracking komplett
:: ==========================
if /i "%DEB_CHOICE%"=="18" (
    echo User Tracking deaktivieren...
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Privacy" /v TailoredExperiencesWithDiagnosticDataEnabled /t REG_DWORD /d 0 /f >nul 2>&1
    echo User Tracking deaktiviert.
    pause
    goto windowsDebloat
)

if /i "%DEB_CHOICE%"=="B" goto page1
goto windowsDebloat




:biosTweaks
cls
call :printHeader
echo %CYAN%===== BIOS Safe Tweaks =====%RESET%
echo.
echo   [1] Fast Boot deaktivieren
echo   [2] C-States deaktivieren / freischalten
echo   [3] Hyper-V deaktivieren
echo   [4] Powersaving Features deaktivieren
echo.
echo %GRAY%B = Zurück%RESET%
echo.

set /p "BIOS_CHOICE=Auswahl: "

:: ==========================
:: Fast Boot deaktivieren
:: ==========================
if /i "%BIOS_CHOICE%"=="1" (
    echo Deaktiviere Fast Boot...
    :: Fast Boot kann über BCDEdit beeinflusst werden
    bcdedit /set {current} bootstatuspolicy ignoreallfailures >nul 2>&1
    bcdedit /set {current} bootlog off >nul 2>&1
    echo Fast Boot wurde deaktiviert.
    pause
    goto biosTweaks
)

:: ==========================
:: C-States deaktivieren / freischalten
:: ==========================
if /i "%BIOS_CHOICE%"=="2" (
    echo C-States deaktivieren / freischalten...
    :: Registry Key sichtbar machen
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\5d76a2ca-e8c0-402f-a133-2158492d58ad" /v Attributes /t REG_DWORD /d 0 /f >nul 2>&1
    :: PowerCfg Option sichtbar machen
    powercfg -attributes SUB_PROCESSOR 5d76a2ca-e8c0-402f-a133-2158492d58ad -ATTRIB_HIDE >nul 2>&1
    echo C-States Einstellungen freigeschaltet. Bitte über Energieoptionen anpassen.
    pause
    goto biosTweaks
)

:: ==========================
:: Hyper-V deaktivieren
:: ==========================
if /i "%BIOS_CHOICE%"=="3" (
    echo Deaktiviere Hyper-V...
    dism /Online /Disable-Feature:Microsoft-Hyper-V-All /Quiet /NoRestart
    echo Hyper-V wurde deaktiviert.
    pause
    goto biosTweaks
)

:: ==========================
:: Powersaving Features deaktivieren
:: ==========================
if /i "%BIOS_CHOICE%"=="4" (
    echo Deaktiviere Powersaving Features...
    :: Beispiel: alle Energiesparmodi auf Höchstleistung
    powercfg -setactive SCHEME_MIN >nul 2>&1
    echo Alle Powersaving Features auf maximale Leistung gesetzt.
    pause
    goto biosTweaks
)

if /i "%BIOS_CHOICE%"=="B" goto page1

goto biosTweaks




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

if /I "!GPU_TYPE!"=="NVIDIA" goto nvidiaMenu
if /I "!GPU_TYPE!"=="AMD" goto amdMenu
if /I "!GPU_TYPE!"=="INTEL" goto intelMenu

echo Keine unterstützte GPU erkannt.
pause
goto page2



:nvidiaMenu
cls
call :printHeader
echo.
echo %CYAN%============== NVIDIA Tweaks ==============%RESET%
echo.
echo   [1] NVIDIA Telemetry Tasks deaktivieren
echo   [2] Shader Cache leeren
echo   [3] Hardware GPU Scheduling (HAGS)
echo   [4] MPO Toggle
echo   [5] TDR Delay setzen
echo.
echo %GRAY%[B] Zurück%RESET%
choice /c 12345B /n /m "Auswahl: "

if errorlevel 6 goto hardwareGPU
if errorlevel 5 goto setTDR
if errorlevel 4 goto mpoMenu
if errorlevel 3 goto hagsMenu
if errorlevel 2 goto clearNVCache
if errorlevel 1 goto nvTelemetry



:nvTelemetry
echo Deaktiviere NVIDIA Telemetry Tasks...
schtasks /Change /TN "NvTmRep" /Disable 2>nul
schtasks /Change /TN "NvDriverUpdateCheckDaily" /Disable 2>nul
schtasks /Change /TN "NvDriverUpdateCheckDaily_{*}" /Disable 2>nul
sc stop "NvTelemetryContainer"
sc config "NvTelemetryContainer" start= disabled
sc stop "NvContainerTelemetryApi"
sc config "NvContainerTelemetryApi" start= disabled
echo Fertig.
pause
goto nvidiaMenu


:clearNVCache
echo Leere NVIDIA Shader Cache...
rd /s /q "%localappdata%\NVIDIA\DXCache" 2>nul
rd /s /q "%localappdata%\NVIDIA\GLCache" 2>nul
rd /s /q "%localappdata%\D3DSCache" 2>nul
del /f /s /q "%localappdata%\NVIDIA Corporation\NV_Cache\*"
echo Cache gelöscht.
pause
goto nvidiaMenu


:hagsMenu
cls
echo ==== HAGS ====
echo.
echo [1] Aktivieren
echo [2] Deaktivieren
echo.
echo [B] Zurück
choice /c 12B /n /m "Auswahl: "

if errorlevel 3 goto nvidiaMenu
if errorlevel 2 reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v HwSchMode /t REG_DWORD /d 0 /f
if errorlevel 1 reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v HwSchMode /t REG_DWORD /d 2 /f

echo Einstellung gesetzt. Neustart nötig.
pause
goto nvidiaMenu


:mpoMenu
cls
echo ==== MPO ====
echo.
echo [1] MPO deaktivieren
echo [2] MPO aktivieren
echo.
echo [B] Zurück
choice /c 12B /n /m "Auswahl: "

if errorlevel 3 goto nvidiaMenu
if errorlevel 2 reg delete "HKLM\SOFTWARE\Microsoft\Windows\Dwm" /v OverlayTestMode /f
if errorlevel 1 reg add "HKLM\SOFTWARE\Microsoft\Windows\Dwm" /v OverlayTestMode /t REG_DWORD /d 5 /f

echo Einstellung gesetzt. Neustart nötig.
pause
goto nvidiaMenu


:setTDR
reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v TdrDelay /t REG_DWORD /d 10 /f
echo TDR Delay auf 10 Sekunden gesetzt.
pause
goto nvidiaMenu


:amdMenu
cls
call :printHeader
echo.
echo %CYAN%============== AMD Tweaks ==============%RESET%
echo.
echo   [1] Shader Cache leeren
echo   [2] ULPS deaktivieren (Multi GPU)
echo   [3] HAGS Toggle
echo   [4] MPO Toggle
echo   [5] TDR Delay setzen
echo.
echo %GRAY%[B] Zurück%RESET%
choice /c 12345B /n /m "Auswahl: "

if errorlevel 6 goto hardwareGPU
if errorlevel 5 goto setTDR
if errorlevel 4 goto mpoMenu
if errorlevel 3 goto hagsMenu
if errorlevel 2 goto amdUlps
if errorlevel 1 goto clearAMDCache



:clearAMDCache
echo Leere AMD Shader Cache...
rd /s /q "%localappdata%\AMD\DxCache" 2>nul
rd /s /q "%localappdata%\AMD\GLCache" 2>nul
rd /s /q "%localappdata%\D3DSCache" 2>nul
echo Cache gelöscht.
pause
goto amdMenu


:amdUlps
echo Deaktiviere ULPS (falls vorhanden)...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Video\{*}\0000" /v EnableUlps /t REG_DWORD /d 0 /f 2>nul
echo Vorgang ausgeführt (wirkt nur bei Multi-GPU).
pause
goto amdMenu


:intelMenu
cls
call :printHeader
echo.
echo %CYAN%============== Intel GPU Tweaks ==============%RESET%
echo.
echo   [1] Shader Cache leeren
echo   [2] HAGS Toggle
echo   [3] MPO Toggle
echo.
echo %GRAY%[B] Zurück%RESET%
choice /c 123B /n /m "Auswahl: "

if errorlevel 4 goto hardwareGPU
if errorlevel 3 goto mpoMenu
if errorlevel 2 goto hagsMenu
if errorlevel 1 goto clearIntelCache


:clearIntelCache
rd /s /q "%localappdata%\D3DSCache" 2>nul
echo Cache gelöscht.
pause
goto intelMenu




:: ==========================
:: RAM Unterseite
:: ==========================
:hardwareRAM
cls
call :printHeader
echo.
echo %CYAN%================== RAM Tweaks ==================%RESET%
echo.
echo RAM: !RAM_GB! GB
echo.
echo   [1] Memory Compression (MMAgent)
echo   [2] LargeSystemCache
echo   [3] Memory Integrity (HVCI)
echo   [4] Pagefile Settings
echo   [5] Apply Performance Profile
echo   [6] HVSplit / SvcHostSplitThreshold
echo.
echo %GRAY%[B] Zurück%RESET%
choice /c 123456B /n /m "Auswahl: "

if errorlevel 7 goto page2
if errorlevel 6 goto hvsMenu
if errorlevel 5 goto ramProfile
if errorlevel 4 goto pagefileMenu
if errorlevel 3 goto hvciMenu
if errorlevel 2 goto largeCacheMenu
if errorlevel 1 goto mmaMenu



:mmaMenu
cls
echo ==== Memory Compression ====
echo.
echo [1] Deaktivieren (weniger CPU Overhead)
echo [2] Aktivieren (besser bei wenig RAM)
echo.
echo [B] Zurück
choice /c 12B /n /m "Auswahl: "

if errorlevel 3 goto hardwareRAM
if errorlevel 2 powershell Enable-MMAgent -mc
if errorlevel 1 powershell Disable-MMAgent -mc

echo Vorgang abgeschlossen. Neustart empfohlen.
pause
goto mmaMenu






:largeCacheMenu
cls
echo ==== LargeSystemCache ====
echo.
echo [1] Deaktivieren (Gaming empfohlen)
echo [2] Aktivieren (Server Style)
echo.
echo [B] Zurück
choice /c 12B /n /m "Auswahl: "

if errorlevel 3 goto hardwareRAM
if errorlevel 2 reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v LargeSystemCache /t REG_DWORD /d 1 /f
if errorlevel 1 reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v LargeSystemCache /t REG_DWORD /d 0 /f

echo Einstellung gesetzt.
pause
goto largeCacheMenu




:hvciMenu
cls
echo ==== Memory Integrity (HVCI) ====
echo.
echo [1] Deaktivieren (mehr Performance)
echo [2] Aktivieren (mehr Sicherheit)
echo.
echo [B] Zurück
choice /c 12B /n /m "Auswahl: "

if errorlevel 3 goto hardwareRAM
if errorlevel 2 reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v EnableVirtualizationBasedSecurity /t REG_DWORD /d 1 /f
if errorlevel 1 reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v EnableVirtualizationBasedSecurity /t REG_DWORD /d 0 /f

echo Änderung gesetzt. Neustart notwendig.
pause
goto hvciMenu





:pagefileMenu
cls
echo ==== Pagefile ====
echo.
echo [1] Systemverwaltet (empfohlen)
echo [2] Deaktivieren (nur ab 32GB RAM)
echo.
echo [B] Zurück
choice /c 12B /n /m "Auswahl: "

if errorlevel 3 goto hardwareRAM
if errorlevel 2 goto pagefileOff
if errorlevel 1 goto pagefileAuto

:pagefileAuto
wmic computersystem where name="%computername%" set AutomaticManagedPagefile=True
echo Pagefile systemverwaltet.
pause
goto pagefileMenu

:pagefileOff
wmic computersystem where name="%computername%" set AutomaticManagedPagefile=False
wmic pagefileset delete
echo Pagefile deaktiviert.
pause
goto pagefileMenu





:ramProfile
echo Wende RAM Performance Profil an...

reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v LargeSystemCache /t REG_DWORD /d 0 /f
powershell Disable-MMAgent -mc
wmic computersystem where name="%computername%" set AutomaticManagedPagefile=True

echo Fertig. Neustart empfohlen.
pause
goto hardwareRAM



:: ==========================
:: HVSPLIT / SvcHostSplitThreshold
:: ==========================
:hvsMenu
cls
call :printHeader
echo.
echo %CYAN%==== HVSplit / SvcHostSplitThreshold ====%RESET%
echo.
echo Erkannt: !RAM_GB! GB RAM
echo.
echo [1] Automatisch optimal setzen
echo [2] Standard Windows Wert wiederherstellen
echo [B] Zurück
choice /c 12B /n /m "Auswahl: "

if errorlevel 3 goto hardwareRAM
if errorlevel 2 goto hvsDefault
if errorlevel 1 goto hvsAuto

:: ===== Automatisch =====
:hvsAuto
set /a splitValue=!RAM_GB!*1048576
reg add "HKLM\SYSTEM\CurrentControlSet\Control" ^
    /v SvcHostSplitThresholdInKB ^
    /t REG_DWORD ^
    /d !splitValue! ^
    /f
echo HVSplit auf !splitValue! KB gesetzt.
pause
goto hvsMenu

:: ===== Standard Windows Wert =====
:hvsDefault
reg delete "HKLM\SYSTEM\CurrentControlSet\Control" /v SvcHostSplitThresholdInKB /f
echo HVSplit auf Standard zurückgesetzt.
pause
goto hvsMenu











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

if errorlevel 4 goto page2
if errorlevel 3 goto storageGeneral
if errorlevel 2 goto storageHDD
if errorlevel 1 goto storageSSD



:storageSSD
cls
call :printHeader
echo.
echo %CYAN%==== SSD Optimierungen ====%RESET%
echo.
echo [1] TRIM aktivieren
echo [2] Defrag deaktivieren (nur HDD sinnvoll)
echo [3] Superfetch (SysMain) deaktivieren
echo [4] Write Cache aktivieren
echo.
echo %GRAY%[B] Zurück%RESET%
choice /c 1234B /n /m "Auswahl: "

if errorlevel 5 goto hardwareStorage
if errorlevel 4 goto ssdCache
if errorlevel 3 goto ssdSuperfetch
if errorlevel 2 goto ssdDefrag
if errorlevel 1 goto ssdTrim

:ssdTrim
fsutil behavior set DisableDeleteNotify 0
echo TRIM aktiviert.
pause
goto storageSSD

:ssdDefrag
schtasks /Change /TN "\Microsoft\Windows\Defrag\ScheduledDefrag" /Disable
echo Geplantes Defrag deaktiviert.
pause
goto storageSSD

:ssdSuperfetch
sc stop SysMain
sc config SysMain start= disabled
echo SysMain deaktiviert.
pause
goto storageSSD

:ssdCache
echo Write-Cache sollte im Geräte-Manager aktiviert sein.
pause
goto storageSSD



:storageHDD
cls
call :printHeader
echo.
echo %CYAN%==== HDD Optimierungen ====%RESET%
echo.
echo [1] Defrag aktivieren
echo [2] NTFS LastAccess deaktivieren
echo [3] Write Cache aktivieren
echo.
echo %GRAY%[B] Zurück%RESET%
choice /c 123B /n /m "Auswahl: "

if errorlevel 4 goto hardwareStorage
if errorlevel 3 goto hddCache
if errorlevel 2 goto hddLastAccess
if errorlevel 1 goto hddDefrag

:hddDefrag
schtasks /Change /TN "\Microsoft\Windows\Defrag\ScheduledDefrag" /Enable
echo Defrag aktiviert.
pause
goto storageHDD

:hddLastAccess
fsutil behavior set disablelastaccess 1
echo NTFS LastAccess deaktiviert.
pause
goto storageHDD

:hddCache
echo Write-Cache im Geräte-Manager aktivieren.
pause
goto storageHDD



:storageGeneral
cls
call :printHeader
echo.
echo %CYAN%==== Allgemeine Storage Tweaks ====%RESET%
echo.
echo [1] NTFS Memory Usage erhöhen
echo [2] Disable 8.3 Filename Creation
echo [3] Disable Paging Executive
echo.
echo %GRAY%[B] Zurück%RESET%
choice /c 123B /n /m "Auswahl: "

if errorlevel 4 goto hardwareStorage
if errorlevel 3 goto disablePaging
if errorlevel 2 goto disable83
if errorlevel 1 goto ntfsMemory

:ntfsMemory
fsutil behavior set memoryusage 2
echo NTFS Memory Usage erhöht.
pause
goto storageGeneral

:disable83
fsutil behavior set disable8dot3 1
echo 8.3 Dateinamen deaktiviert.
pause
goto storageGeneral

:disablePaging
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" ^
/v DisablePagingExecutive ^
/t REG_DWORD ^
/d 1 ^
/f
echo DisablePagingExecutive aktiviert.
pause
goto storageGeneral





:page3
cls
call :printHeader
echo.
echo %CYAN%================== Peripherals Tweaks ==================%RESET%
echo.
echo   [1] Keyboard / Mouse (MKB) Tweaks
echo   [2] Controller (CRR) Tweaks
echo   [3] USB Tweaks
echo.
echo %GRAY%[B] Zurück%RESET%
choice /c 123B /n /m "Auswahl: "

if errorlevel 4 goto page2
if errorlevel 3 goto usbMenu
if errorlevel 2 goto crrMenu
if errorlevel 1 goto mkbMenu



:mkbMenu
cls
call :printHeader
echo.
echo %CYAN%==== Keyboard / Mouse Performance ====%RESET%
echo.
echo   [1] Disable Mouse Acceleration (wichtig)
echo   [2] Apply 1:1 Mouse Input (SmoothMouse Fix)
echo   [3] Max Keyboard Repeat Rate
echo   [4] Disable Filter Keys
echo   [5] Apply Competitive MKB Profile (All in One)
echo.
echo %GRAY%[B] Zurück%RESET%
choice /c 12345B /n /m "Auswahl: "

if errorlevel 6 goto page3
if errorlevel 5 goto mkbCompetitive
if errorlevel 4 goto filterKeysOff
if errorlevel 3 goto kbRepeat
if errorlevel 2 goto smoothMouse
if errorlevel 1 goto mouseAccel


:mouseAccel
reg add "HKCU\Control Panel\Mouse" /v MouseSpeed /t REG_SZ /d 0 /f
reg add "HKCU\Control Panel\Mouse" /v MouseThreshold1 /t REG_SZ /d 0 /f
reg add "HKCU\Control Panel\Mouse" /v MouseThreshold2 /t REG_SZ /d 0 /f
echo Mausbeschleunigung deaktiviert.
pause
goto mkbMenu



:smoothMouse
reg add "HKCU\Control Panel\Mouse" /v SmoothMouseXCurve /t REG_BINARY ^
/d 0000000000000000000000000000000000000000000000000000000000000000 /f

reg add "HKCU\Control Panel\Mouse" /v SmoothMouseYCurve /t REG_BINARY ^
/d 0000000000000000000000000000000000000000000000000000000000000000 /f

echo Mouse Curve neutralisiert (1:1 Input).
pause
goto mkbMenu


:kbRepeat
reg add "HKCU\Control Panel\Keyboard" /v KeyboardSpeed /t REG_SZ /d 31 /f
reg add "HKCU\Control Panel\Keyboard" /v KeyboardDelay /t REG_SZ /d 0 /f
echo Keyboard Repeat Rate maximiert.
pause
goto mkbMenu


:filterKeysOff
reg add "HKCU\Control Panel\Accessibility\Keyboard Response" ^
/v Flags /t REG_SZ /d 122 /f
echo Filter Keys deaktiviert.
pause
goto mkbMenu



:mkbCompetitive
call :mouseAccel
call :smoothMouse
call :kbRepeat
call :filterKeysOff
echo Competitive MKB Profil angewendet.
pause
goto mkbMenu





:crrMenu
cls
call :printHeader
echo.
echo %CYAN%==== Controller Tweaks ====%RESET%
echo.
echo   [1] Disable Vibration
echo   [2] Max Polling Rate
echo   [3] Controller Deadzone Min
echo.
echo %GRAY%[B] Zurück%RESET%
choice /c 123B /n /m "Auswahl: "

if errorlevel 4 goto page3
if errorlevel 3 goto crrDeadzone
if errorlevel 2 goto crrPoll
if errorlevel 1 goto crrVib

:crrVib
echo Controller Vibration deaktiviert...
:: ggf. Registry oder Tool Befehl
pause
goto crrMenu

:crrPoll
echo Controller Polling Rate optimiert...
pause
goto crrMenu

:crrDeadzone
echo Controller Deadzone minimal gesetzt...
pause
goto crrMenu




:usbMenu
cls
call :printHeader
echo.
echo %CYAN%==== USB Performance Tweaks ====%RESET%
echo.
echo   [1] Disable USB Selective Suspend
echo   [2] Disable USB Hub Power Saving
echo   [3] Apply Full USB Performance Profile
echo   [4] Restore Windows Default
echo.
echo %GRAY%[B] Zurück%RESET%
choice /c 1234B /n /m "Auswahl: "

if errorlevel 5 goto page3
if errorlevel 4 goto usbDefault
if errorlevel 3 goto usbFull
if errorlevel 2 goto usbHub
if errorlevel 1 goto usbSuspend



:usbSuspend
powercfg -setacvalueindex SCHEME_CURRENT SUB_USB USBSELECTIVE SUSPEND 0
powercfg -setdcvalueindex SCHEME_CURRENT SUB_USB USBSELECTIVE SUSPEND 0
powercfg -setactive SCHEME_CURRENT
echo USB Selective Suspend deaktiviert.
pause
goto usbMenu



:usbHub
reg add "HKLM\SYSTEM\CurrentControlSet\Services\USB" /v DisableSelectiveSuspend /t REG_DWORD /d 1 /f
echo USB Hub Power Saving deaktiviert.
pause
goto usbMenu



:usbFull
call :usbSuspend
call :usbHub
echo USB Performance Profil angewendet.
echo Neustart empfohlen.
pause
goto usbMenu




:usbDefault
powercfg -setacvalueindex SCHEME_CURRENT SUB_USB USBSELECTIVE SUSPEND 1
powercfg -setdcvalueindex SCHEME_CURRENT SUB_USB USBSELECTIVE SUSPEND 1
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\USB" /v DisableSelectiveSuspend /f
powercfg -setactive SCHEME_CURRENT
echo USB Einstellungen zurückgesetzt.
pause
goto usbMenu






:page4
cls
call :printHeader
echo.
echo %CYAN%================ 3rd Party Tools ================%RESET%
echo.
echo   [1] Autoruns
echo   [2] DDU

echo.
echo %GRAY%[B] Zurück%RESET%
choice /c 12B /n /m "Auswahl: "

if errorlevel 3 goto page2
if errorlevel 2 goto toolDDU
if errorlevel 1 goto toolAutoruns




:toolAutoruns
cls
if exist "C:\KenV2\Tools\Autoruns64.exe" (
    echo Starte Autoruns...
    start "" "C:\KenV2\Tools\Autoruns64.exe"
) else (
    echo Autoruns nicht gefunden.
    pause
)
goto page4





:toolDDU
cls
if exist "C:\KenV2\Tools\DisplayDriverUninstaller.exe" (
    echo Starte DDU...
    start "" "C:\KenV2\Tools\DisplayDriverUninstaller.exe"
) else (
    echo DDU nicht gefunden.
    pause
)
goto page4






:page5
:cleanapps
cls
call :printHeader
echo.
echo %CYAN%============= Chrome & Discord Tweaks =============%RESET%
echo.
echo   [1] Chrome Cache löschen
echo   [2] Chrome Effizienz Modus aktivieren
echo   [3] Discord Cache löschen
echo   [4] Discord Hardwarebeschleunigung deaktivieren
echo   [5] Discord Overlay deaktivieren
echo.
echo %GRAY%[B] Zurück%RESET%
choice /c 12345B /n /m "Auswahl: "

if errorlevel 6 goto page5
if errorlevel 5 goto discordOverlay
if errorlevel 4 goto discordHW
if errorlevel 3 goto discordClean
if errorlevel 2 goto chromeEfficiency
if errorlevel 1 goto chromeClean




:chromeClean
taskkill /f /im chrome.exe >nul 2>&1

rd /s /q "%LOCALAPPDATA%\Google\Chrome\User Data\Default\Cache" >nul 2>&1
rd /s /q "%LOCALAPPDATA%\Google\Chrome\User Data\Default\GPUCache" >nul 2>&1
rd /s /q "%LOCALAPPDATA%\Google\Chrome\User Data\Default\Code Cache" >nul 2>&1

echo Chrome Cache gelöscht.
pause
goto cleanApps




:chromeEfficiency
taskkill /f /im chrome.exe >nul 2>&1

powershell -Command ^
"$path = '$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Preferences'; ^
$json = Get-Content $path -Raw | ConvertFrom-Json; ^
$json.background_mode.enabled = $false; ^
$json.hardware_acceleration_mode.enabled = $false; ^
$json | ConvertTo-Json -Depth 100 | Set-Content $path"

echo Chrome Hardwarebeschleunigung & Background Mode deaktiviert.
pause
goto cleanApps




:discordClean
taskkill /f /im discord.exe >nul 2>&1

rd /s /q "%APPDATA%\Discord\Cache" >nul 2>&1
rd /s /q "%APPDATA%\Discord\Code Cache" >nul 2>&1
rd /s /q "%APPDATA%\Discord\GPUCache" >nul 2>&1

echo Discord Cache gelöscht.
pause
goto cleanApps



:discordHW
taskkill /f /im discord.exe >nul 2>&1

powershell -Command ^
"$path = '$env:APPDATA\Discord\settings.json'; ^
if (Test-Path $path) { ^
    $json = Get-Content $path -Raw | ConvertFrom-Json; ^
    $json.enableHardwareAcceleration = $false; ^
    $json | ConvertTo-Json -Depth 100 | Set-Content $path ^
}"

echo Discord Hardwarebeschleunigung deaktiviert.
pause
goto cleanApps



:discordOverlay
taskkill /f /im discord.exe >nul 2>&1

powershell -Command ^
"$path = '$env:APPDATA\Discord\settings.json'; ^
if (Test-Path $path) { ^
    $json = Get-Content $path -Raw | ConvertFrom-Json; ^
    if ($json.PSObject.Properties.Name -contains 'overlay') { $json.overlay = $false }; ^
    $json | ConvertTo-Json -Depth 100 | Set-Content $path ^
}"

echo Discord Overlay deaktiviert.
pause
goto cleanApps











:page6
cls
call :printHeader
echo.
echo %CYAN%================== Network Tweaks ==================%RESET%
echo.

echo   [1] Low-Latency Profile (Gaming / Fortnite)
echo   [2] High-Throughput Profile (Downloads / Epic / Steam)
echo   [3] VPN & Proxy deaktivieren
echo   [4] NetBIOS over IPv4 deaktivieren
echo   [5] Getaktete Verbindung deaktivieren
echo   [6] DNS Server auf High Performance setzen
echo   [7] Netzwerkkennung & Freigaben deaktivieren
echo   [8] Nutzungstatistiken zurücksetzen
echo   [9] Energieoptionen Netzwerk deaktivieren
echo   [A] IPv6 & Teredo Tweaks
echo   [B] Zurück zum Hauptmenü
echo.
set /p "NET_CHOICE=Auswahl: "

:: ==========================
:: Netzwerkadapter / Treiber Tweaks (Low-Latency Optimiert)
:: ==========================
if /i "%NET_CHOICE%"=="9" (
    echo Netzwerkadapter Low-Latency Tweaks anwenden...
    for /f "tokens=2 delims==" %%a in ('wmic nic where "NetEnabled=true" get Name /value ^| find "="') do (
        set "ADAPTER=%%a"
        echo Adapter erkannt: !ADAPTER!

        :: ==========================
        :: Offload & Energie Tweaks
        :: ==========================
        powershell -Command "Set-NetAdapterAdvancedProperty -Name '!ADAPTER!' -DisplayName 'Energy Efficient Ethernet' -DisplayValue 'Disabled'"
        powershell -Command "Set-NetAdapterAdvancedProperty -Name '!ADAPTER!' -DisplayName 'Interrupt Moderation' -DisplayValue 'Disabled'"
        powershell -Command "Set-NetAdapterAdvancedProperty -Name '!ADAPTER!' -DisplayName 'Flow Control' -DisplayValue 'Disabled'"
        powershell -Command "Set-NetAdapterAdvancedProperty -Name '!ADAPTER!' -DisplayName 'Priority & VLAN' -DisplayValue 'Enabled'"
        powershell -Command "Set-NetAdapterAdvancedProperty -Name '!ADAPTER!' -DisplayName 'Jumbo Packet' -DisplayValue 'Disabled'"
        powershell -Command "Set-NetAdapterAdvancedProperty -Name '!ADAPTER!' -DisplayName 'Transmit Buffers' -DisplayValue '512'"
        powershell -Command "Set-NetAdapterAdvancedProperty -Name '!ADAPTER!' -DisplayName 'Receive Buffers' -DisplayValue '512'"
        powershell -Command "Set-NetAdapterAdvancedProperty -Name '!ADAPTER!' -DisplayName 'Wake on Magic Packet' -DisplayValue 'Disabled'"
        powershell -Command "Set-NetAdapterAdvancedProperty -Name '!ADAPTER!' -DisplayName 'Receive Side Scaling' -DisplayValue 'Disabled'"

        :: ==========================
        :: Offload Deaktivieren (IPv4 & IPv6)
        :: ==========================
        powershell -Command "Set-NetAdapterAdvancedProperty -Name '!ADAPTER!' -DisplayName 'TCP Checksum Offload (IPv4)' -DisplayValue 'Disabled'"
        powershell -Command "Set-NetAdapterAdvancedProperty -Name '!ADAPTER!' -DisplayName 'TCP Checksum Offload (IPv6)' -DisplayValue 'Disabled'"
        powershell -Command "Set-NetAdapterAdvancedProperty -Name '!ADAPTER!' -DisplayName 'UDP Checksum Offload (IPv4)' -DisplayValue 'Disabled'"
        powershell -Command "Set-NetAdapterAdvancedProperty -Name '!ADAPTER!' -DisplayName 'UDP Checksum Offload (IPv6)' -DisplayValue 'Disabled'"
        powershell -Command "Set-NetAdapterAdvancedProperty -Name '!ADAPTER!' -DisplayName 'Large Send Offload v2 (IPv4)' -DisplayValue 'Disabled'"
        powershell -Command "Set-NetAdapterAdvancedProperty -Name '!ADAPTER!' -DisplayName 'Large Send Offload v2 (IPv6)' -DisplayValue 'Disabled'"
        powershell -Command "Set-NetAdapterAdvancedProperty -Name '!ADAPTER!' -DisplayName 'Receive Segment Coalescing (RSC)' -DisplayValue 'Disabled'"

        :: ==========================
        :: TCP/IP Global Optimierungen
        :: ==========================
        netsh int tcp set global autotuninglevel=disabled
        netsh int tcp set global congestionprovider=ctcp
        netsh int tcp set global chimney=disabled
        netsh int tcp set global rss=disabled
        netsh int tcp set global rsc=disabled
        netsh int tcp set global timestamps=disabled
        netsh int tcp set global sack=enabled
        netsh int tcp set global dca=enabled
        netsh int tcp set global initialRto=2000
        netsh int tcp set global MaxSynRetransmissions=2
        netsh int tcp set global TcpTimedWaitDelay=30
        netsh int tcp set global TcpMaxDataRetransmissions=5
        netsh int tcp set global TcpNoDelay=enabled

        :: ==========================
        :: MTU & Standard Ethernet Frame
        :: ==========================
        netsh interface ipv4 set subinterface "Ethernet" mtu=1500 store=persistent
    )
    echo Alle Low-Latency Netzwerkadapter Tweaks angewendet.
    pause
    goto page6
)


:: ==========================
:: High-Throughput Profile
:: ==========================
if /i "%NET_CHOICE%"=="2" (
    echo High-Throughput Profile anwenden...

    :: TCP/IP Tweaks für maximale Geschwindigkeit
    netsh int tcp set global autotuninglevel=normal
    netsh int tcp set global congestionprovider=cubic
    netsh int tcp set global chimney=enabled
    netsh int tcp set global rss=enabled
    netsh int tcp set global rsc=enabled
    netsh int tcp set global timestamps=disabled
    netsh int tcp set global sack=enabled
    netsh int tcp set global dca=enabled
    netsh int tcp set global initialRto=3000
    netsh int tcp set global MaxSynRetransmissions=5
    netsh int tcp set global TcpTimedWaitDelay=60
    netsh int tcp set global TcpMaxDataRetransmissions=10
    netsh interface ipv4 set subinterface "Ethernet" mtu=9000 store=persistent

    :: Netzwerkadapter / Treiber Tweaks
    for /f "tokens=2 delims==" %%a in ('wmic nic where "NetEnabled=true" get Name /value ^| find "="') do (
        set "ADAPTER=%%a"
        echo Adapter erkannt: !ADAPTER!

        powershell -Command "Set-NetAdapterAdvancedProperty -Name '!ADAPTER!' -DisplayName 'Energy Efficient Ethernet' -DisplayValue 'Enabled'"
        powershell -Command "Set-NetAdapterAdvancedProperty -Name '!ADAPTER!' -DisplayName 'Interrupt Moderation' -DisplayValue 'Enabled'"
        powershell -Command "Set-NetAdapterAdvancedProperty -Name '!ADAPTER!' -DisplayName 'Flow Control' -DisplayValue 'Enabled'"
        powershell -Command "Set-NetAdapterAdvancedProperty -Name '!ADAPTER!' -DisplayName 'Priority & VLAN' -DisplayValue 'Enabled'"
        powershell -Command "Set-NetAdapterAdvancedProperty -Name '!ADAPTER!' -DisplayName 'Jumbo Packet' -DisplayValue '9014'"
        powershell -Command "Set-NetAdapterAdvancedProperty -Name '!ADAPTER!' -DisplayName 'Transmit Buffers' -DisplayValue '512'"
        powershell -Command "Set-NetAdapterAdvancedProperty -Name '!ADAPTER!' -DisplayName 'Receive Buffers' -DisplayValue '512'"
        powershell -Command "Set-NetAdapterAdvancedProperty -Name '!ADAPTER!' -DisplayName 'Wake on Magic Packet' -DisplayValue 'Enabled'"
        powershell -Command "Set-NetAdapterAdvancedProperty -Name '!ADAPTER!' -DisplayName 'Receive Side Scaling' -DisplayValue 'Enabled'"
    )

    echo High-Throughput Tweaks angewendet.
    pause
    goto page6
)

:: ==========================
:: VPN & Proxy
:: ==========================
if /i "%NET_CHOICE%"=="3" (
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable /t REG_DWORD /d 0 /f >nul 2>&1
    netsh interface set interface "VPN" admin=disable >nul 2>&1
    echo VPN & Proxy deaktiviert.
    pause
    goto page6
)

:: ==========================
:: NetBIOS over IPv4
:: ==========================
if /i "%NET_CHOICE%"=="4" (
    for /f "tokens=1 delims=:" %%a in ('wmic nicconfig where IPEnabled^=TRUE get index /value') do (
        netsh interface ip set interface %%a netbios=disable
    )
    echo NetBIOS deaktiviert.
    pause
    goto page6
)

:: ==========================
:: Getaktete Verbindung
:: ==========================
if /i "%NET_CHOICE%"=="5" (
    powershell -Command "Set-NetConnectionProfile -NetworkCategory Private"
    echo Getaktete Verbindung deaktiviert.
    pause
    goto page6
)

:: ==========================
:: DNS Server
:: ==========================
if /i "%NET_CHOICE%"=="6" (
    netsh interface ip set dns name="Ethernet" static 1.1.1.1
    netsh interface ip add dns name="Ethernet" 8.8.8.8 index=2
    echo DNS Server gesetzt.
    pause
    goto page6
)

:: ==========================
:: Netzwerkkennung & Freigaben
:: ==========================
if /i "%NET_CHOICE%"=="7" (
    powershell -Command "Set-NetConnectionProfile -NetworkCategory Private -NetworkDiscovery Disabled -Sharing Disabled"
    echo Netzwerkkennung & Freigaben deaktiviert.
    pause
    goto page6
)

:: ==========================
:: Nutzungstatistiken
:: ==========================
if /i "%NET_CHOICE%"=="8" (
    powershell -Command "Clear-NetIPsecCounters"
    echo Nutzungstatistiken zurückgesetzt.
    pause
    goto page6
)

:: ==========================
:: Energieoptionen Netzwerk
:: ==========================
if /i "%NET_CHOICE%"=="9" (
    powercfg -setactive SCHEME_MIN
    echo Energieoptionen angepasst.
    pause
    goto page6
)

:: ==========================
:: IPv6 & Teredo Tweaks
:: ==========================
if /i "%NET_CHOICE%"=="A" (
    netsh interface ipv6 set teredo disabled
    netsh interface ipv6 set privacy disabled
    netsh interface ipv6 set global randomizeidentifiers=disabled
    echo IPv6 & Teredo optimiert.
    pause
    goto page6
)

if /i "%NET_CHOICE%"=="B" goto menuStart
goto page6



























































































