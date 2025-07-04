# iOS-Style Design Guide for JachtProef Alert

This guide shows how to use iOS-style components throughout your Flutter app to create a consistent, polished iOS design language that works beautifully on both iOS and Android platforms.

## 🎯 Why Use iOS-Style Components?

- **Consistent Design**: Clean, polished look that users love
- **Better UX**: Smooth animations and native feel
- **Cross-Platform**: Works perfectly on both iOS and Android
- **Modern Look**: Matches current iOS design trends

## 📱 Core iOS-Style Components

### 1. Segmented Controls
```dart
// Replace Material tabs with iOS segmented control
CupertinoSlidingSegmentedControl<int>(
  groupValue: selectedTab,
  backgroundColor: CupertinoColors.systemGrey6,
  thumbColor: CupertinoColors.white,
  children: {
    0: Text('Alle', style: TextStyle(color: selectedTab == 0 ? kMainColor : CupertinoColors.systemGrey)),
    1: Text('Inschrijven', style: TextStyle(color: selectedTab == 1 ? kMainColor : CupertinoColors.systemGrey)),
    // ... more tabs
  },
  onValueChanged: (int? value) {
    if (value != null) setState(() => selectedTab = value);
  },
)
```

### 2. Text Fields
```dart
// Replace TextField with CupertinoTextField
CupertinoTextField(
  placeholder: 'Zoeken op naam…',
  placeholderStyle: TextStyle(color: CupertinoColors.systemGrey),
  prefix: Icon(CupertinoIcons.search, color: CupertinoColors.systemGrey),
  style: TextStyle(color: CupertinoColors.label),
  decoration: BoxDecoration(
    color: CupertinoColors.systemGrey6,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: CupertinoColors.systemGrey4),
  ),
)
```

### 3. Buttons
```dart
// Replace ElevatedButton with CupertinoButton
CupertinoButton(
  color: kMainColor,
  borderRadius: BorderRadius.circular(12),
  onPressed: () => _handleAction(),
  child: Text(
    'Action',
    style: TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w600,
    ),
  ),
)

// For secondary actions
CupertinoButton(
  onPressed: () => _handleAction(),
  child: Text(
    'Cancel',
    style: TextStyle(color: CupertinoColors.systemBlue),
  ),
)
```

### 4. Pickers and Modals
```dart
// iOS-style picker modal
void _showPicker() {
  showCupertinoModalPopup<void>(
    context: context,
    builder: (context) => Container(
      height: 300,
      color: CupertinoColors.systemBackground,
      child: SafeArea(
        child: Column(
          children: [
            // Drag handle
            Container(
              width: 40, height: 4,
              margin: EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey4,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Picker
            Expanded(
              child: CupertinoPicker(
                magnification: 1.2,
                squeeze: 1.2,
                useMagnifier: true,
                itemExtent: 50,
                onSelectedItemChanged: (index) => _handleSelection(index),
                children: items.map((item) => Center(child: Text(item))).toList(),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
```

### 5. Navigation
```dart
// iOS-style navigation bar
CupertinoNavigationBar(
  middle: Text('Title'),
  leading: CupertinoNavigationBarBackButton(
    onPressed: () => Navigator.pop(context),
  ),
  trailing: CupertinoButton(
    padding: EdgeInsets.zero,
    onPressed: () => _handleAction(),
    child: Icon(CupertinoIcons.add),
  ),
)
```

### 6. Lists and Cards
```dart
// iOS-style list items
CupertinoListSection.insetGrouped(
  header: Text('Section Header'),
  children: [
    CupertinoListTile(
      title: Text('Item Title'),
      subtitle: Text('Item subtitle'),
      trailing: CupertinoListTileNotchedArrow(),
      onTap: () => _handleTap(),
    ),
  ],
)
```

