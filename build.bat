@echo off
echo Building Team Create Enhancement Plugin with Rojo...
echo.

REM Check if Rojo is installed
where rojo >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Rojo is not installed or not in PATH
    echo Please install Rojo from: https://rojo.space/
    pause
    exit /b 1
)

REM Build the plugin
echo Building plugin file...
rojo build default.project.json -o "TeamCreateEnhancer.rbxmx"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo SUCCESS: Plugin built successfully!
    echo Output: TeamCreateEnhancer.rbxmx
    echo.
    echo To install:
    echo 1. Open Roblox Studio
    echo 2. Go to Plugins tab
    echo 3. Click "Plugins Folder"
    echo 4. Copy TeamCreateEnhancer.rbxmx to the plugins folder
    echo 5. Restart Studio
) else (
    echo.
    echo ERROR: Build failed!
    echo Check your project structure and try again.
)

echo.
pause 