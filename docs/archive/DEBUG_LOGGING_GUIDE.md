# 🐛 Debug Logging Guide for TestFlight Testing

This guide will help you view real-time logs from your iPhone when connected to your MacBook during TestFlight testing.

## 🚀 Quick Start

### 1. Enable Debug Logging in the App
1. Open the JachtProef Alert app on your iPhone
2. Go to **Settings** → **Debug Instellingen**
3. Toggle **Enable Debug Logging** to ON
4. Optionally enable **Verbose Logging** for extra details
5. Tap **Generate Test Logs** to verify logging is working

### 2. View Logs on MacBook
1. Connect your iPhone to your MacBook with a USB cable
2. Trust the computer on your iPhone if prompted
3. Run the log viewer script:
   ```bash
   ./view_ios_logs.sh
   ```
4. Choose option 1 (Xcode Console) for the best experience

## 📱 How to View Logs

### Option 1: Xcode Console (Recommended)
1. Open Xcode
2. Go to **Window** → **Devices and Simulators**
3. Select your iPhone from the list
4. Click **View Device Logs**
5. Filter by "JachtProef" to see app-specific logs
6. Use Cmd+F to search for specific messages

### Option 2: Console.app
1. Open Console.app (Applications → Utilities → Console)
2. Select your iPhone from the left sidebar
3. In the search bar, type: `process:JachtProef`
4. Or search for: `subsystem:com.fhkjin1.JachtProef-Alert`

### Option 3: Real-time Stream
Use the script option 3 for live log streaming:
```bash
./view_ios_logs.sh
# Choose option 3
```

### Option 4: Export to File
Use the script option 4 to save logs to a file:
```bash
./view_ios_logs.sh
# Choose option 4
```

## 🔍 Understanding Log Messages

### Log Format
```
[2024-01-15T10:30:45.123Z] [INFO] [JachtProef] 🚀 App starting up...
```

### Log Levels
- **INFO** (🔵): General information
- **DEBUG** (🔍): Detailed debugging info
- **WARN** (🟡): Warnings
- **ERROR** (🔴): Errors
- **FATAL** (💀): Critical errors

### Common Tags
- **[STARTUP]**: App initialization
- **[FIREBASE]**: Firebase operations
- **[PAYMENT]**: Payment processing
- **[NOTIFICATION]**: Push notifications
- **[USER]**: User interactions
- **[NAVIGATION]**: Screen navigation
- **[NETWORK]**: Network requests
- **[TESTFLIGHT]**: TestFlight specific

## 💳 Payment Debugging

When testing payments, look for these log patterns:

### Successful Payment Flow
```
[INFO] [PAYMENT] 💳 Payment Service: Starting initialization
[INFO] [PAYMENT] 💳 Payment Service: IAP available: true
[INFO] [PAYMENT] 💳 Starting purchase attempt
[INFO] [PAYMENT] 💳 Product found
[INFO] [PAYMENT] 💳 Purchase initiated
```

### Payment Issues
```
[ERROR] [PAYMENT] 💳 Product not found: jachtproef_monthly_399
[WARN] [PAYMENT] 💳 Payment Service: In-app purchases not available
[ERROR] [PAYMENT] 💳 Purchase initiation failed: PlatformException
```

## 🔔 Notification Debugging

For notification issues, look for:
```
[INFO] [NOTIFICATION] 🔔 Notification Service: Starting initialization
[INFO] [NOTIFICATION] 🔔 Notification: Permission granted
[ERROR] [NOTIFICATION] 🔔 Notification: Permission denied
```

## 🧪 Testing Specific Features

### Test Payment Flow
1. Enable debug logging
2. Go to payment screen
3. Attempt to purchase
4. Check logs for payment flow
5. Look for any errors or warnings

### Test Notifications
1. Enable debug logging
2. Go to settings → notifications
3. Toggle notification settings
4. Check logs for permission status
5. Test notification delivery

### Test App Navigation
1. Enable debug logging
2. Navigate through different screens
3. Check logs for navigation events
4. Look for any errors during navigation

## 🛠️ Troubleshooting

### No Logs Appearing
1. **Check Debug Logging is Enabled**: Go to Settings → Debug Instellingen
2. **Check Device Connection**: Ensure iPhone is connected and trusted
3. **Check Xcode/Console**: Make sure you're looking at the right device
4. **Restart App**: Close and reopen the app after enabling logging

### Logs Too Noisy
1. Disable **Verbose Logging** in debug settings
2. Use search filters in Xcode Console
3. Focus on specific tags like [PAYMENT] or [ERROR]

### Can't Find Specific Logs
1. Use search in Xcode Console (Cmd+F)
2. Filter by specific tags
3. Check the time range
4. Export logs and search in a text editor

## 📊 Log Analysis Tips

### Performance Issues
Look for:
- Long initialization times
- Network request delays
- Memory warnings
- Battery drain indicators

### Payment Issues
Look for:
- Product loading failures
- Purchase initiation errors
- Platform-specific issues
- Chromebook detection

### User Experience Issues
Look for:
- Navigation errors
- Screen loading problems
- Data loading failures
- Permission issues

## 🔧 Advanced Debugging

### Custom Log Messages
You can add custom debug messages in your code:
```dart
DebugLoggingService().info('Custom message', tag: 'CUSTOM');
DebugLoggingService().error('Error message', tag: 'CUSTOM');
```

### Exporting Logs
1. Use the script option 4 to export logs
2. Share logs with developers for analysis
3. Include logs when reporting bugs

### Filtering Logs
In Xcode Console, you can filter by:
- Process name: `process:JachtProef`
- Subsystem: `subsystem:com.fhkjin1.JachtProef-Alert`
- Log level: `level:error`
- Custom tags: `message:PAYMENT`

## 📞 Getting Help

If you encounter issues:
1. Check this guide first
2. Enable verbose logging for more details
3. Export logs and share with support
4. Include specific error messages and steps to reproduce

## 🎯 Best Practices

1. **Enable logging before testing**: Turn on debug logging before starting your test session
2. **Use specific test scenarios**: Test one feature at a time for clearer logs
3. **Document issues**: Note down timestamps and specific error messages
4. **Export logs regularly**: Save logs for later analysis
5. **Clean up**: Clear logs periodically to avoid overwhelming output

---

**Happy Debugging! 🐛✨** 