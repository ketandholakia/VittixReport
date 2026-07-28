@echo off
call "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat"
msbuild vittixdesigner\VittixDesigner.dproj /p:Config=Debug /p:Platform=Win32 /t:Build
