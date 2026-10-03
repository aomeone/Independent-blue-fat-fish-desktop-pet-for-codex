@echo off
setlocal
set "PS_EXE=pwsh.exe"
where "%PS_EXE%" >nul 2>&1
if errorlevel 1 set "PS_EXE=powershell.exe"
"%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
if errorlevel 1 (
  echo.
  echo Installation failed.
  pause
  exit /b 1
)
echo.
pause