### 7. Alerts and Dialogs
```dart
// iOS-style alert
showCupertinoDialog(
  context: context,
  builder: (context) => CupertinoAlertDialog(
    title: Text('Title'),
    content: Text('Message'),
    actions: [
      CupertinoDialogAction(
        onPressed: () => Navigator.pop(context),
        child: Text('Cancel'),
      ),
      CupertinoDialogAction(
        onPressed: () => _handleConfirm(),
        isDefaultAction: true,
        child: Text('Confirm'),
      ),
    ],
  ),
)
```

### 8. Switches and Toggles
```dart
// iOS-style switch
CupertinoSwitch(
  value: isEnabled,
  onChanged: (value) => setState(() => isEnabled = value),
  activeColor: kMainColor,
)
```

### 9. Progress Indicators
```dart
// iOS-style activity indicator
CupertinoActivityIndicator(
  radius: 12,
  color: kMainColor,
)

// iOS-style progress bar
CupertinoSlidingSegmentedControl<int>(
  groupValue: currentStep,
  children: {
    0: Container(padding: EdgeInsets.all(8), child: Text('Step 1')),
    1: Container(padding: EdgeInsets.all(8), child: Text('Step 2')),
    2: Container(padding: EdgeInsets.all(8), child: Text('Step 3')),
  },
)
```

## 🎨 Color System

Use iOS system colors for consistency:

```dart
// Primary colors
CupertinoColors.systemBlue
CupertinoColors.systemGreen
CupertinoColors.systemRed
CupertinoColors.systemOrange
CupertinoColors.systemYellow

// Background colors
CupertinoColors.systemBackground
CupertinoColors.systemGrey6
CupertinoColors.systemGrey5
CupertinoColors.systemGrey4

// Text colors
CupertinoColors.label
CupertinoColors.secondaryLabel
CupertinoColors.tertiaryLabel
CupertinoColors.quaternaryLabel
```

## 📐 Spacing and Typography

```dart
// Consistent spacing
const double kSpacingXS = 4.0;
const double kSpacingS = 8.0;
const double kSpacingM = 16.0;
const double kSpacingL = 24.0;
const double kSpacingXL = 32.0;

// Typography
TextStyle(
  fontSize: 17, // iOS standard
  fontWeight: FontWeight.w400, // Regular
  color: CupertinoColors.label,
)
```

## 🔧 Implementation Tips

### 1. Import Statement
```dart
import 'package:flutter/cupertino.dart';
```

### 2. Platform Detection (Optional)
```dart
import 'dart:io';

bool get isIOS => Platform.isIOS;
bool get isAndroid => Platform.isAndroid;

// Use iOS style on both platforms
Widget buildButton() {
  return CupertinoButton(
    // iOS style for both platforms
  );
}
```

### 3. Theme Consistency
```dart
// In your MaterialApp theme
theme: ThemeData(
  // Your existing theme
  cupertinoOverrideTheme: CupertinoThemeData(
    primaryColor: kMainColor,
    brightness: Brightness.light,
  ),
)
```

## 🚀 Migration Strategy

1. **Start with Core Components**: Segmented controls, text fields, buttons
2. **Update Navigation**: Navigation bars and back buttons
3. **Enhance Interactions**: Pickers, modals, alerts
4. **Polish Details**: Lists, cards, switches
5. **Test Both Platforms**: Ensure everything works smoothly

## ✅ Benefits

- **Consistent Design**: All components follow iOS design principles
- **Better Performance**: Optimized iOS components
- **Native Feel**: Smooth animations and interactions
- **Accessibility**: Built-in iOS accessibility features
- **Future-Proof**: Follows Apple's design guidelines

## 🎯 Current Implementation Status

✅ **Completed**:
- Segmented control for tabs
- Search text field
- Filter button and picker
- Help button styling

🔄 **Next Steps**:
- Navigation bars
- Alert dialogs
- List items
- Settings screens

This approach gives you the best of both worlds: the polished iOS design you love, working perfectly on both iOS and Android platforms! 