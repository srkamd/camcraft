@echo off
echo ========================================================
echo       CamCraft: Building Release APK with JDK 17
echo ========================================================

set "JAVA_HOME=C:\Users\srkamd\jdk-17\jdk-17.0.20.1+1"
set "PATH=%JAVA_HOME%\bin;%PATH%"
set "GRADLE_USER_HOME=%~dp0.gradle"

cd /d "%~dp0android"

echo.
echo Running Gradle assembleRelease...
echo.

call gradlew.bat assembleRelease

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================================
    echo   SUCCESS: Release APK generated successfully.
    echo ========================================================
    echo.
    echo Location:
    echo %~dp0build\app\outputs\flutter-apk\app-release.apk
    echo.
    if exist "%~dp0build\app\outputs\flutter-apk\app-release.apk" (
        explorer.exe /select,"%~dp0build\app\outputs\flutter-apk\app-release.apk"
    )
) else (
    echo.
    echo [ERROR] Build failed.
)
