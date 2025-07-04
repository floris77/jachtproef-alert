#!/bin/bash

# Quick TestFlight Mac Monitor for Account & Payment
echo "💻 Quick TestFlight Mac Monitor - Account & Payment"
echo "==================================================="
echo ""

echo "🔍 Starting real-time monitoring for account creation and payment process..."
echo "📱 Make sure debug logging is enabled in the app first!"
echo "💳 Try to create an account and make a payment"
echo ""

echo "Press Ctrl+C to stop monitoring"
echo ""

# Monitor for account and payment related logs
log stream --predicate 'process == "JachtProef Alert"' --style compact | grep -E "(PAYMENT|Payment|TestFlight|buyNonConsumable|account|auth|login|signup|AUTH|USER|FIREBASE)" --line-buffered 