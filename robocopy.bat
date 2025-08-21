@echo off
setlocal enabledelayedexpansion

:: Robocopy Backup Script - Enhanced Version
:: Documentation: https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/robocopy
:: 
:: Usage: robocopy.bat [source_user] [dest_user] [/dryrun]
:: Example: robocopy.bat Kalle Aaron
:: Example: robocopy.bat Kalle Aaron /dryrun

:: Interactive prompts for drive letters and users
echo ===============================================
echo Interactive Robocopy Backup Setup
echo ===============================================

:: Prompt for source drive (required)
:prompt_source_drive
set /p "SOURCE_DRIVE=Enter source drive letter (required): "
if "%SOURCE_DRIVE%"=="" (
    echo ERROR: Source drive letter is required!
    goto prompt_source_drive
)

:: Prompt for source user (required)
:prompt_source_user
set /p "SOURCE_USER=Enter source username (required): "
if "%SOURCE_USER%"=="" (
    echo ERROR: Source username is required!
    goto prompt_source_user
)

:: Prompt for destination drive (required)
:prompt_dest_drive
set /p "DEST_DRIVE=Enter destination drive letter (required): "
if "%DEST_DRIVE%"=="" (
    echo ERROR: Destination drive letter is required!
    goto prompt_dest_drive
)

:: Prompt for destination user (required)
:prompt_dest_user
set /p "DEST_USER=Enter destination username (required): "
if "%DEST_USER%"=="" (
    echo ERROR: Destination username is required!
    goto prompt_dest_user
)

:: Prompt for dry run
set /p "DRY_RUN_INPUT=Run in dry-run mode? (y/N): "
if /i "%DRY_RUN_INPUT%"=="y" set "DRY_RUN=/dryrun"
if /i "%DRY_RUN_INPUT%"=="yes" set "DRY_RUN=/dryrun"

:: Set paths using variables
set "SOURCE_BASE=%SOURCE_DRIVE%:\Users\%SOURCE_USER%"
set "DEST_BASE=%DEST_DRIVE%:\Users\%DEST_USER%"
set "LOG_DIR=%DEST_DRIVE%:\robocopy\logs"

:: Initialize counters
set /a SUCCESS_COUNT=0
set /a FAILED_COUNT=0

:: Create log directory if it doesn't exist
if not exist "%LOG_DIR%" (
    echo Creating log directory: %LOG_DIR%
    mkdir "%LOG_DIR%" 2>nul
    if !errorlevel! neq 0 (
        echo ERROR: Could not create log directory: %LOG_DIR%
        pause
        exit /b 1
    )
)

:: Generate timestamp
call :GenerateTimestamp TIMESTAMP

:: Display configuration
echo.
echo ===============================================
echo Robocopy Backup Configuration
echo ===============================================
echo Source User: %SOURCE_USER%
echo Destination User: %DEST_USER%
echo Source Base: %SOURCE_BASE%
echo Destination Base: %DEST_BASE%
echo Log Directory: %LOG_DIR%
if "%DRY_RUN%"=="/dryrun" echo Mode: DRY RUN (no files will be copied)
echo Timestamp: %TIMESTAMP%
echo ===============================================
echo.

:: Set robocopy flags
set "ROBOCOPY_FLAGS=/E /W:0 /R:0 /copy:dat /XO /dcopy:t /MT:8 /nfl /ndl"
if "%DRY_RUN%"=="/dryrun" set "ROBOCOPY_FLAGS=%ROBOCOPY_FLAGS% /L"

:: Define folders to sync
set "FOLDERS=desktop documents downloads music pictures videos favorites"

:: Process each folder
for %%f in (%FOLDERS%) do (
    call :SyncFolder "%%f" "%SOURCE_BASE%\%%f" "%DEST_BASE%\%%f" "%LOG_DIR%\%%f_log_%TIMESTAMP%.txt"
)

:: Display summary
echo.
echo ===============================================
echo Backup Summary
echo ===============================================
echo Successful: %SUCCESS_COUNT%
echo Failed: %FAILED_COUNT%
echo Total: %/a SUCCESS_COUNT+FAILED_COUNT%
echo ===============================================
echo.

if %FAILED_COUNT% gtr 0 (
    echo WARNING: Some operations failed. Check log files for details.
    exit /b 1
) else (
    echo All operations completed successfully.
    exit /b 0
)

:: Function to generate timestamp
:GenerateTimestamp
set hh=%time:~-11,2%
set /a hh=%hh%+100
set hh=%hh:~1%
set "%~1=%date:~10,4%_%date:~4,2%_%date:~7,2%_%hh%_%time:~3,2%_%time:~6,2%"
goto :eof

:: Function to sync a folder
:SyncFolder
set "FOLDER_NAME=%~1"
set "SOURCE_PATH=%~2"
set "DEST_PATH=%~3"
set "LOG_FILE=%~4"

echo Processing %FOLDER_NAME%...

:: Check if source directory exists
if not exist "%SOURCE_PATH%" (
    echo   WARNING: Source directory does not exist: %SOURCE_PATH%
    echo   Skipping %FOLDER_NAME%
    set /a FAILED_COUNT+=1
    goto :eof
)

:: Create destination directory if it doesn't exist
if not exist "%DEST_PATH%" (
    echo   Creating destination directory: %DEST_PATH%
    mkdir "%DEST_PATH%" 2>nul
)

:: Run robocopy
echo   Source: %SOURCE_PATH%
echo   Destination: %DEST_PATH%
echo   Log: %LOG_FILE%

robocopy "%SOURCE_PATH%" "%DEST_PATH%" %ROBOCOPY_FLAGS% /log:"%LOG_FILE%"

:: Check result (robocopy exit codes: 0-7 are success, 8+ are errors)
if !errorlevel! lss 8 (
    echo   SUCCESS: %FOLDER_NAME% completed successfully
    set /a SUCCESS_COUNT+=1
) else (
    echo   ERROR: %FOLDER_NAME% failed with exit code !errorlevel!
    set /a FAILED_COUNT+=1
)
echo.
goto :eof
