@echo off
cd /d "%~dp0"
echo === BUILDING NIZIK ANDROID RELEASE APK ===
flutter clean
if errorlevel 1 goto :fail
flutter pub get
if errorlevel 1 goto :fail
flutter build apk --release
if errorlevel 1 goto :fail
echo.
echo SUCCESS:
echo %CD%\build\app\outputs\flutter-apk\app-release.apk
echo.
pause
exit /b 0
:fail
echo.
echo BUILD FAILED. Copy the error output and send it to ChatGPT.
pause
exit /b 1
