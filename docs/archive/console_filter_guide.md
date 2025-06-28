# Console.app Filtering Guide for JachtProef Alert

Since you can see the logs in Console.app but there are too many messages, here's how to filter them effectively:

## 🔍 Step-by-Step Filtering in Console.app

### 1. Select Your Device
- In Console.app, click on your iPhone in the left sidebar (under "Devices")

### 2. Use These Search Filters (one at a time):

#### For App Startup Logs:
```
process == "Runner" AND messageType == 16
```

#### For Debug Logs (if enabled):
```
process == "Runner" AND (message CONTAINS "🚀" OR message CONTAINS "🧹" OR message CONTAINS "🔥" OR message CONTAINS "💳" OR message CONTAINS "🔔")
```

#### For Quick Setup Related:
```
process == "Runner" AND (message CONTAINS "quick_setup" OR message CONTAINS "QuickSetup" OR message CONTAINS "setup")
```

#### For Payment Related:
```
process == "Runner" AND (message CONTAINS "payment" OR message CONTAINS "PAYMENT" OR message CONTAINS "💳" OR message CONTAINS "purchase")
```

#### For Firebase Related:
```
process == "Runner" AND (message CONTAINS "Firebase" OR message CONTAINS "FIREBASE" OR message CONTAINS "🔥")
```

#### For Navigation/Screen Views:
```
process == "Runner" AND (message CONTAINS "screen" OR message CONTAINS "navigation" OR message CONTAINS "📱")
```

### 3. Alternative: Use Shorthand Filters

#### For All Runner Process Logs:
```
Runner
```

#### For Recent Activity:
```
Runner info
```

#### For Errors Only:
```
Runner error
```

### 4. Time-Based Filtering

In Console.app, you can also:
- Use the time slider at the bottom to focus on recent logs
- Click the "Now" button to jump to current time
- Use the search bar with time constraints

### 5. What to Look For

#### App Startup Sequence:
- `🚀 App starting up...`
- `🧹 Navigation flag cleared`
- `🔥 Initializing Firebase...`
- `💳 Payment Service: Starting initialization`
- `🔔 Notification Service: Starting initialization`

#### Quick Setup Flow:
- `📱 Screen view: quick_setup_screen`
- `👤 User action: quick_setup_started`
- `🔔 Notification: Permission request`

#### Payment Flow:
- `💳 Payment Service: Starting initialization`
- `💳 Starting purchase attempt`
- `💳 Product found`
- `💳 Purchase initiated`

### 6. Pro Tips

1. **Start with broad filters** and narrow down
2. **Use the time slider** to focus on recent activity
3. **Copy interesting log lines** to share with developers
4. **Look for error patterns** (lines with ❌ or ERROR)
5. **Focus on the sequence** of events

### 7. If You Still See Too Many Logs

Try this ultra-specific filter:
```
process == "Runner" AND (message CONTAINS "🚀" OR message CONTAINS "🧹" OR message CONTAINS "🔥" OR message CONTAINS "💳" OR message CONTAINS "🔔" OR message CONTAINS "📱" OR message CONTAINS "👤" OR message CONTAINS "⏱️" OR message CONTAINS "📊" OR message CONTAINS "🔍" OR message CONTAINS "❌" OR message CONTAINS "✅" OR message CONTAINS "⚠️" OR message CONTAINS "🎉")
```

This will show only logs with our specific emoji markers from the debug logging system.

---

**Remember**: The debug logging needs to be enabled in the app (Settings → Debug Instellingen) for the emoji-marked logs to appear. 