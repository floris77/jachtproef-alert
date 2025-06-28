#!/bin/bash

# Enhanced iOS Log Viewer for JachtProef Alert TestFlight Testing
# Advanced filtering and real-time monitoring capabilities

echo "🔍 Enhanced JachtProef Alert Log Viewer"
echo "======================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Check if iPhone is connected
echo -e "${BLUE}🔍 Checking for connected iOS devices...${NC}"
DEVICE_INFO=$(xcrun devicectl list devices | grep -i "iphone\|ipad")

if [ -z "$DEVICE_INFO" ]; then
    echo -e "${RED}❌ No iPhone/iPad found. Please:${NC}"
    echo "   1. Connect your iPhone to your MacBook"
    echo "   2. Trust the computer on your iPhone"
    echo "   3. Run this script again"
    exit 1
fi

echo -e "${GREEN}✅ iOS device detected!${NC}"
echo ""

# Extract device ID
DEVICE_ID=$(echo "$DEVICE_INFO" | head -1 | awk '{print $3}')

# Show enhanced options
echo -e "${CYAN}Choose your logging experience:${NC}"
echo ""
echo "1. 📱 Real-time filtered logs (recommended)"
echo "2. 🔍 Advanced search and filter"
echo "3. 📊 Performance monitoring"
echo "4. 💳 Payment-specific monitoring"
echo "5. 🔔 Notification monitoring"
echo "6. 📁 Export logs with filtering"
echo "7. 🛠️ Xcode Console (manual)"
echo "8. 📋 Console.app (manual)"
echo ""

read -p "Enter your choice (1-8): " choice

