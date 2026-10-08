@echo off
setlocal
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if exist "%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe" set "PS=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
"%PS%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0CorelWatch.ps1" %*
set "RC=%ERRORLEVEL%"
echo.
if not "%RC%"=="0" (
    echo CorelWatch failed with exit code %RC%. A report may NOT have been created.
    echo Please keep the error text above. CorelDRAW and its settings were not changed by this launcher.
) else (
    echo CorelWatch has stopped. See the report path printed above, if a capture was started.
)
pause
exit /b %RC%
