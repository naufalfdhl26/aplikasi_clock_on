@echo off
echo ========================================
echo    BUILD APK - Aplikasi ClockOn
echo ========================================
echo.

echo [1/4] Cleaning previous build...
call flutter clean

echo.
echo [2/4] Getting dependencies...
call flutter pub get

echo.
echo [3/4] Building APK (Release mode)...
call flutter build apk --release

echo.
echo [4/4] Build Complete!
echo.
echo APK Location:
echo build\app\outputs\flutter-apk\app-release.apk
echo.
echo File size:
dir /s build\app\outputs\flutter-apk\app-release.apk | find "app-release.apk"
echo.
echo ========================================
echo Transfer APK ke HP dan install!
echo ========================================
pause
