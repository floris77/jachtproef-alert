#!/bin/bash

# Simple filter for JachtProef Alert app logs
echo "🔍 Filtering JachtProef Alert logs..."
echo "====================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}Looking for JachtProef Alert specific logs...${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
echo ""

# Filter for our specific log patterns
log stream --predicate 'process == "Runner"' --info --debug --style compact | grep -E "(🚀|🧹|🔥|💳|🔔|📱|👤|⏱️|📊|🔍|❌|✅|⚠️|🎉|STARTUP|FIREBASE|PAYMENT|NOTIFICATION|USER|NAVIGATION|PERFORMANCE|JachtProef|DebugLoggingService)" | while read line; do
    # Color code different log types
    if echo "$line" | grep -q "❌\|ERROR\|FATAL"; then
        echo -e "${RED}$line${NC}"
    elif echo "$line" | grep -q "⚠️\|WARN"; then
        echo -e "${YELLOW}$line${NC}"
    elif echo "$line" | grep -q "✅\|SUCCESS"; then
        echo -e "${GREEN}$line${NC}"
    elif echo "$line" | grep -q "💳\|PAYMENT"; then
        echo -e "${PURPLE}$line${NC}"
    elif echo "$line" | grep -q "🔔\|NOTIFICATION"; then
        echo -e "${BLUE}$line${NC}"
    elif echo "$line" | grep -q "📊\|PERFORMANCE\|⏱️"; then
        echo -e "${CYAN}$line${NC}"
    else
        echo "$line"
    fi
done 