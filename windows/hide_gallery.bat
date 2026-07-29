@echo off
setlocal EnableExtensions DisableDelayedExpansion

REM Hide the Gallery navigation-pane item for the current user. This does not
REM delete files or disable the underlying Windows Gallery feature.

reg.exe add "HKEY_CURRENT_USER\Software\Classes\CLSID\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}" ^
    /v "System.IsPinnedToNameSpaceTree" ^
    /t REG_DWORD ^
    /d 0 ^
    /f >nul || (
        echo ERROR: Failed to hide Gallery in File Explorer.
        exit /b 1
    )

echo Gallery is hidden for the current user. Restart Windows Explorer or sign out to apply the change.
exit /b 0
