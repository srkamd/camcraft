@echo off
echo ========================================================
echo       ScanCraft: Building Google Play AAB Bundle
echo ========================================================

set "JAVA_HOME=C:\Users\srkamd\jdk-17\jdk-17.0.20.1+1"
set "PATH=%JAVA_HOME%\bin;%PATH%"
set "GRADLE_USER_HOME=%~dp0.gradle"

cd /d "%~dp0android"

echo.
echo Running Gradle bundleRelease...
echo.

call gradlew.bat bundleRelease

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================================
    echo   SUCCESS: Release AAB App Bundle generated.
    echo ========================================================
    echo.
    echo Upload this file to Google Play Console:
    echo %~dp0build\app\outputs\bundle\release\app-release.aab
    echo.
    if exist "%~dp0build\app\outputs\bundle\release\app-release.aab" (
        explorer.exe /select,"%~dp0build\app\outputs\bundle\release\app-release.aab"
    )
) else (
    echo.
    echo [ERROR] Build failed.
)
