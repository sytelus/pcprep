set filepath="%~dpn1.ps1"

@echo off
set RESTVAR=
shift
:loop1
if "%~1"=="" goto after_loop
set RESTVAR=%RESTVAR% %1
shift
goto loop1

:after_loop
PowerShell -NoProfile -ExecutionPolicy Bypass -File %filepath% %RESTVAR%
