import 'package:flutter/material.dart';

class DevicePreviewHelper {
  // iPhone screen dimensions for testing
  static const Map<String, Size> deviceSizes = {
    'iPhone SE (2022)': Size(375, 667), // 4.7" screen
    'iPhone 12 mini': Size(375, 812), // 5.4" screen
    'iPhone 12': Size(390, 844), // 6.1" screen
    'iPhone 12 Pro Max': Size(428, 926), // 6.7" screen
    'iPhone 16': Size(393, 852), // 6.1" screen
    'iPhone 16 Pro Max': Size(440, 956), // 6.9" screen
  };

  // Test if current screen size matches a specific device
  static bool isDeviceSize(BuildContext context, String deviceName) {
    final currentSize = MediaQuery.of(context).size;
    final targetSize = deviceSizes[deviceName];
    
    if (targetSize == null) return false;
    
    // Allow for small variations in screen size
    const tolerance = 10.0;
    return (currentSize.width - targetSize.width).abs() < tolerance &&
           (currentSize.height - targetSize.height).abs() < tolerance;
  }

  // Get device name based on screen size
  static String getDeviceName(BuildContext context) {
    final currentSize = MediaQuery.of(context).size;
    
    for (final entry in deviceSizes.entries) {
      const tolerance = 10.0;
      if ((currentSize.width - entry.value.width).abs() < tolerance &&
          (currentSize.height - entry.value.height).abs() < tolerance) {
        return entry.key;
      }
    }
    
    return 'Unknown Device (${currentSize.width.toInt()}x${currentSize.height.toInt()})';
  }

  // Check if device is considered small screen
  static bool isSmallDevice(BuildContext context) {
    return isDeviceSize(context, 'iPhone SE (2022)') || 
           isDeviceSize(context, 'iPhone 12 mini');
  }

  // Get recommended font scale for device
  static double getFontScale(BuildContext context) {
    if (isDeviceSize(context, 'iPhone SE (2022)')) {
      return 0.9; // Slightly smaller fonts for iPhone SE
    } else if (isDeviceSize(context, 'iPhone 12 mini')) {
      return 0.95; // Slightly smaller fonts for iPhone 12 mini
    }
    return 1.0; // Normal font size for other devices
  }

  // Debug widget to show current device info
  static Widget buildDeviceInfo(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final deviceName = getDeviceName(context);
    
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Device: $deviceName',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          Text(
            'Size: ${size.width.toInt()}x${size.height.toInt()}',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          Text(
            'Small Screen: ${isSmallDevice(context)}',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
} 