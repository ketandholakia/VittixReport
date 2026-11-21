@echo off
setlocal
pushd "%~dp0.."
if not exist "build\installer-tests" mkdir "build\installer-tests"
python "installer\tests\test_installer_policy.py"
if errorlevel 1 goto fail
call "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat"
if errorlevel 1 goto fail
dcc32 -B -Q -U"%BDS%\lib\win32\release" -E"build\installer-tests" -N0"build\installer-tests" "installer\tests\IdeOwnershipTests.dpr"
if errorlevel 1 goto fail
"build\installer-tests\IdeOwnershipTests.exe"
if errorlevel 1 goto fail
popd
exit /b 0
:fail
popd
exit /b 1
