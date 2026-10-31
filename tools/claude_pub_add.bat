@echo off
rem Adds the rest-notification packages and copies their API for review.
setlocal
cd /d "%~dp0.."
set OUT=build\claude_verify
if not exist "%OUT%" mkdir "%OUT%"
del /q "%OUT%\pubadd*.log" "%OUT%\pubadd_done.txt" 2>nul
set FLUTTER=flutter
where flutter >nul 2>nul
if errorlevel 1 set FLUTTER="%USERPROFILE%\flutter\bin\flutter.bat"
call %FLUTTER% pub add flutter_local_notifications timezone > "%OUT%\pubadd.log" 2>&1
set ADD=%ERRORLEVEL%
set CACHE=%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev
if defined PUB_CACHE set CACHE=%PUB_CACHE%\hosted\pub.dev
dir /b /ad "%CACHE%" | findstr /b "flutter_local_notifications" > "%OUT%\pubadd_pkgs.log"
if exist "%OUT%\fln" rmdir /s /q "%OUT%\fln"
mkdir "%OUT%\fln"
for /f "delims=" %%P in ('dir /b /ad "%CACHE%" ^| findstr /b "flutter_local_notifications"') do (
  xcopy /e /i /q /y "%CACHE%\%%P\lib" "%OUT%\fln\%%P\lib" >nul
  copy /y "%CACHE%\%%P\pubspec.yaml" "%OUT%\fln\%%P\" >nul
  if exist "%CACHE%\%%P\README.md" copy /y "%CACHE%\%%P\README.md" "%OUT%\fln\%%P\" >nul
)
echo add=%ADD% > "%OUT%\pubadd_done.txt"
