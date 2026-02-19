@echo off
setlocal EnableDelayedExpansion
title KenV2

:: ================================
:: BASIC CONFIG
:: ================================

set "APP_NAME=KenV2"
set "VERSION=1.0.0"
set "REPO_OWNER=27migu"
set "REPO_NAME=KenV2"

set "BASE_DIR=%~dp0"
set "LOG_FILE=%BASE_DIR%KenV2.log"

set "TEMP_UPDATE=%TEMP%\KenV2_update.bat"
set "TEMP_PAYLOAD=%TEMP%\KenV2_payload.zip"
set "TEMP_HASH=%TEMP%\hash.txt"

:: ================================
:: ADMIN CHECK
:: ================================

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Administratorrechte erforderlich.
    pause
    exit
)

:: ================================
:: LOG FUNCTION
:: ================================

:log
echo [%date% %time%] %~1 >> "%LOG_FILE%"
exit /b

:: ================================
:: MAIN MENU
:: ================================

:menu
cls
echo ========================================
echo              %APP_NAME% v%VERSION%
echo ========================================
echo.
echo 1 - Check for Update
echo 2 - Download 3rd Party Tools
echo 3 - Exit
echo.
set /p choice=Select option:

if "%choice%"=="1" call :check_update
if "%choice%"=="2" call :download_payload
if "%choice%"=="3" exit

goto menu

:: ================================
:: CHECK FOR UPDATE (GITHUB API)
:: ================================

:check_update
cls
echo Checking GitHub for latest release...

for /f "tokens=2 delims=:, " %%A in ('curl -s https://api.github.com/repos/%REPO_OWNER%/%REPO_NAME%/releases/latest ^| findstr tag_name') do (
    set LATEST=%%~A
)

set LATEST=%LATEST:"=%

if "%LATEST%"=="v%VERSION%" (
    echo You are up to date.
    pause
    goto menu
)

echo New version found: %LATEST%
echo Downloading update...

curl -L -o "%TEMP_UPDATE%" "https://github.com/%REPO_OWNER%/%REPO_NAME%/releases/download/%LATEST%/KenV2.bat"
curl -L -o "%TEMP_HASH%" "https://github.com/%REPO_OWNER%/%REPO_NAME%/releases/download/%LATEST%/KenV2.sha256"

call :verify_hash "%TEMP_UPDATE%" "%TEMP_HASH%"
if errorlevel 1 (
    echo Update verification failed.
    pause
    goto menu
)

echo Installing update...
copy /Y "%TEMP_UPDATE%" "%BASE_DIR%KenV2_new.bat" >nul

echo.
echo Restarting updated version...
start "" "%BASE_DIR%KenV2_new.bat"
exit

:: ================================
:: DOWNLOAD PAYLOAD (3RD PARTY)
:: ================================

:download_payload
cls
echo Downloading 3rd party tools...

for /f "tokens=2 delims=:, " %%A in ('curl -s https://api.github.com/repos/%REPO_OWNER%/%REPO_NAME%/releases/latest ^| findstr tag_name') do (
    set LATEST=%%~A
)

set LATEST=%LATEST:"=%

curl -L -o "%TEMP_PAYLOAD%" "https://github.com/%REPO_OWNER%/%REPO_NAME%/releases/download/%LATEST%/KenV2Payload.zip"
curl -L -o "%TEMP_HASH%" "https://github.com/%REPO_OWNER%/%REPO_NAME%/releases/download/%LATEST%/KenV2Payload.sha256"

call :verify_hash "%TEMP_PAYLOAD%" "%TEMP_HASH%"
if errorlevel 1 (
    echo Payload verification failed.
    pause
    goto menu
)

echo Extracting payload...
mkdir "%BASE_DIR%Tools" 2>nul
tar -xf "%TEMP_PAYLOAD%" -C "%BASE_DIR%Tools"

call :log "Payload installed successfully"

echo Done.
pause
goto menu

:: ================================
:: HASH VERIFICATION FUNCTION
:: ================================

:verify_hash
set FILE=%~1
set HASHFILE=%~2

for /f %%H in ('certutil -hashfile "%FILE%" SHA256 ^| findstr /R "^[0-9A-F]"') do set DOWN_HASH=%%H
set /p EXPECTED_HASH=<"%HASHFILE%"

if /I "%DOWN_HASH%"=="%EXPECTED_HASH%" (
    exit /b 0
) else (
    exit /b 1
)
