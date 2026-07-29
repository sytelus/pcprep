@echo off
setlocal EnableExtensions DisableDelayedExpansion

REM git config --global merge.tool bc trustExitCode true
REM git config --global mergetool.bc.path "c:/Program Files/Beyond Compare 4/bcomp.exe"
REM git config --global diff.tool bc trustExitCode true
REM git config --global difftool.bc.path "c:/Program Files/Beyond Compare 4/bcomp.exe"
REM git config --global --add difftool.prompt false
REM git config --global core.autocrlf true

where git.exe >nul 2>&1 || (
    echo ERROR: Git was not found on PATH.
    exit /b 1
)

REM Environment variables take precedence. Otherwise preserve an existing Git
REM identity and prompt only when no value has been configured yet.
if not defined user_name for /f "usebackq delims=" %%V in (`git config --global --get user.name 2^>nul`) do set "user_name=%%V"
if not defined user_email for /f "usebackq delims=" %%V in (`git config --global --get user.email 2^>nul`) do set "user_email=%%V"
if not defined user_name set /p "user_name=Enter your git user name: "
if not defined user_email set /p "user_email=Enter your git email: "

if not defined user_name (
    echo ERROR: Git user name cannot be empty.
    exit /b 1
)

if not defined user_email (
    echo ERROR: Git email cannot be empty.
    exit /b 1
)

git config --global user.name "%user_name%" || exit /b 1
git config --global user.email "%user_email%" || exit /b 1
git config --global url.ssh://git@github.com/.insteadOf https://github.com/ || exit /b 1

REM Use LF line endings and convert CRLF to LF on commit, but not LF to CRLF on checkout.
git config --global core.eol lf || exit /b 1
git config --global core.autocrlf input || exit /b 1

REM git config --global core.editor "'C:/Program Files (x86)/Notepad++/notepad++.exe' -multiInst -notabbar -nosession -noPlugin"
git config --global merge.tool vscode || exit /b 1
git config --global mergetool.vscode.cmd "code --wait $MERGED" || exit /b 1
git config --global diff.tool vscode || exit /b 1
git config --global difftool.vscode.cmd "code --wait --diff $LOCAL $REMOTE" || exit /b 1
git config --global core.editor "code --new-window --wait" || exit /b 1

REM Rebase local commits when pulling divergent history.
git config --global pull.rebase true || exit /b 1

echo Git global configuration updated for %user_name% ^<%user_email%^>.
exit /b 0
