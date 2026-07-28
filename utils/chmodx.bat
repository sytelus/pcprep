REM Marks a tracked file as executable in Git's index; does not change Windows file permissions.
REM Use it when a script edited on Windows must run directly after checkout on Linux or WSL.
git update-index --chmod=+x %1
