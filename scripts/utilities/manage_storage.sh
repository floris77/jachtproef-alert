#!/bin/bash

# Development Storage Management Script
# Manages storage between MacBook, 1TB NRDB disk, and Time Capsule

NRDB_DISK="/Volumes/1TB NRDB"
TIME_CAPSULE="/Volumes/Data"

echo "🗄️  Development Storage Manager"
echo "================================"

# Check disk availability
check_disks() {
    echo "📊 Checking available storage:"
    
    if [ -d "$NRDB_DISK" ]; then
        echo "✅ 1TB NRDB Disk: $(df -h "$NRDB_DISK" | tail -1 | awk '{print $4}') available"
    else
        echo "❌ 1TB NRDB Disk: Not connected"
    fi
    
    if [ -d "$TIME_CAPSULE" ]; then
        echo "✅ Time Capsule: $(df -h "$TIME_CAPSULE" | tail -1 | awk '{print $4}') available"
    else
        echo "❌ Time Capsule: Not connected"
    fi
    
    echo "💻 MacBook: $(df -h /System/Volumes/Data | tail -1 | awk '{print $4}') available"
    echo ""
}

# Show current storage setup
show_setup() {
    echo "📁 Current Storage Setup:"
    
    # Check Xcode DerivedData
    if [ -L ~/Library/Developer/Xcode/DerivedData ]; then
        echo "✅ Xcode DerivedData → $(readlink ~/Library/Developer/Xcode/DerivedData)"
    else
        echo "❌ Xcode DerivedData: Still on MacBook"
    fi
    
    # Check Flutter pub cache
    if [ -L ~/.pub-cache ]; then
        echo "✅ Flutter pub cache → $(readlink ~/.pub-cache)"
    else
        echo "❌ Flutter pub cache: Still on MacBook"
    fi
    
    echo ""
}

# Archive old projects to Time Capsule
archive_projects() {
    echo "📦 Project Archiving:"
    echo "Move old/completed projects to Time Capsule for backup storage"
    echo ""
    echo "Available for archiving:"
    
    # List potential projects to archive (older than 3 months)
    find ~/Documents ~/Desktop -name "*.xcodeproj" -o -name "pubspec.yaml" -type f 2>/dev/null | \
    while read file; do
        dir=$(dirname "$file")
        if [ $(find "$dir" -type f -newer "$file" -mtime -90 | wc -l) -eq 0 ]; then
            echo "  📁 $dir (last modified: $(stat -f %Sm "$file"))"
        fi
    done
    
    echo ""
    echo "To archive a project:"
    echo "  mv /path/to/project \"$TIME_CAPSULE/Development/Projects/Archive/\""
}

# Move Flutter pub cache
move_pub_cache() {
    if [ ! -d "$NRDB_DISK" ]; then
        echo "❌ 1TB NRDB disk not available"
        return 1
    fi
    
    if [ -L ~/.pub-cache ]; then
        echo "✅ Flutter pub cache already moved"
        return 0
    fi
    
    echo "📦 Moving Flutter pub cache to 1TB NRDB disk..."
    
    # Create target directory
    mkdir -p "$NRDB_DISK/Developer/Flutter"
    
    # Move pub cache
    if [ -d ~/.pub-cache ]; then
        mv ~/.pub-cache "$NRDB_DISK/Developer/Flutter/"
        ln -s "$NRDB_DISK/Developer/Flutter/.pub-cache" ~/.pub-cache
        echo "✅ Flutter pub cache moved and linked"
    else
        echo "❌ No pub cache found to move"
    fi
}

# Main menu
case "$1" in
    "status")
        check_disks
        show_setup
        ;;
    "archive")
        archive_projects
        ;;
    "move-pub-cache")
        move_pub_cache
        ;;
    *)
        check_disks
        show_setup
        echo "🛠️  Available commands:"
        echo "  ./manage_storage.sh status      - Show storage status"
        echo "  ./manage_storage.sh archive     - Show projects ready for archiving"
        echo "  ./manage_storage.sh move-pub-cache - Move Flutter pub cache to 1TB disk"
        echo ""
        echo "💡 Storage Strategy:"
        echo "  • 1TB NRDB Disk: Active development (DerivedData, pub cache)"
        echo "  • Time Capsule: Project archives, assets, long-term backup"
        echo "  • MacBook: Current active projects only"
        ;;
esac 