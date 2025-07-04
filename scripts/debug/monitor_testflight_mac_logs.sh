#!/bin/bash

# TestFlight Mac Log Monitor for JachtProef Alert
# This script monitors logs when running TestFlight directly on macOS

echo "💻 TestFlight Mac Log Monitor for JachtProef Alert"
echo "=================================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}🔍 Monitoring TestFlight logs on macOS...${NC}"
echo "📱 Make sure debug logging is enabled in the app"
echo "💳 Try to make a payment and watch the logs below"
echo ""

# Show available options
echo -e "${BLUE}Choose your monitoring method:${NC}"
echo ""
echo "1. 📋 Console.app (recommended for TestFlight on Mac)"
echo "2. 🔍 Real-time log stream"
echo "3. 💳 Payment-specific monitoring"
echo "4. 📁 Export logs to file"
echo "5. 🛠️ Xcode Console (if available)"
echo ""

read -p "Enter your choice (1-5): " choice

case $choice in
    1)
        echo -e "${GREEN}🚀 Opening Console.app for TestFlight on Mac...${NC}"
        echo "📋 Instructions:"
        echo "   1. In Console.app, look for 'JachtProef Alert' in the left sidebar"
        echo "   2. Or search for: process:JachtProef"
        echo "   3. Or search for: subsystem:com.fhkjin1.JachtProef-Alert"
        echo "   4. Enable debug logging in the app settings"
        echo ""
        echo "💡 Tip: Use the search bar to filter for payment-related logs"
        open -a Console
        ;;
    2)
        echo -e "${GREEN}🔍 Starting real-time log monitoring...${NC}"
        echo "Press Ctrl+C to stop monitoring"
        echo ""
        
        # Monitor system logs for the app
        log stream --predicate 'process == "JachtProef Alert" OR process == "Runner" OR subsystem == "com.fhkjin1.JachtProef-Alert"' --style compact
        ;;
    3)
        echo -e "${GREEN}💳 Starting payment-specific monitoring...${NC}"
        echo "Press Ctrl+C to stop monitoring"
        echo ""
        
        # Monitor payment-related logs
        log stream --predicate 'process == "JachtProef Alert" OR process == "Runner" OR subsystem == "com.fhkjin1.JachtProef-Alert"' --style compact | grep -E "(PAYMENT|Payment|TestFlight|buyNonConsumable|storekit|jachtproef)" --line-buffered
        ;;
    4)
        echo -e "${GREEN}📁 Exporting logs to file...${NC}"
        TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
        LOG_FILE="testflight_mac_logs_$TIMESTAMP.txt"
        
        echo "📋 Exporting to: $LOG_FILE"
        echo "📱 This may take a few moments..."
        
        # Export logs for the app
        log show --predicate 'process == "JachtProef Alert" OR process == "Runner" OR subsystem == "com.fhkjin1.JachtProef-Alert"' --last 1h > "$LOG_FILE" 2>/dev/null
        
        if [ -s "$LOG_FILE" ]; then
            echo -e "${GREEN}✅ Logs exported to: $LOG_FILE${NC}"
            echo "📊 File size: $(du -h "$LOG_FILE" | cut -f1)"
            echo "📋 You can open this file in any text editor"
        else
            echo -e "${RED}❌ No logs found or export failed${NC}"
            rm -f "$LOG_FILE"
        fi
        ;;
    5)
        echo -e "${GREEN}🚀 Opening Xcode Console...${NC}"
        echo "📋 Instructions:"
        echo "   1. In Xcode, go to Window → Devices and Simulators"
        echo "   2. Look for your Mac in the list"
        echo "   3. Click 'View Device Logs'"
        echo "   4. Filter by 'JachtProef' to see app logs"
        echo ""
        echo "💡 Note: This may not work for TestFlight on Mac"
        open -a Xcode
        ;;
    *)
        echo -e "${RED}❌ Invalid choice. Please run the script again.${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${YELLOW}🎯 Debug Logging Tips for TestFlight on Mac:${NC}"
echo "=================================================="
echo "• Enable 'Debug Logging' in the app settings"
echo "• Enable 'Verbose Logging' for extra details"
echo "• Use the 'Generate Test Logs' button to test"
echo "• Look for logs with [JachtProef] tag"
echo "• Error logs are marked with [ERROR]"
echo "• Payment logs are marked with [PAYMENT]"
echo "• TestFlight logs are marked with [TESTFLIGHT]"
echo ""
echo -e "${CYAN}🔧 Common Log Tags:${NC}"
echo "• [STARTUP] - App initialization"
echo "• [FIREBASE] - Firebase operations"
echo "• [PAYMENT] - Payment processing"
echo "• [NOTIFICATION] - Push notifications"
echo "• [USER] - User interactions"
echo "• [NAVIGATION] - Screen navigation"
echo "• [TESTFLIGHT] - TestFlight specific"
echo ""
echo -e "${PURPLE}💳 For Payment Dialog Issues:${NC}"
echo "Look for these specific messages:"
echo "• '🔍 Payment Dialog: Starting for product'"
echo "• '🔍 Payment Dialog: Found product'"
echo "• '🔍 Payment Dialog: Calling InAppPurchase.instance.buyNonConsumable'"
echo "• '✅ TestFlight on Mac: Payment dialog initiated successfully'"
echo "• '❌ TestFlight on Mac: Failed to initiate payment dialog'"
echo ""
echo -e "${GREEN}📞 Need help? Check the debug settings in the app!${NC}" 