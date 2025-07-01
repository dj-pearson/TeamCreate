#!/bin/bash

echo "Building Team Create Enhancement Plugin with Rojo..."
echo

# Check if Rojo is installed
if ! command -v rojo &> /dev/null; then
    echo "ERROR: Rojo is not installed or not in PATH"
    echo "Please install Rojo from: https://rojo.space/"
    exit 1
fi

# Build the plugin
echo "Building plugin file..."
rojo build default.project.json -o "TeamCreateEnhancer.rbxmx"

if [ $? -eq 0 ]; then
    echo
    echo "SUCCESS: Plugin built successfully!"
    echo "Output: TeamCreateEnhancer.rbxmx"
    echo
    echo "To install:"
    echo "1. Open Roblox Studio"
    echo "2. Go to Plugins tab"
    echo "3. Click 'Plugins Folder'"
    echo "4. Copy TeamCreateEnhancer.rbxmx to the plugins folder"
    echo "5. Restart Studio"
else
    echo
    echo "ERROR: Build failed!"
    echo "Check your project structure and try again."
    exit 1
fi

echo 