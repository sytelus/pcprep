@echo off
setlocal EnableExtensions DisableDelayedExpansion

set "SOURCE_FILE=%~dp0aliases.doskey"
set "INSTALL_DIRECTORY=%LOCALAPPDATA%\pcprep"
set "AUTORUN_BACKUP=%INSTALL_DIRECTORY%\command-processor-before-pcprep.reg"
set "COMMAND_PROCESSOR_KEY=HKEY_CURRENT_USER\Software\Microsoft\Command Processor"
set "REG_EXE=%SystemRoot%\System32\reg.exe"
set "CMD_EXE=%SystemRoot%\System32\cmd.exe"
set "DOSKEY_EXE=%SystemRoot%\System32\doskey.exe"
set "FINDSTR_EXE=%SystemRoot%\System32\findstr.exe"

if not exist "%SOURCE_FILE%" (
    echo ERROR: Command Prompt aliases file was not found: %SOURCE_FILE%
    exit /b 1
)
for %%I in ("%SOURCE_FILE%") do if %%~zI LEQ 0 (
    echo ERROR: Command Prompt aliases file is empty: %SOURCE_FILE%
    exit /b 1
)
if not defined LOCALAPPDATA (
    echo ERROR: LOCALAPPDATA is not defined for the current user.
    exit /b 1
)
if not exist "%REG_EXE%" (
    echo ERROR: Registry tool was not found: %REG_EXE%
    exit /b 1
)
if not exist "%CMD_EXE%" (
    echo ERROR: Command Prompt was not found: %CMD_EXE%
    exit /b 1
)
if not exist "%DOSKEY_EXE%" (
    echo ERROR: DOSKEY was not found: %DOSKEY_EXE%
    exit /b 1
)
if not exist "%FINDSTR_EXE%" (
    echo ERROR: FINDSTR was not found: %FINDSTR_EXE%
    exit /b 1
)

if not exist "%INSTALL_DIRECTORY%" mkdir "%INSTALL_DIRECTORY%" >nul 2>&1
if not exist "%INSTALL_DIRECTORY%" (
    echo ERROR: Could not create the aliases support directory: %INSTALL_DIRECTORY%
    exit /b 1
)

set "ROLLBACK_FILE=%INSTALL_DIRECTORY%\command-processor-rollback-%RANDOM%-%RANDOM%.reg"
set "VERIFY_FILE=%INSTALL_DIRECTORY%\aliases-verification-%RANDOM%-%RANDOM%.txt"
set "HAD_COMMAND_PROCESSOR_KEY=0"

REM Capture the current key for transaction rollback. Preserve the original
REM pre-pcprep settings separately and never overwrite that persistent backup.
"%REG_EXE%" query "%COMMAND_PROCESSOR_KEY%" >nul 2>&1
if not errorlevel 1 (
    set "HAD_COMMAND_PROCESSOR_KEY=1"
    "%REG_EXE%" export "%COMMAND_PROCESSOR_KEY%" "%ROLLBACK_FILE%" /y >nul 2>&1
    if errorlevel 1 (
        echo ERROR: Existing Command Processor settings could not be backed up.
        echo No registry values were changed.
        exit /b 1
    )
    if not exist "%AUTORUN_BACKUP%" (
        copy /y "%ROLLBACK_FILE%" "%AUTORUN_BACKUP%" >nul
        if errorlevel 1 (
            del /q "%ROLLBACK_FILE%" >nul 2>&1
            echo ERROR: Could not preserve the original Command Processor settings.
            echo No registry values were changed.
            exit /b 1
        )
    )
)

REM Register the aliases file beside this installer as the source of truth. A
REM new Command Prompt therefore sees edits to that file without another copy.
"%REG_EXE%" add "%COMMAND_PROCESSOR_KEY%" ^
    /v AutoRun ^
    /t REG_SZ ^
    /d "if exist \"%SOURCE_FILE%\" \"%DOSKEY_EXE%\" /macrofile=\"%SOURCE_FILE%\"" ^
    /f >nul
if errorlevel 1 (
    echo ERROR: Could not configure Command Prompt aliases.
    call :restore_previous_settings
    exit /b 1
)

REM Prove that a newly started Command Prompt runs AutoRun and receives every
REM macro name from the adjacent aliases file.
"%CMD_EXE%" /q /c "doskey.exe /macros" >"%VERIFY_FILE%" 2>&1
if errorlevel 1 (
    echo ERROR: A new Command Prompt could not load the registered aliases.
    call :restore_previous_settings
    exit /b 1
)
for /f "usebackq tokens=1 delims==" %%A in ("%SOURCE_FILE%") do (
    "%FINDSTR_EXE%" /i /l /b /c:"%%A=" "%VERIFY_FILE%" >nul 2>&1
    if errorlevel 1 (
        echo ERROR: A new Command Prompt did not load alias: %%A
        call :restore_previous_settings
        exit /b 1
    )
)

del /q "%VERIFY_FILE%" >nul 2>&1
if exist "%ROLLBACK_FILE%" del /q "%ROLLBACK_FILE%" >nul 2>&1

echo Command Prompt aliases now load from: %SOURCE_FILE%
echo Open a new Command Prompt window or Command Prompt tab to use them.
exit /b 0

:restore_previous_settings
set "RESTORE_FAILED=0"
del /q "%VERIFY_FILE%" >nul 2>&1
"%REG_EXE%" delete "%COMMAND_PROCESSOR_KEY%" /v AutoRun /f >nul 2>&1
if errorlevel 1 set "RESTORE_FAILED=1"
if "%HAD_COMMAND_PROCESSOR_KEY%"=="1" (
    "%REG_EXE%" import "%ROLLBACK_FILE%" >nul 2>&1
    if errorlevel 1 set "RESTORE_FAILED=1"
)
if "%RESTORE_FAILED%"=="0" (
    del /q "%ROLLBACK_FILE%" >nul 2>&1
) else (
    echo WARNING: Automatic rollback failed. Recovery data remains at:
    echo %ROLLBACK_FILE%
)
exit /b %RESTORE_FAILED%
