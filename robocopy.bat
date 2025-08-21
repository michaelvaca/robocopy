Here’s your full script with the persistent menu loop dropped in (and your requested flags: `/FFT`, `/TEE`, `/R:2 /W:2`), plus the session log + sanity checks intact.

```bat
@echo off
setlocal EnableExtensions EnableDelayedExpansion

:: Robocopy Backup Script - Enhanced Version

:: Ensure robocopy exists
where robocopy >nul 2>&1
if errorlevel 1 (
  echo ERROR: robocopy.exe not found. This script requires Robocopy (Windows Vista+).
  pause
  exit /b 1
)

echo ===============================================
echo Interactive Robocopy Backup Setup
echo ===============================================

:: Prompt for source drive (required)
:prompt_source_drive
set /p "SOURCE_DRIVE=Enter source drive letter (required, e.g. C): "
if "%SOURCE_DRIVE%"=="" (
  echo ERROR: Source drive letter is required!
  goto prompt_source_drive
)
:: normalize: strip any colon and keep first char
set "SOURCE_DRIVE=%SOURCE_DRIVE::=%"
set "SOURCE_DRIVE=%SOURCE_DRIVE:~0,1%"

:: Prompt for source user (required)
:prompt_source_user
set /p "SOURCE_USER=Enter source username (required): "
if "%SOURCE_USER%"=="" (
  echo ERROR: Source username is required!
  goto prompt_source_user
)

:: Prompt for destination drive (required)
:prompt_dest_drive
set /p "DEST_DRIVE=Enter destination drive letter (required, e.g. D): "
if "%DEST_DRIVE%"=="" (
  echo ERROR: Destination drive letter is required!
  goto prompt_dest_drive
)
set "DEST_DRIVE=%DEST_DRIVE::=%"
set "DEST_DRIVE=%DEST_DRIVE:~0,1%"

:: Prompt for destination user (required)
:prompt_dest_user
set /p "DEST_USER=Enter destination username (required): "
if "%DEST_USER%"=="" (
  echo ERROR: Destination username is required!
  goto prompt_dest_user
)

:: Prompt for dry run
set /p "DRY_RUN_INPUT=Run in dry-run mode? (y/N): "
if /i "%DRY_RUN_INPUT%"=="y"   set "DRY_RUN=/dryrun"
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

:: Generate timestamp (locale-agnostic)
call :GenerateTimestamp TIMESTAMP

:: Create session log path
set "SESSION_LOG=%LOG_DIR%\session_%TIMESTAMP%.txt"

:: Sanity checks for base paths
if not exist "%SOURCE_BASE%" (
  echo ERROR: Source base path not found: "%SOURCE_BASE%"
  echo Verify the drive letter and username.
  pause
  exit /b 1
)

if not exist "%DEST_BASE%" (
  echo Creating destination base: "%DEST_BASE%"
  mkdir "%DEST_BASE%" 2>nul
  if errorlevel 1 (
    echo ERROR: Could not create destination base: "%DEST_BASE%"
    pause
    exit /b 1
  )
)

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
:: ONLY changes requested: /R:2 /W:2, ensure /FFT present, add /TEE
set "ROBOCOPY_FLAGS=/E /W:2 /R:2 /COPY:DAT /XO /DCOPY:T /MT:8 /NFL /NDL /NJH /NJS /XJ /FFT /TEE"
if "%DRY_RUN%"=="/dryrun" set "ROBOCOPY_FLAGS=%ROBOCOPY_FLAGS% /L"

:: Define folders to sync
set "FOLDERS=Desktop Documents Downloads Music Pictures Videos Favorites"

:: Optional excludes (leave commented unless needed)
:: set "EXCLUDES=/XD OneDrive 'OneDrive - *' AppData .git /XF Thumbs.db desktop.ini 'NTUSER.DAT*'"

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
echo Failed:     %FAILED_COUNT%
set /a TOTAL=SUCCESS_COUNT+FAILED_COUNT
echo Total:      %TOTAL%
echo Log Directory: %LOG_DIR%
echo Session Log: %SESSION_LOG%
echo ===============================================
echo.

:: ===== Persistent Menu Loop =====
:MENU
echo Options:
echo 1. Close this window
echo 2. Open log directory
echo 3. Open session log
echo.
set "USER_CHOICE="
set /p "USER_CHOICE=Choose an option (1-3): "

if "%USER_CHOICE%"=="2" (
  echo Opening log directory...
  start "" "%LOG_DIR%"
  echo.
  goto MENU
) else if "%USER_CHOICE%"=="3" (
  if exist "%SESSION_LOG%" (
    echo Opening session log...
    start "" notepad "%SESSION_LOG%"
  ) else (
    echo No session log found for this run.
  )
  echo.
  goto MENU
) else if "%USER_CHOICE%"=="1" (
  goto END
) else (
  echo Invalid selection. Please choose 1-3.
  echo.
  goto MENU
)

:END
echo.
echo Press any key to exit...
pause >nul
if %FAILED_COUNT% gtr 0 (
  exit /b 1
) else (
  exit /b 0
)

:: -------- Functions --------

:GenerateTimestamp
:: Robust, locale-independent timestamp via PowerShell
for /f %%A in ('powershell -NoProfile -Command "Get-Date -Format yyyy_MM_dd_HH_mm_ss"') do set "%~1=%%A"
goto :eof

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

robocopy "%SOURCE_PATH%" "%DEST_PATH%" %ROBOCOPY_FLAGS% /LOG:"%LOG_FILE%" /LOG+:"%SESSION_LOG%" %EXCLUDES%

:: Check result (robocopy exit codes: 0-7 are success, 8+ are errors)
set "RC=!errorlevel!"
if !RC! lss 8 (
  echo   SUCCESS: %FOLDER_NAME% completed successfully (rc=!RC!)
  set /a SUCCESS_COUNT+=1
) else (
  echo   ERROR: %FOLDER_NAME% failed with exit code !RC!
  set /a FAILED_COUNT+=1
)
echo.
goto :eof
```

