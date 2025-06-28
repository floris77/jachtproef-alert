#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}🔍 JachtProef Alert Log Monitor${NC}"
echo "=================================="
echo ""

# Check if device is connected
if ! xcrun devicectl list devices | grep -q "iPhone"; then
    echo -e "${RED}❌ No iPhone detected. Please connect your iPhone via USB.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ iPhone detected${NC}"
echo ""

echo -e "${YELLOW}📱 Available monitoring modes:${NC}"
echo "1. 🔍 All app logs (Runner process)"
echo "2. 💳 Payment-related logs only"
echo "3. 🔗 Deep link logs only"
echo "4. ❌ Error logs only"
echo "5. 🚀 App startup logs only"
echo "6. 📊 Firebase logs only"
echo ""

read -p "Choose monitoring mode (1-6): " choice

case $choice in
    1)
        echo -e "${GREEN}🔍 Monitoring all Runner process logs...${NC}"
        echo "Press Ctrl+C to stop"
        echo ""
        xcrun simctl spawn booted log stream --predicate 'process == "Runner"' --style compact
        ;;
    2)
        echo -e "${GREEN}💳 Monitoring payment-related logs...${NC}"
        echo "Press Ctrl+C to stop"
        echo ""
        xcrun simctl spawn booted log stream --predicate 'process == "Runner" AND (message CONTAINS "PAYMENT" OR message CONTAINS "payment" OR message CONTAINS "💳" OR message CONTAINS "purchase")' --style compact
        ;;
    3)
        echo -e "${GREEN}🔗 Monitoring deep link logs...${NC}"
        echo "Press Ctrl+C to stop"
        echo ""
        xcrun simctl spawn booted log stream --predicate 'process == "Runner" AND (message CONTAINS "deep" OR message CONTAINS "link" OR message CONTAINS "🔗")' --style compact
        ;;
    4)
        echo -e "${GREEN}❌ Monitoring error logs...${NC}"
        echo "Press Ctrl+C to stop"
        echo ""
        xcrun simctl spawn booted log stream --predicate 'process == "Runner" AND (messageType == 16 OR message CONTAINS "❌" OR message CONTAINS "Error")' --style compact
        ;;
    5)
        echo -e "${GREEN}🚀 Monitoring app startup logs...${NC}"
        echo "Press Ctrl+C to stop"
        echo ""
        xcrun simctl spawn booted log stream --predicate 'process == "Runner" AND (message CONTAINS "🚀" OR message CONTAINS "startup" OR message CONTAINS "initializing")' --style compact
        ;;
    6)
        echo -e "${GREEN}📊 Monitoring Firebase logs...${NC}"
        echo "Press Ctrl+C to stop"
        echo ""
        xcrun simctl spawn booted log stream --predicate 'process == "Runner" AND (message CONTAINS "Firebase" OR message CONTAINS "🔥" OR message CONTAINS "cloud_firestore")' --style compact
        ;;
    *)
        echo -e "${RED}❌ Invalid choice. Please run the script again.${NC}"
        exit 1
        ;;
esac 