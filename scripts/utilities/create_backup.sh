#!/bin/bash

# Jachtproef Alert App Backup Script
# This script creates a clean backup of the Flutter project

# Set backup directory name with timestamp
BACKUP_NAME="jachtproef_alert_backup_$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="../$BACKUP_NAME"

echo "Creating backup: $BACKUP_NAME"
echo "Backup location: $BACKUP_DIR"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Copy essential project files
echo "Copying project files..."

# Copy main project files
cp pubspec.yaml "$BACKUP_DIR/"
cp pubspec.lock "$BACKUP_DIR/"
cp analysis_options.yaml "$BACKUP_DIR/"
cp .metadata "$BACKUP_DIR/"
cp README.md "$BACKUP_DIR/"
cp .gitignore "$BACKUP_DIR/"
cp jachtproef_alert_new.iml "$BACKUP_DIR/"

# Copy documentation files
cp AUTH_TEST_GUIDE.md "$BACKUP_DIR/"
cp FIREBASE_DEBUG_INFO.md "$BACKUP_DIR/"
cp TESTFLIGHT_ICON_SETUP_COMPLETE.md "$BACKUP_DIR/"

# Copy environment file if it exists
if [ -f .env ]; then
    cp .env "$BACKUP_DIR/"
fi

# Copy source code directories
echo "Copying source code..."
cp -r lib/ "$BACKUP_DIR/"
cp -r test/ "$BACKUP_DIR/"

# Copy assets
echo "Copying assets..."
cp -r assets/ "$BACKUP_DIR/"
cp -r store_assets/ "$BACKUP_DIR/"

# Copy platform-specific configuration files (excluding build artifacts)
echo "Copying platform configurations..."

# Android
mkdir -p "$BACKUP_DIR/android"
cp -r android/app/src/ "$BACKUP_DIR/android/app/"
cp android/app/build.gradle "$BACKUP_DIR/android/app/" 2>/dev/null || true
cp android/build.gradle "$BACKUP_DIR/android/" 2>/dev/null || true
cp android/gradle.properties "$BACKUP_DIR/android/" 2>/dev/null || true
cp android/settings.gradle "$BACKUP_DIR/android/" 2>/dev/null || true
cp -r android/gradle/ "$BACKUP_DIR/android/" 2>/dev/null || true

# iOS
mkdir -p "$BACKUP_DIR/ios"
cp -r ios/Runner/ "$BACKUP_DIR/ios/"
cp ios/Podfile "$BACKUP_DIR/ios/" 2>/dev/null || true
cp ios/Podfile.lock "$BACKUP_DIR/ios/" 2>/dev/null || true

# Web
cp -r web/ "$BACKUP_DIR/"

# macOS
mkdir -p "$BACKUP_DIR/macos"
cp -r macos/Runner/ "$BACKUP_DIR/macos/"
cp macos/Podfile "$BACKUP_DIR/macos/" 2>/dev/null || true

# Linux
mkdir -p "$BACKUP_DIR/linux"
cp -r linux/runner/ "$BACKUP_DIR/linux/" 2>/dev/null || true
cp linux/CMakeLists.txt "$BACKUP_DIR/linux/" 2>/dev/null || true

# Windows
mkdir -p "$BACKUP_DIR/windows"
cp -r windows/runner/ "$BACKUP_DIR/windows/" 2>/dev/null || true
cp windows/CMakeLists.txt "$BACKUP_DIR/windows/" 2>/dev/null || true

# Create a restore instructions file
cat > "$BACKUP_DIR/RESTORE_INSTRUCTIONS.md" << 'EOF'
# Jachtproef Alert App - Restore Instructions

This backup contains a clean copy of the Flutter project without build artifacts or dependencies.

## To restore this project:

1. **Prerequisites:**
   - Install Flutter SDK (latest stable version)
   - Install Dart SDK
   - Install Android Studio / Xcode (for mobile development)
   - Install VS Code or your preferred IDE

2. **Restore steps:**
   ```bash
   # Navigate to the backup directory
   cd jachtproef_alert_backup_[timestamp]
   
   # Get Flutter dependencies
   flutter pub get
   
   # For iOS (if developing for iOS):
   cd ios
   pod install
   cd ..
   
   # For macOS (if developing for macOS):
   cd macos
   pod install
   cd ..
   
   # Clean and rebuild (optional)
   flutter clean
   flutter pub get
   ```

3. **Environment setup:**
   - Ensure your `.env` file contains the correct Firebase configuration
   - Set up Firebase project if needed
   - Configure signing certificates for iOS/Android if publishing

4. **Test the restoration:**
   ```bash
   flutter doctor
   flutter run
   ```

## What's included in this backup:
- Source code (lib/, test/)
- Assets and images
- Platform-specific configurations
- Project configuration files
- Documentation

## What's NOT included (will be regenerated):
- Build artifacts (build/, .dart_tool/)
- Dependencies (node_modules, Pods/, .packages)
- IDE-specific files (.idea/, .vscode/)
- Generated files

## Backup created on: $(date)
EOF

# Create a compressed archive
echo "Creating compressed archive..."
cd ..
tar -czf "${BACKUP_NAME}.tar.gz" "$BACKUP_NAME"

# Calculate sizes
BACKUP_SIZE=$(du -sh "$BACKUP_NAME" | cut -f1)
ARCHIVE_SIZE=$(du -sh "${BACKUP_NAME}.tar.gz" | cut -f1)

echo ""
echo "✅ Backup completed successfully!"
echo "📁 Backup folder: $BACKUP_NAME ($BACKUP_SIZE)"
echo "📦 Compressed archive: ${BACKUP_NAME}.tar.gz ($ARCHIVE_SIZE)"
echo ""
echo "The backup is ready to be copied to an external disk."
echo "Both the folder and compressed archive are available."
echo ""
echo "To copy to external disk:"
echo "1. Connect your external disk"
echo "2. Copy either the folder or the .tar.gz file"
echo "3. The compressed .tar.gz file is recommended for easier transfer" 