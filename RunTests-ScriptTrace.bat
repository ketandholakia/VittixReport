@echo off
echo Checking for MSBuild...
where msbuild >nul 2>nul
if %errorlevel% neq 0 (
    echo MSBuild not found. Attempting to load Delphi 12 environment...
    if exist "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat" (
        call "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat"
    ) else (
        echo.
        echo ERROR: Could not find rsvars.bat for Delphi 12.
        echo Please run this script from the "RAD Studio Command Prompt" or open the project in Delphi.
        pause
        exit /b 1
    )
)

echo Building VittixRunner...
:: Compiles the project using Delphi's MSBuild
taskkill /f /im VittixRunner.exe >nul 2>nul
msbuild VittixRunner.dproj /p:Config=Debug /p:Platform=Win32
if %errorlevel% neq 0 (
    echo.
    echo MSBuild failed!
    pause
    exit /b %errorlevel%
)

echo.
echo Running script trace diagnostics...
.\bin\Win32\Debug\VittixRunner.exe --script-trace -pause
pause
