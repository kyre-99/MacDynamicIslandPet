#!/bin/bash

# Build script for MacDynamicIslandPet
# Creates a release-ready .app bundle

set -e

echo "🚀 Building MacDynamicIslandPet..."

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf build/Release/*.app
rm -f MacDynamicIslandPet.app.zip

# Build the project
echo "🔨 Building project..."
xcodebuild -project MacDynamicIslandPet.xcodeproj \
    -scheme MacDynamicIslandPet \
    -configuration Release \
    -derivedDataPath build \
    clean build

# Find the built app
APP_PATH=$(find build/Build/Products/Release -name "*.app" -type d | head -1)

if [ -z "$APP_PATH" ]; then
    echo "❌ Build failed - no .app found"
    exit 1
fi

echo "✅ Build successful: $APP_PATH"

# Copy to current directory for easy access
echo "📦 Preparing release package..."
cp -R "$APP_PATH" ./MacDynamicIslandPet.app

# Create zip archive
echo "🗜️ Creating zip archive..."
zip -r MacDynamicIslandPet.app.zip MacDynamicIslandPet.app

# Get app size
APP_SIZE=$(du -h MacDynamicIslandPet.app.zip | cut -f1)
echo "📊 Package size: $APP_SIZE"

# Clean up
rm -rf MacDynamicIslandPet.app

echo "✨ Build complete!"
echo "📦 Release package: MacDynamicIslandPet.app.zip"
echo ""
echo "Next steps:"
echo "1. Upload MacDynamicIslandPet.app.zip to GitHub Releases"
echo "2. Users can download and unzip to run the app"