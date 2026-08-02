@echo off
setlocal EnableExtensions DisableDelayedExpansion

REM Keep the caller's working directory: it is the default scan root.
REM Prefer python.exe so an active virtual/Conda environment (and its Rich
REM package) is honored, then fall back to the Windows Python launcher.
where python.exe >nul 2>&1
if errorlevel 1 goto try_py
python -c "import sys; raise SystemExit(0 if sys.version_info >= (3, 8) else 1)" >nul 2>&1
if errorlevel 1 goto try_py
python "%~dp0gitstatall.py" %*
exit /b %errorlevel%

:try_py
where py.exe >nul 2>&1
if errorlevel 1 goto no_python
py -3 -c "import sys; raise SystemExit(0 if sys.version_info >= (3, 8) else 1)" >nul 2>&1
if errorlevel 1 goto old_python
py -3 "%~dp0gitstatall.py" %*
exit /b %errorlevel%

:old_python
echo ERROR: gitstatall requires Python 3.8 or newer. 1>&2
exit /b 2

:no_python
echo ERROR: Python 3.8 or newer was not found on PATH. 1>&2
exit /b 2
