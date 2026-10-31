@echo off
rem Copies a few plugin source files to a shallow folder so they can be read.
setlocal
cd /d "%~dp0.."
set SRC=build\claude_verify\fln\flutter_local_notifications-22.3.2\lib\src\platform_specifics
set OUT=build\fln_api
if exist "%OUT%" rmdir /s /q "%OUT%"
mkdir "%OUT%"
copy /y "%SRC%\android\notification_details.dart" "%OUT%\android_notification_details.dart" >nul
copy /y "%SRC%\android\schedule_mode.dart" "%OUT%\android_schedule_mode.dart" >nul
copy /y "%SRC%\android\enums.dart" "%OUT%\android_enums.dart" >nul
copy /y "%SRC%\android\initialization_settings.dart" "%OUT%\android_initialization_settings.dart" >nul
copy /y "%SRC%\darwin\notification_details.dart" "%OUT%\darwin_notification_details.dart" >nul
copy /y "%SRC%\darwin\initialization_settings.dart" "%OUT%\darwin_initialization_settings.dart" >nul
copy /y "%SRC%\darwin\interruption_level.dart" "%OUT%\darwin_interruption_level.dart" >nul
set CACHE=%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev
copy /y "%CACHE%\timezone-0.11.2\lib\timezone.dart" "%OUT%\timezone.dart" >nul
copy /y "%CACHE%\timezone-0.11.2\lib\src\env.dart" "%OUT%\timezone_env.dart" >nul
copy /y "%CACHE%\timezone-0.11.2\lib\src\location.dart" "%OUT%\timezone_location.dart" >nul
echo ok > "%OUT%\done.txt"
