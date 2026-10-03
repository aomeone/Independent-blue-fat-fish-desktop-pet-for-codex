@echo off
setlocal
set "PS_EXE=pwsh.exe"
where "%PS_EXE%" >nul 2>&1
if errorlevel 1 set "PS_EXE=powershell.exe"
"%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-pet.ps1" %*
if errorlevel 1 (
  echo.
  echo Could not start the Codex whale pet.
  echo Make sure Python 3 and PySide6 are installed:
  echo   py -3 -m pip install -r standalone\requirements.txt
  pause
  exit /b 1
)
