@echo off
echo ========================================================
echo       ScanCraft: Building Release APK with JDK 17
echo ========================================================

set "JAVA_HOME=C:\Users\srkamd\jdk-17\jdk-17.0.20.1+1"
set "PATH=%JAVA_HOME%\bin;%PATH%"

cd /d "C:\Users\srkamd\.gemini\antigravity\scratch\scancraft\android"

echo.
echo Running Gradle assembleRelease...
echo.

call gradlew.bat assembleRelease

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================================
    echo      SUCCESS! Release APK generated successfully!
    echo ========================================================
    echo.
    echo Location:
    echo C:\Users\srkamd\.gemini\antigravity\scratch\scancraft\build\app\outputs\flutter-apk\app-release.apk
    echo.
    explorer.exe /select,"C:\Users\srkamd\.gemini\antigravity\scratch\scancraft\build\app\outputs\flutter-apk\app-release.apk"
) else (
    echo.
    echo [ERROR] Build failed. Please check the error messages above.
)

pause
