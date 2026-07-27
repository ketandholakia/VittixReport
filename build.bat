@echo off
setlocal

:: Check if msbuild is available
where msbuild >nul 2>nul
if %errorlevel% neq 0 (
    echo msbuild is not in your PATH. Please run this script from a RAD Studio Command Prompt.
    exit /b 1
)

echo =======================================================
echo Building VittixReport...
echo =======================================================

echo.
echo [1/5] Building Runtime Package (Win32)...
msbuild packages\VittixReportRuntime.dproj /p:Config=Release /p:Platform=Win32 /t:Clean;Build
if %errorlevel% neq 0 exit /b %errorlevel%


echo.
echo [3/5] Building Design-time Package (Win32)...
msbuild packages\VittixReportDesign.dproj /p:Config=Release /p:Platform=Win32 /t:Clean;Build
if %errorlevel% neq 0 exit /b %errorlevel%

echo.
echo [4/5] Building Standalone Designer (Win32)...
msbuild vittixdesigner\VittixDesigner.dproj /p:Config=Release /p:Platform=Win32 /t:Clean;Build
if %errorlevel% neq 0 exit /b %errorlevel%

echo.
echo [5/5] Building Standalone Designer (Win64)...
msbuild vittixdesigner\VittixDesigner.dproj /p:Config=Release /p:Platform=Win64 /t:Clean;Build
if %errorlevel% neq 0 exit /b %errorlevel%

echo.
echo =======================================================
echo Build completed successfully!
echo =======================================================
