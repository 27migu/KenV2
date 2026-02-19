@echo off
setlocal EnableDelayedExpansion

:: ===============================
:: CONFIG
:: ===============================
set "APP_NAME=KenV2"
set "VERSION=2.0.0"
set "BASE_DIR=%~dp0"
set "LOG_DIR=%BASE_DIR%logs"
set "LOG_FILE=%LOG_DIR%\%APP_NAME%.log"
set "CONFIG_FILE=%BASE_DIR%config.ini"
set "UPDATE_URL=https://yourdomain.com/KenV2.zip"
set "UPDATE_HASH_URL=https://yourdomain.com/KenV2.sha256"

if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

call :log "Application started"

:: ===============================
:: ADMIN CHECK
:: ===============================
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Administratorrechte erforderlich.
    pause
    exit /b
)

:: ===============================
:: LOAD CONFIG
:: ===============================
if not exist "%CONFIG_FILE%" (
    echo first_run=true > "%CONFIG_FILE%"
)

:: ===============================
:: MAIN MENU
:: ===============================
:menu
cls
echo ==========================================
echo              %APP_NAME% v%VERSION%
echo ==========================================
echo.
echo 1 - System Info
echo 2 - Network Optimizations
echo 3 - Safe Temp Cleanup
echo 4 - Check for Updates
echo 5 - Exit
echo.
set /p choice=Select option:

if "%choice%"=="1" call :systeminfo
if "%choice%"=="2" call :network
if "%choice%"=="3" call :cleantemp
if "%choice%"=="4" call :update
if "%choice%"=="5" exit /b

goto menu

:: ===============================
:: SYSTEM INFO
:: ===============================
:systeminfo
cls
echo ===== SYSTEM INFORMATION =====
for /f "tokens=2 delims==" %%A in ('wmic cpu get name /value ^| find "="') do set CPU=%%A
for /f "tokens=2 delims==" %%A in ('wmic computersystem get totalphysicalmemory /value ^| find "="') do set RAM=%%A

echo CPU: %CPU%
echo.

echo GPUs:
for /f "skip=1 delims=" %%A in ('wmic path win32_VideoController get name') do (
    if not "%%A"=="" echo   - %%A
)

set /a RAM_GB=%RAM:~0,-6% / 1024
echo.
echo RAM: %RAM_GB% GB
echo.
pause
goto menu

:: ===============================
:: NETWORK TWEAKS (SAFE)
:: ===============================
:network
cls
echo Applying network optimizations...

netsh int tcp set global autotuninglevel=normal >nul
netsh int tcp set global chimney=enabled >nul
netsh int tcp set global rss=enabled >nul

call :log "Network tweaks applied"
echo Done.
pause
goto menu

:: ===============================
:: SAFE TEMP CLEANUP
:: ===============================
:cleantemp
cls
echo Cleaning user temp files only...

del /s /q "%TEMP%\*" >nul 2>&1

call :log "Temp cleaned"
echo Done.
pause
goto menu

:: ===============================
:: UPDATE SYSTEM (HASH VERIFIED)
:: ===============================
:update
cls
echo Checking for updates...

set "TEMP_ZIP=%TEMP%\update.zip"
set "TEMP_HASH=%TEMP%\update.sha256"

curl -L -o "%TEMP_ZIP%" "%UPDATE_URL%"
curl -L -o "%TEMP_HASH%" "%UPDATE_HASH_URL%"

for /f %%H in ('certutil -hashfile "%TEMP_ZIP%" SHA256 ^| findstr /R /C:"^[0-9A-F]"') do set DOWNLOADED_HASH=%%H
set /p EXPECTED_HASH=<"%TEMP_HASH%"

if /I "%DOWNLOADED_HASH%"=="%EXPECTED_HASH%" (
    echo Hash verified.
    echo Extracting update...
    tar -xf "%TEMP_ZIP%" -C "%BASE_DIR%"
    call :log "Update installed"
    echo Update complete. Restart tool.
) else (
    echo Hash mismatch. Update aborted.
    call :log "Update failed - hash mismatch"
)

pause
goto menu

:: ===============================
:: LOG FUNCTION
:: ===============================
:log
echo [%date% %time%] %~1 >> "%LOG_FILE%"
exit /b









