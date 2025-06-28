#!/bin/bash

# Debug Logging Setup Script for JachtProef Alert
# This script sets up all the enhanced debugging tools

echo "🔧 JachtProef Alert Debug Logging Setup"
echo "======================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${GREEN}✅ Setting up enhanced debug logging system...${NC}"
echo ""

# Check if scripts are executable
echo -e "${BLUE}🔍 Checking script permissions...${NC}"
chmod +x view_ios_logs.sh
chmod +x enhanced_log_viewer.sh
echo -e "${GREEN}✅ Scripts are executable${NC}"
echo ""

# Check if iPhone is connected
echo -e "${BLUE}🔍 Checking iPhone connection...${NC}"
DEVICE_INFO=$(xcrun devicectl list devices | grep -i "iphone\|ipad")

if [ -z "$DEVICE_INFO" ]; then
    echo -e "${YELLOW}⚠️ No iPhone detected${NC}"
    echo "   Please connect your iPhone and run this script again"
    echo ""
else
    echo -e "${GREEN}✅ iPhone detected${NC}"
    DEVICE_ID=$(echo "$DEVICE_INFO" | head -1 | awk '{print $3}')
    echo "   Device ID: $DEVICE_ID"
    
    # Check Developer Mode status
    DEV_MODE_STATUS=$(xcrun devicectl device info details --device "$DEVICE_ID" 2>/dev/null | grep "developerModeStatus" | awk '{print $2}')
    
    if [ "$DEV_MODE_STATUS" = "enabled" ]; then
        echo -e "${GREEN}✅ Developer Mode is enabled${NC}"
    else
        echo -e "${YELLOW}⚠️ Developer Mode is disabled${NC}"
        echo "   Enable Developer Mode on your iPhone for enhanced debugging"
    fi
fi

echo ""
echo -e "${PURPLE}🎯 Quick Start Guide:${NC}"
echo "========================"
echo ""
echo -e "${CYAN}1. Enable Debug Logging in the App:${NC}"
echo "   • Open JachtProef Alert on your iPhone"
echo "   • Go to Settings → Debug Instellingen"
echo "   • Toggle 'Enable Debug Logging' to ON"
echo "   • Optionally enable 'Verbose Logging'"
echo ""
echo -e "${CYAN}2. View Logs on MacBook:${NC}"
echo "   • Run: ${GREEN}./enhanced_log_viewer.sh${NC}"
echo "   • Choose option 1 for real-time filtered logs"
echo "   • Or choose specific monitoring modes"
echo ""
echo -e "${CYAN}3. Available Logging Tools:${NC}"
echo "   • ${GREEN}enhanced_log_viewer.sh${NC} - Advanced filtering and monitoring"
echo "   • ${GREEN}view_ios_logs.sh${NC} - Basic log viewing"
echo "   • ${GREEN}Xcode Console${NC} - Manual log viewing"
echo "   • ${GREEN}Console.app${NC} - System-wide logs"
echo ""
echo -e "${CYAN}4. Enhanced Features:${NC}"
echo "   • 📱 Real-time filtered logs"
echo "   • 💳 Payment-specific monitoring"
echo "   • 🔔 Notification monitoring"
echo "   • 📊 Performance monitoring"
echo "   • 📁 Export logs with filtering"
echo "   • 🔍 Advanced search and filter"
echo ""
echo -e "${CYAN}5. What You'll See:${NC}"
echo "   • App startup and initialization"
echo "   • Payment processing flow"
echo "   • User interactions and navigation"
echo "   • Network requests and responses"
echo "   • Performance metrics"
echo "   • Error tracking and debugging"
echo ""
echo -e "${PURPLE}🚀 Ready to start debugging!${NC}"
echo ""
echo -e "${YELLOW}💡 Pro Tips:${NC}"
echo "• Use the 'Generate Test Logs' button in the app to verify logging"
echo "• Focus on specific log tags like [PAYMENT] or [ERROR]"
echo "• Export logs when reporting bugs to developers"
echo "• Enable verbose logging for detailed debugging"
echo ""
echo -e "${GREEN}🎉 Setup complete! Happy debugging! 🐛✨${NC}" 