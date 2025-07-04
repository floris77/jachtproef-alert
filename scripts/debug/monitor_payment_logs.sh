#!/bin/bash

# Quick Payment Log Monitor for TestFlight Testing
echo "💳 Payment Log Monitor for JachtProef Alert"
echo "==========================================="
echo ""

# Check if iPhone is connected
DEVICE_INFO=$(xcrun devicectl list devices | grep -i "iphone\|ipad")

if [ -z "$DEVICE_INFO" ]; then
    echo "❌ No iPhone/iPad found. Please connect your device first."
    exit 1
fi

echo "✅ iOS device detected!"
echo ""

echo "🔍 Starting payment log monitoring..."
echo "📱 Make sure debug logging is enabled in the app"
echo "💳 Try to make a payment and watch the logs below"
echo ""

# Get device ID
DEVICE_ID=$(echo "$DEVICE_INFO" | head -1 | awk '{print $3}')

# Monitor logs with payment-specific filtering
echo "🔍 Monitoring payment-related logs..."
echo "Press Ctrl+C to stop monitoring"
echo ""

# Real-time log monitoring with payment focus
xcrun devicectl device log show --device $DEVICE_ID | grep -E "(JachtProef|PAYMENT|Payment|TestFlight|buyNonConsumable|storekit)" --line-buffered 