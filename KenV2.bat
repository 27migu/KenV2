@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion
title KenV2 Control Center
mode con: cols=110 lines=35

:: ===== ANSI =====
for /f %%a in ('echo prompt $E^| cmd') do set "ESC=%%a"
set "GREEN=%ESC%[92m"
set "RED=%ESC%[91m"
set "YELLOW=%ESC%[93m"
set "CYAN=%ESC%[96m"
set "GRAY=%ESC%[90m"
set "RESET=%ESC%[0m"

:: ===== CONFIG =====
set "VERSION=2.1.0"
set "UPDATE_URL=https://raw.githubusercontent.com/27migu/KenV2/refs/heads/main/version.txt"
set "TARGET=C:\KenV2 Tools"
set "ZIP=%TARGET%\KenV2.zip"
set "LOG=%TARGET%\kenv2.log"
set "URL=https://www.dropbox.com/scl/fo/31xuv7x2futpzb62q21s9/ABlXgEs8K9DTn5IsgtibIs4?rlkey=tuo7xm6y9jorwiai24y7b7v71&dl=1"
set "TOTALPAGES=3"
set "PAGE=1"

:: ===== START =====
call :requireAdmin
call :prepareFolder
call :header
call :checks
call :autoUpdate
call :restorePrompt
call :download
call :extract
call :menu
exit /b

:: ============================================================
:requireAdmin
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo %YELLOW%Adminrechte werden angefordert...%RESET%
    powershell -Command "Start-Process cmd -ArgumentList '/c \"%~s0\"' -Verb RunAs"
    exit
)
exit /b

:: ============================================================
:log
echo [%date% %time%] %~1>>"%LOG%"
exit /b

:: ============================================================
:header
cls
echo %CYAN%════════════════════════════════════════════════════════════════════════════════════════════════════%RESET%
echo %CYAN%   KenV2 Control Center   %GRAY%v%VERSION%%RESET%
echo %CYAN%════════════════════════════════════════════════════════════════════════════════════════════════════%RESET%
exit /b

:: ============================================================
:checks
echo %YELLOW%Systemstatus:%RESET%

echo Admin      : %GREEN%Verbunden%RESET%
call :log Admin OK

ping -n 1 8.8.8.8 >nul 2>&1
if %errorlevel% neq 0 (
    echo Internet   : %RED%Fehlgeschlagen%RESET%
    call :log Internet FAILED
    pause & exit
) else (
    echo Internet   : %GREEN%Verbunden%RESET%
)

where curl >nul 2>&1
if %errorlevel% neq 0 (
    echo Curl       : %RED%Fehlgeschlagen%RESET%
    call :log Curl FAILED
    pause & exit
) else (
    echo Curl       : %GREEN%Verbunden%RESET%
)

echo.
timeout /t 1 >nul
exit /b

:: ============================================================
:autoUpdate
echo %GRAY%Pruefe auf Updates...%RESET%
curl -s "%UPDATE_URL%" -o "%TEMP%\kv_version.txt"

if exist "%TEMP%\kv_version.txt" (
    set /p NEWVER=<"%TEMP%\kv_version.txt"
    if not "!NEWVER!"=="" if not "!NEWVER!"=="%VERSION%" (
        echo %YELLOW%Neue Version verfuegbar: !NEWVER!%RESET%
        choice /c JN /m "Jetzt aktualisieren?"
        if errorlevel 2 exit /b

        echo %CYAN%Update wird heruntergeladen...%RESET%
        curl -L "https://raw.githubusercontent.com/27migu/KenV2/refs/heads/main/KenV2.bat" -o "%TEMP%\KenV2_new.bat"
        if exist "%TEMP%\KenV2_new.bat" (
            echo %GREEN%Update erfolgreich.%RESET%
            timeout /t 1 >nul
            echo %CYAN%Starte Update...%RESET%
            move /Y "%TEMP%\KenV2_new.bat" "%~f0" >nul
            start "" "%~f0"
            exit
        ) else (
            echo %RED%Update fehlgeschlagen.%RESET%
            pause
        )
    )
)
del "%TEMP%\kv_version.txt" >nul 2>&1
exit /b

:: ============================================================
:restorePrompt
choice /c JN /n /m "Wiederherstellungspunkt erstellen? (J/N): "
if errorlevel 2 exit /b
echo %CYAN%Erstelle Wiederherstellungspunkt...%RESET%
powershell -Command "Checkpoint-Computer -Description 'KenV2 Restore' -RestorePointType 'Modify_Settings'" >>"%LOG%" 2>&1
echo %GREEN%Fertig.%RESET%
timeout /t 1 >nul
exit /b

:: ============================================================
:prepareFolder
if exist "%TARGET%" (
    echo %YELLOW%Alter Ordner wird entfernt...%RESET%
    rmdir /s /q "%TARGET%"
)
mkdir "%TARGET%"
exit /b

:: ============================================================
:download
echo.
echo %CYAN%Download gestartet...%RESET%
call :log Download started

:: animierter Ladebalken + Curl
curl -L --progress-bar "%URL%" -o "%ZIP%"

if not exist "%ZIP%" (
    echo %RED%Download fehlgeschlagen.%RESET%
    call :log Download FAILED
    pause & exit
)

echo %GREEN%Download abgeschlossen.%RESET%
timeout /t 1 >nul
exit /b

:: ============================================================
:extract
echo %CYAN%Entpacke Dateien...%RESET%
powershell -Command "Expand-Archive -Force '%ZIP%' '%TARGET%'" >>"%LOG%" 2>&1
del "%ZIP%"
echo %GREEN%Installation abgeschlossen.%RESET%
timeout /t 1 >nul
exit /b

:: ============================================================
:menu
:menuLoop
cls
call :header
echo %GRAY%Seite %PAGE% von %TOTALPAGES%%RESET%
echo ───────────────────────────────────────────────────────────

if %PAGE%==1 call :page1
if %PAGE%==2 call :page2
if %PAGE%==3 call :page3

echo ───────────────────────────────────────────────────────────
echo [1-3] Option   [N] Weiter   [P] Zurueck   [Q] Beenden
choice /c 123NPQ /n /m "Auswahl: "
set "sel=%errorlevel%"

if %sel%==4 (
    set /a PAGE+=1
    if %PAGE% gtr %TOTALPAGES% set PAGE=1
    goto menuLoop
)
if %sel%==5 (
    set /a PAGE-=1
    if %PAGE% lss 1 set PAGE=%TOTALPAGES%
    goto menuLoop
)
if %sel%==6 exit /b

if %PAGE%==1 call :handlePage1 %sel%
if %PAGE%==2 call :handlePage2 %sel%
if %PAGE%==3 call :handlePage3 %sel%

goto menuLoop

:: ============================================================
:page1
echo [1] Systeminformationen anzeigen
echo [2] Temp Dateien bereinigen
echo [3] Log Datei anzeigen
exit /b

:page2
echo [1] Explorer neu starten
echo [2] Platzhalter
echo [3] Platzhalter
exit /b

:page3
echo [1] GPU Modul (kommt spaeter)
echo [2] Platzhalter
echo [3] Platzhalter
exit /b

:: ============================================================
:handlePage1
if %1==1 systeminfo
if %1==2 del /s /q C:\Windows\Temp\* >nul 2>&1
if %1==3 type "%LOG%"
pause
exit /b

:handlePage2
if %1==1 taskkill /f /im explorer.exe & start explorer.exe
pause
exit /b

:handlePage3
echo GPU Modul wird spaeter integriert.
pause
exit /b

