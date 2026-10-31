@echo off
rem Runs analysis and tests and writes logs to build\claude_verify\.
rem Double-click to run. Optional: pass "goldens" to regenerate golden images.
setlocal
cd /d "%~dp0.."
set OUT=build\claude_verify
if not exist "%OUT%" mkdir "%OUT%"
del /q "%OUT%\*.log" "%OUT%\done.txt" 2>nul

set FLUTTER=flutter
where flutter >nul 2>nul
if errorlevel 1 (
  if exist "%USERPROFILE%\flutter\bin\flutter.bat" (
    set FLUTTER="%USERPROFILE%\flutter\bin\flutter.bat"
  ) else (
    echo No se encontro Flutter > "%OUT%\done.txt"
    exit /b 1
  )
)

echo Ejecutando verificacion... no cierres esta ventana.
call %FLUTTER% --version > "%OUT%\version.log" 2>&1
call %FLUTTER% pub get > "%OUT%\pub.log" 2>&1
set PUB=%ERRORLEVEL%
call %FLUTTER% analyze --fatal-infos > "%OUT%\analyze.log" 2>&1
set ANALYZE=%ERRORLEVEL%
if /i "%~1"=="goldens" (
  call %FLUTTER% test --no-pub --update-goldens -r expanded > "%OUT%\test.log" 2>&1
) else (
  call %FLUTTER% test --no-pub -r expanded > "%OUT%\test.log" 2>&1
)
set TEST=%ERRORLEVEL%
echo pub=%PUB% analyze=%ANALYZE% test=%TEST% > "%OUT%\done.txt"
echo Listo. pub=%PUB% analyze=%ANALYZE% test=%TEST%
timeout /t 5 >nul
