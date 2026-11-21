@echo off
setlocal
:: Fixed release build; stale arbitrary-version packaging is rejected.
if not "%~1"=="" (
  echo Use installer\build_installer.bat without arguments for the verified 1.0.1 build.
  exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_release.ps1"
exit /b %errorlevel%
