#!/bin/bash

# Flutter Multi-App Environment Setup Script
# Prevents build conflicts between different Flutter projects

setup_flutter_project() {
    local project_name=$1
    local bundle_id=$2
    
    if [ -z "$project_name" ] || [ -z "$bundle_id" ]; then
        echo "❌ Usage: setup_flutter_project <project_name> <bundle_id>"
        echo "   Example: setup_flutter_project jachtproef_alert com.yourcompany.jachtproef"
        return 1
    fi
    
    echo "🏗️  Setting up isolated Flutter environment for: $project_name"
    
    # Create project directory structure
    PROJECT_DIR="$HOME/Development/flutter_projects/$project_name"
    mkdir -p "$PROJECT_DIR"
    mkdir -p "$HOME/Development/build_outputs/$project_name"
    
    # Create project-specific build script
    cat > "$PROJECT_DIR/build_clean.sh" << EOF
#!/bin/bash
# Clean build script for $project_name

echo "🧹 Cleaning $project_name build environment..."

# Clean Flutter
flutter clean

# Clean iOS
rm -rf ios/build/
rm -rf ios/Pods/
rm -rf ios/.symlinks/
rm -rf ios/Flutter/Flutter.framework
rm -rf ios/Flutter/Flutter.podspec

# Clean Android  
rm -rf android/build/
rm -rf android/app/build/
rm -rf android/.gradle/

# Clean Dart
rm -rf .dart_tool/
rm -rf build/

echo "✅ $project_name environment cleaned!"
echo "💡 Run 'flutter pub get' to reinstall dependencies"
EOF

    chmod +x "$PROJECT_DIR/build_clean.sh"
    
    # Create project-specific environment variables
    cat > "$PROJECT_DIR/.env" << EOF
# Environment for $project_name
PROJECT_NAME=$project_name
BUNDLE_ID=$bundle_id
BUILD_OUTPUT_DIR=$HOME/Development/build_outputs/$project_name

# iOS specific
IOS_DEVELOPMENT_TEAM=YOUR_TEAM_ID
IOS_BUNDLE_ID=$bundle_id

# Android specific  
ANDROID_PACKAGE_NAME=$bundle_id
EOF

    echo "✅ Created isolated environment for $project_name"
    echo "📁 Project directory: $PROJECT_DIR"
    echo "🔨 Build outputs: $HOME/Development/build_outputs/$project_name"
    echo "🧹 Clean script: $PROJECT_DIR/build_clean.sh"
}

# Function to switch between projects cleanly
switch_flutter_project() {
    local project_name=$1
    
    if [ -z "$project_name" ]; then
        echo "📂 Available Flutter projects:"
        ls -1 "$HOME/Development/flutter_projects/" 2>/dev/null || echo "   No projects found"
        return 1
    fi
    
    PROJECT_DIR="$HOME/Development/flutter_projects/$project_name"
    
    if [ ! -d "$PROJECT_DIR" ]; then
        echo "❌ Project $project_name not found"
        return 1
    fi
    
    echo "🔄 Switching to $project_name environment..."
    
    # Source project environment
    if [ -f "$PROJECT_DIR/.env" ]; then
        source "$PROJECT_DIR/.env"
        echo "✅ Loaded environment for $project_name"
    fi
    
    # Change to project directory
    cd "$PROJECT_DIR" 2>/dev/null || cd "$HOME/Development/flutter_projects/$project_name"
    
    echo "🎯 Now in $project_name environment"
    echo "💡 Run './build_clean.sh' if you have build conflicts"
}

echo "🚀 Flutter Multi-App Environment Setup Loaded!"
echo ""
echo "📋 Available Commands:"
echo "   setup_flutter_project <name> <bundle_id>  - Create new isolated project"
echo "   switch_flutter_project <name>             - Switch to project environment"
echo ""
echo "💡 Add this to your ~/.zshrc:"
echo "   source ~/Development/shared_configs/flutter_env_setup.sh" 