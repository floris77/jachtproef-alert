#!/bin/bash

# iOS Log Viewer Script for JachtProef Alert TestFlight Testing
# This script helps you view real-time logs from your iPhone when connected to MacBook

echo "📱 JachtProef Alert iOS Log Viewer"
echo "=================================="
echo ""

# Check if iPhone is connected
echo "🔍 Checking for connected iOS devices..."
xcrun devicectl list devices | grep -i "iphone\|ipad" || {
    echo "❌ No iPhone/iPad found. Please:"
    echo "   1. Connect your iPhone to your MacBook"
    echo "   2. Trust the computer on your iPhone"
    echo "   3. Run this script again"
    exit 1
}

echo "✅ iOS device detected!"
echo ""

# Show available options
echo "Choose how to view logs:"
echo "1. Xcode Console (recommended for TestFlight)"
echo "2. Console.app (system-wide logs)"
echo "3. Real-time device logs (advanced)"
echo "4. Export logs to file"
echo ""

read -p "Enter your choice (1-4): " choice

case $choice in
    1)
        echo "🚀 Opening Xcode Console..."
        echo "📋 Instructions:"
        echo "   1. In Xcode, go to Window → Devices and Simulators"
        echo "   2. Select your iPhone"
        echo "   3. Click 'View Device Logs'"
        echo "   4. Filter by 'JachtProef' to see app logs"
        echo "   5. Enable debug logging in the app settings"
        echo ""
        echo "💡 Tip: Use Cmd+F to search for specific log messages"
        open -a Xcode
        ;;
    2)
        echo "🚀 Opening Console.app..."
        echo "📋 Instructions:"
        echo "   1. In Console.app, select your iPhone from the left sidebar"
        echo "   2. In the search bar, type: process:JachtProef"
        echo "   3. Or search for: subsystem:com.fhkjin1.JachtProef-Alert"
        echo "   4. Enable debug logging in the app settings"
        echo ""
        echo "💡 Tip: Use the search filters to narrow down logs"
        open -a Console
        ;;
    3)
        echo "🚀 Starting real-time log stream..."
        echo "📋 This will show live logs from your device"
        echo "   Press Ctrl+C to stop"
        echo ""
        echo "🔍 Filtering for JachtProef Alert logs..."
        echo "=========================================="
        
        # Get device ID
        DEVICE_ID=$(xcrun devicectl list devices | grep -i "iphone\|ipad" | head -1 | awk '{print $1}')
        
        if [ -z "$DEVICE_ID" ]; then
            echo "❌ Could not get device ID"
            exit 1
        fi
        
        # Stream logs with filtering
        xcrun devicectl device process list --device $DEVICE_ID | grep -i "jachtproef\|com.fhkjin1" || {
            echo "📱 No JachtProef processes found. Starting general log stream..."
            echo "💡 Enable debug logging in the app to see detailed logs"
            echo ""
            xcrun devicectl device log stream --device $DEVICE_ID | grep -i "jachtproef\|com.fhkjin1\|debug\|error\|warning" || {
                echo "📱 No filtered logs found. Showing all device logs..."
                xcrun devicectl device log stream --device $DEVICE_ID
            }
        }
        ;;
    4)
        echo "📁 Exporting logs to file..."
        TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
        LOG_FILE="jachtproef_logs_$TIMESTAMP.txt"
        
        echo "📋 Exporting to: $LOG_FILE"
        echo "📱 This may take a few moments..."
        
        # Get device ID
        DEVICE_ID=$(xcrun devicectl list devices | grep -i "iphone\|ipad" | head -1 | awk '{print $1}')
        
        if [ -z "$DEVICE_ID" ]; then
            echo "❌ Could not get device ID"
            exit 1
        fi
        
        # Export logs
        xcrun devicectl device log show --device $DEVICE_ID > "$LOG_FILE" 2>/dev/null
        
        if [ -s "$LOG_FILE" ]; then
            echo "✅ Logs exported to: $LOG_FILE"
            echo "📊 File size: $(du -h "$LOG_FILE" | cut -f1)"
            echo "📋 You can open this file in any text editor"
        else
            echo "❌ No logs found or export failed"
            rm -f "$LOG_FILE"
        fi
        ;;
    *)
        echo "❌ Invalid choice. Please run the script again."
        exit 1
        ;;
esac

echo ""
echo "🎯 Debug Logging Tips:"
echo "======================"
echo "• Enable 'Debug Logging' in the app settings"
echo "• Enable 'Verbose Logging' for extra details"
echo "• Use the 'Generate Test Logs' button to test"
echo "• Look for logs with [JachtProef] tag"
echo "• Error logs are marked with [ERROR]"
echo "• Payment logs are marked with [PAYMENT]"
echo "• Network logs are marked with [NETWORK]"
echo ""
echo "🔧 Common Log Tags:"
echo "• [STARTUP] - App initialization"
echo "• [FIREBASE] - Firebase operations"
echo "• [PAYMENT] - Payment processing"
echo "• [NOTIFICATION] - Push notifications"
echo "• [USER] - User interactions"
echo "• [NAVIGATION] - Screen navigation"
echo "• [TESTFLIGHT] - TestFlight specific"
echo ""
echo "📞 Need help? Check the debug settings in the app!" 