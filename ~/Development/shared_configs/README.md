# 🚀 Flutter Multi-App Development Environment

This setup prevents build conflicts and keeps your Flutter projects organized and isolated.

## 📁 Directory Structure
```
~/Development/
├── flutter_projects/          # Your actual Flutter projects
│   ├── project1/
│   ├── project2/
│   └── jachtproef_alert/
├── build_outputs/             # Isolated build artifacts
└── shared_configs/            # Shared configuration files
```

## 🛠️ Setup Instructions

### 1. Load Environment
Add this line to your `~/.zshrc`:
```bash
source ~/Development/shared_configs/flutter_env_setup.sh
```

### 2. Create a New Project Environment
```bash
setup_flutter_project jachtproef_alert com.yourcompany.jachtproef
```

### 3. Switch Between Projects
```bash
switch_flutter_project jachtproef_alert
```

## 🧹 Preventing Build Conflicts

### Common Issues You Were Having:
- ✅ **Build artifacts mixing**: Each project now has isolated build outputs
- ✅ **Bundle ID conflicts**: Project-specific environment variables
- ✅ **Cache interference**: Individual clean scripts per project
- ✅ **iOS provisioning**: Separate team IDs and certificates per project

### Clean Build Process:
```bash
# In any project directory:
./build_clean.sh

# Then:
flutter pub get
flutter build ios/android
```

## 📱 iOS Multi-App Best Practices

### Xcode Configuration:
1. **Separate Schemes**: Create unique schemes for each app
2. **Different Bundle IDs**: Use project-specific identifiers
3. **Team Management**: Set correct development teams per project

### Provisioning Profiles:
```bash
# Set in each project's .env file:
IOS_DEVELOPMENT_TEAM=YOUR_TEAM_ID_1
IOS_BUNDLE_ID=com.company.app1

# For different apps:
IOS_DEVELOPMENT_TEAM=YOUR_TEAM_ID_2  
IOS_BUNDLE_ID=com.company.app2
```

## 🤖 Android Multi-App Setup

### Gradle Isolation:
- Each project uses isolated `.gradle` folders
- Separate package names prevent conflicts
- Individual signing configurations

### Key Files to Check:
- `android/app/build.gradle` - Package name
- `android/app/src/main/AndroidManifest.xml` - Application ID
- `android/gradle.properties` - Build settings

## 🎯 Cursor IDE Optimization

### Recommended Settings:
Copy the settings from `cursor_flutter_settings.json` to:
- **Global**: Cursor > Preferences > Settings (JSON)
- **Per Project**: `.vscode/settings.json` in each project

### Key Performance Settings:
- Excludes build folders from indexing
- Optimizes Dart analysis server
- Prevents file watcher overload

## 🔧 Troubleshooting

### Build Conflicts:
```bash
# Complete clean:
./build_clean.sh
flutter clean
flutter pub get

# iOS specific:
cd ios && pod install --clean-install

# Android specific:
cd android && ./gradlew clean
```

### Xcode Issues:
1. Product > Clean Build Folder
2. Delete derived data for specific project
3. Check provisioning profiles in Xcode settings

### Common Commands:
```bash
# List all projects:
switch_flutter_project

# Check Flutter doctor:
flutter doctor -v

# Rebuild everything:
flutter clean && flutter pub get && flutter build runner build
```

## 🚀 Workflow Example

```bash
# Morning routine:
switch_flutter_project jachtproef_alert
flutter clean && flutter pub get

# Work on features...

# Before switching projects:
./build_clean.sh

# Switch to different project:
switch_flutter_project other_app
flutter pub get
```

This setup ensures **zero cross-contamination** between your Flutter projects! 