case $choice in
    1)
        echo -e "${GREEN}🚀 Starting real-time filtered logs...${NC}"
        echo -e "${YELLOW}📋 This will show live logs filtered for JachtProef Alert${NC}"
        echo -e "${YELLOW}   Press Ctrl+C to stop${NC}"
        echo ""
        echo -e "${CYAN}🔍 Filtering for:${NC}"
        echo "   • JachtProef Alert app logs"
        echo "   • Payment processing"
        echo "   • User interactions"
        echo "   • Errors and warnings"
        echo "   • Performance metrics"
        echo ""
        echo "=========================================="
        
        xcrun devicectl device log stream --device "$DEVICE_ID" | grep -E "(JachtProef|com\.fhkjin1|PAYMENT|ERROR|WARN|INFO|DEBUG|💳|🔔|📱|🔥|👤|⏱️)" || {
            echo -e "${YELLOW}📱 No filtered logs found. Showing all device logs...${NC}"
            xcrun devicectl device log stream --device "$DEVICE_ID"
        }
        ;;
    2)
        echo -e "${GREEN}🔍 Advanced search and filter mode${NC}"
        echo ""
        echo -e "${CYAN}Enter search terms (comma-separated):${NC}"
        echo "Examples: PAYMENT,ERROR,monthly,subscription"
        read -p "Search terms: " search_terms
        
        if [ -z "$search_terms" ]; then
            search_terms="JachtProef"
        fi
        
        # Convert comma-separated to grep pattern
        search_pattern=$(echo "$search_terms" | sed 's/,/|/g')
        
        echo -e "${GREEN}🔍 Filtering for: $search_pattern${NC}"
        echo -e "${YELLOW}   Press Ctrl+C to stop${NC}"
        echo ""
        
        xcrun devicectl device log stream --device "$DEVICE_ID" | grep -iE "$search_pattern" || {
            echo -e "${YELLOW}📱 No matching logs found.${NC}"
        }
        ;;
    3)
        echo -e "${GREEN}📊 Performance monitoring mode${NC}"
        echo -e "${YELLOW}   Press Ctrl+C to stop${NC}"
        echo ""
        echo -e "${CYAN}Monitoring:${NC}"
        echo "   • App startup time"
        echo "   • Screen load times"
        echo "   • Network request times"
        echo "   • Memory usage"
        echo "   • Performance traces"
        echo ""
        
        xcrun devicectl device log stream --device "$DEVICE_ID" | grep -E "(PERFORMANCE|⏱️|📊|app_startup|screen_load|data_load|memory)" || {
            echo -e "${YELLOW}📱 No performance logs found.${NC}"
        }
        ;;
    4)
        echo -e "${GREEN}💳 Payment monitoring mode${NC}"
        echo -e "${YELLOW}   Press Ctrl+C to stop${NC}"
        echo ""
        echo -e "${CYAN}Monitoring payment flow:${NC}"
        echo "   • Payment initialization"
        echo "   • Product loading"
        echo "   • Purchase attempts"
        echo "   • Payment errors"
        echo "   • Subscription status"
        echo ""
        
        xcrun devicectl device log stream --device "$DEVICE_ID" | grep -E "(PAYMENT|💳|purchase|subscription|product|billing|payment)" || {
            echo -e "${YELLOW}📱 No payment logs found.${NC}"
        }
        ;;
    5)
        echo -e "${GREEN}🔔 Notification monitoring mode${NC}"
        echo -e "${YELLOW}   Press Ctrl+C to stop${NC}"
        echo ""
        echo -e "${CYAN}Monitoring notifications:${NC}"
        echo "   • Permission requests"
        echo "   • Notification delivery"
        echo "   • Notification errors"
        echo "   • Push notification events"
        echo ""
        
        xcrun devicectl device log stream --device "$DEVICE_ID" | grep -E "(NOTIFICATION|🔔|notification|permission|push)" || {
            echo -e "${YELLOW}📱 No notification logs found.${NC}"
        }
        ;;
    6)
        echo -e "${GREEN}📁 Export logs with filtering${NC}"
        echo ""
        echo -e "${CYAN}Choose export type:${NC}"
        echo "1. All JachtProef logs"
        echo "2. Payment logs only"
        echo "3. Error logs only"
        echo "4. Performance logs only"
        echo "5. Custom filter"
        echo ""
        read -p "Export type (1-5): " export_type
        
        TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
        
        case $export_type in
            1)
                LOG_FILE="jachtproef_all_logs_$TIMESTAMP.txt"
                echo -e "${GREEN}📁 Exporting all JachtProef logs to: $LOG_FILE${NC}"
                xcrun devicectl device log show --device "$DEVICE_ID" | grep -E "(JachtProef|com\.fhkjin1)" > "$LOG_FILE"
                ;;
            2)
                LOG_FILE="jachtproef_payment_logs_$TIMESTAMP.txt"
                echo -e "${GREEN}📁 Exporting payment logs to: $LOG_FILE${NC}"
                xcrun devicectl device log show --device "$DEVICE_ID" | grep -E "(PAYMENT|💳|purchase|subscription)" > "$LOG_FILE"
                ;;
            3)
                LOG_FILE="jachtproef_error_logs_$TIMESTAMP.txt"
                echo -e "${GREEN}📁 Exporting error logs to: $LOG_FILE${NC}"
                xcrun devicectl device log show --device "$DEVICE_ID" | grep -E "(ERROR|FATAL|❌)" > "$LOG_FILE"
                ;;
            4)
                LOG_FILE="jachtproef_performance_logs_$TIMESTAMP.txt"
                echo -e "${GREEN}📁 Exporting performance logs to: $LOG_FILE${NC}"
                xcrun devicectl device log show --device "$DEVICE_ID" | grep -E "(PERFORMANCE|⏱️|📊)" > "$LOG_FILE"
                ;;
            5)
                echo -e "${CYAN}Enter custom filter pattern:${NC}"
                read -p "Filter: " custom_filter
                LOG_FILE="jachtproef_custom_logs_$TIMESTAMP.txt"
                echo -e "${GREEN}📁 Exporting custom filtered logs to: $LOG_FILE${NC}"
                xcrun devicectl device log show --device "$DEVICE_ID" | grep -E "$custom_filter" > "$LOG_FILE"
                ;;
            *)
                echo -e "${RED}❌ Invalid choice${NC}"
                exit 1
                ;;
        esac
        
        if [ -s "$LOG_FILE" ]; then
            echo -e "${GREEN}✅ Logs exported successfully!${NC}"
            echo -e "${CYAN}📊 File size: $(du -h "$LOG_FILE" | cut -f1)${NC}"
            echo -e "${CYAN}📋 Lines: $(wc -l < "$LOG_FILE")${NC}"
        else
            echo -e "${YELLOW}⚠️ No matching logs found${NC}"
            rm -f "$LOG_FILE"
        fi
        ;;
    7)
        echo -e "${GREEN}🛠️ Opening Xcode Console...${NC}"
        echo -e "${CYAN}📋 Instructions:${NC}"
        echo "   1. In Xcode, go to Window → Devices and Simulators"
        echo "   2. Select your iPhone"
        echo "   3. Click 'View Device Logs'"
        echo "   4. Filter by 'JachtProef' to see app logs"
        echo "   5. Use Cmd+F to search for specific messages"
        echo ""
        open -a Xcode
        ;;
    8)
        echo -e "${GREEN}📋 Opening Console.app...${NC}"
        echo -e "${CYAN}📋 Instructions:${NC}"
        echo "   1. In Console.app, select your iPhone from the left sidebar"
        echo "   2. In the search bar, type: process:JachtProef"
        echo "   3. Or search for: subsystem:com.fhkjin1.JachtProef-Alert"
        echo "   4. Use the search filters to narrow down logs"
        echo ""
        open -a Console
        ;;
    *)
        echo -e "${RED}❌ Invalid choice. Please run the script again.${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${PURPLE}🎯 Enhanced Debug Logging Tips:${NC}"
echo "======================================"
echo -e "• ${GREEN}Enable 'Debug Logging' in the app settings${NC}"
echo -e "• ${GREEN}Enable 'Verbose Logging' for extra details${NC}"
echo -e "• ${GREEN}Use the 'Generate Test Logs' button to test${NC}"
echo -e "• ${CYAN}Look for logs with [JachtProef] tag${NC}"
echo -e "• ${RED}Error logs are marked with [ERROR]${NC}"
echo -e "• ${YELLOW}Payment logs are marked with [PAYMENT]${NC}"
echo -e "• ${BLUE}Network logs are marked with [NETWORK]${NC}"
echo ""
echo -e "${PURPLE}🔧 Common Log Tags:${NC}"
echo -e "• ${GREEN}[STARTUP] - App initialization${NC}"
echo -e "• ${GREEN}[FIREBASE] - Firebase operations${NC}"
echo -e "• ${YELLOW}[PAYMENT] - Payment processing${NC}"
echo -e "• ${BLUE}[NOTIFICATION] - Push notifications${NC}"
echo -e "• ${CYAN}[USER] - User interactions${NC}"
echo -e "• ${PURPLE}[NAVIGATION] - Screen navigation${NC}"
echo -e "• ${GREEN}[PERFORMANCE] - Performance metrics${NC}"
echo ""
echo -e "${PURPLE}📞 Need help? Check the debug settings in the app!${NC}" 