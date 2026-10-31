@echo off
rem Builds Android debug APK and web release to verify native/web setup.
setlocal
cd /d "%~dp0.."
set OUT=build\claude_verify
if not exist "%OUT%" mkdir "%OUT%"
del /q "%OUT%\build_*.log" "%OUT%\build_done.txt" 2>nul
set FLUTTER=flutter
where flutter >nul 2>nul
if errorlevel 1 set FLUTTER="%USERPROFILE%\flutter\bin\flutter.bat"
call %FLUTTER% build apk --debug > "%OUT%\build_apk.log" 2>&1
set APK=%ERRORLEVEL%
call %FLUTTER% build web --release > "%OUT%\build_web.log" 2>&1
set WEB=%ERRORLEVEL%
echo apk=%APK% web=%WEB% > "%OUT%\build_done.txt"
