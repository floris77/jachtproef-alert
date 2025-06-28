import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'notification_service.dart';
import 'enrollment_confirmation_service.dart';

/// Policy-compliant viral sharing service based on Alex Hormozi's principles
/// Uses in-app prompts, email, and safe notification methods instead of interactive push
class ViralSharingService {
  static const String _lastSharingPromptKey = 'last_sharing_prompt';
  static const String _sharingCooldownPrefix = 'sharing_cooldown_';
  static const String _userSharingStatsKey = 'user_sharing_stats';
  
  // Cooldown periods (14 days in production, 30 seconds in debug)
  static const int _productionCooldownDays = 14;
  static const int _debugCooldownSeconds = 30;
  
  /// Check if user should see a sharing prompt after enrollment response
  static Future<bool> shouldShowSharingPrompt(String matchKey) async {
    final prefs = await SharedPreferences.getInstance();
    final cooldownKey = '$_sharingCooldownPrefix$matchKey';
    final lastPromptTimestamp = prefs.getInt(cooldownKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    final cooldownDuration = kDebugMode 
        ? _debugCooldownSeconds * 1000 
        : _productionCooldownDays * 24 * 60 * 60 * 1000;
    
    return (now - lastPromptTimestamp) >= cooldownDuration;
  }
  
  /// Record that a sharing prompt was shown to start cooldown
  static Future<void> recordSharingPromptShown(String matchKey) async {
    final prefs = await SharedPreferences.getInstance();
    final cooldownKey = '$_sharingCooldownPrefix$matchKey';
    await prefs.setInt(cooldownKey, DateTime.now().millisecondsSinceEpoch);
  }
  
  /// Show in-app sharing prompt after enrollment response
  static Future<void> showInAppSharingPrompt(
    BuildContext context, {
    required String matchTitle,
    required String matchLocation,
    required bool userEnrolled,
  }) async {
    final message = userEnrolled 
        ? _getEnrolledSharingMessage(matchTitle, matchLocation)
        : _getMissedSharingMessage(matchTitle, matchLocation);
    
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.share, color: Colors.green),
            SizedBox(width: 8),
            Text('Deel met vrienden'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            SizedBox(height: 16),
            Text(
              'Help andere jagers deze geweldige app te ontdekken!',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Misschien later'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _shareApp(context, matchTitle, userEnrolled);
              _trackSharingAction('in_app_prompt', userEnrolled);
            },
            icon: Icon(Icons.share),
            label: Text('Delen'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
  
  /// Show sharing prompt as a bottom sheet (less intrusive)
  static Future<void> showSharingBottomSheet(
    BuildContext context, {
    required String matchTitle,
    required String matchLocation,
    required bool userEnrolled,
  }) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
            
            // Icon and title
            Icon(Icons.favorite, color: Colors.red, size: 48),
            SizedBox(height: 16),
            Text(
              'Vond je dit handig?',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            
            // Message
            Text(
              userEnrolled 
                  ? 'Geweldig dat je je hebt ingeschreven voor $matchTitle! Deel JachtProef Alert met vrienden zodat zij ook geen proeven missen.'
                  : 'Jammer dat $matchTitle niet uitkwam. Deel JachtProef Alert met vrienden - misschien kunnen zij wel!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            SizedBox(height: 24),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Niet nu'),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _shareApp(context, matchTitle, userEnrolled);
                      _trackSharingAction('bottom_sheet', userEnrolled);
                    },
                    icon: Icon(Icons.share),
                    label: Text('Delen'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
          ],
        ),
      ),
    );
  }
  
  /// Send sharing prompt via email (policy-compliant alternative)
  static Future<void> sendSharingEmail({
    required String userEmail,
    required String matchTitle,
    required String matchLocation,
    required bool userEnrolled,
  }) async {
    // This would integrate with your existing email service
    // For now, we'll just log the intent
    print('📧 Would send sharing email to $userEmail about $matchTitle');
    
    // TODO: Integrate with EmailNotificationService to send sharing prompt emails
    // This is policy-compliant as it's opt-in email communication
  }
  
  /// Schedule a gentle in-app reminder for later (not a push notification)
  static Future<void> scheduleInAppReminder(String matchKey, String matchTitle) async {
    final prefs = await SharedPreferences.getInstance();
    final reminderKey = 'sharing_reminder_$matchKey';
    final reminderData = {
      'matchKey': matchKey,
      'matchTitle': matchTitle,
      'scheduledAt': DateTime.now().millisecondsSinceEpoch,
    };
    
    await prefs.setString(reminderKey, reminderData.toString());
    print('📝 Scheduled in-app sharing reminder for $matchTitle');
  }
  
  /// Check for pending in-app reminders when user opens the app
  static Future<List<Map<String, dynamic>>> getPendingInAppReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith('sharing_reminder_'));
    final reminders = <Map<String, dynamic>>[];
    
    for (final key in keys) {
      final reminderData = prefs.getString(key);
      if (reminderData != null) {
        // Parse reminder data and check if it should be shown
        // This is a simplified version - you'd want proper JSON parsing
        reminders.add({
          'key': key,
          'data': reminderData,
        });
      }
    }
    
    return reminders;
  }
  
  /// Show contextual sharing prompts during natural app usage
  static Future<void> showContextualSharingPrompt(
    BuildContext context, {
    required String trigger, // 'app_open', 'match_browse', 'settings_visit'
  }) async {
    final shouldShow = await _shouldShowContextualPrompt(trigger);
    if (!shouldShow) return;
    
    // Show a subtle banner or card, not a disruptive popup
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.favorite, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text('Vind je JachtProef Alert handig? Deel het met vrienden!'),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'Delen',
          textColor: Colors.yellow,
          onPressed: () {
            _shareApp(context, 'JachtProef Alert', true);
            _trackSharingAction('contextual_$trigger', true);
          },
        ),
        duration: Duration(seconds: 8),
        backgroundColor: Colors.green,
      ),
    );
    
    await _recordContextualPromptShown(trigger);
  }
  
  /// Create shareable content with tracking
  static Future<void> _shareApp(BuildContext context, String matchTitle, bool enrolled) async {
    final shareText = enrolled
        ? 'Ik heb me net ingeschreven voor $matchTitle via JachtProef Alert! 🎯\n\nDeze app is echt geweldig - je mist nooit meer een jachtproef. Download hem hier: https://play.google.com/store/apps/details?id=com.jachtproef.alert'
        : 'Ik gebruik JachtProef Alert om alle jachtproeven bij te houden! 🎯\n\nSuper handig om nooit meer een proef te missen. Probeer het zelf: https://play.google.com/store/apps/details?id=com.jachtproef.alert';
    
    try {
      await Share.share(
        shareText,
        subject: 'Check deze handige jachtproef app!',
      );
      
      // Track successful share
      await _incrementSharingStats();
      
    } catch (e) {
      print('❌ Error sharing app: $e');
    }
  }
  
  /// Generate sharing messages based on enrollment status
  static String _getEnrolledSharingMessage(String matchTitle, String matchLocation) {
    return 'Geweldig! Je hebt je ingeschreven voor $matchTitle in $matchLocation.\n\n'
           'Wil je vrienden ook helpen om geen proeven te missen? Deel JachtProef Alert met hen!';
  }
  
  static String _getMissedSharingMessage(String matchTitle, String matchLocation) {
    return 'Jammer dat $matchTitle in $matchLocation niet uitkwam voor je.\n\n'
           'Misschien hebben vrienden van je wel interesse? Deel JachtProef Alert zodat zij ook op de hoogte blijven!';
  }
  
  /// Check if contextual prompt should be shown
  static Future<bool> _shouldShowContextualPrompt(String trigger) async {
    final prefs = await SharedPreferences.getInstance();
    final lastShownKey = 'contextual_prompt_$trigger';
    final lastShown = prefs.getInt(lastShownKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // Show contextual prompts max once per week
    const weekInMs = 7 * 24 * 60 * 60 * 1000;
    return (now - lastShown) >= weekInMs;
  }
  
  /// Record when contextual prompt was shown
  static Future<void> _recordContextualPromptShown(String trigger) async {
    final prefs = await SharedPreferences.getInstance();
    final lastShownKey = 'contextual_prompt_$trigger';
    await prefs.setInt(lastShownKey, DateTime.now().millisecondsSinceEpoch);
  }
  
  /// Track sharing actions for analytics
  static Future<void> _trackSharingAction(String method, bool enrolled) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('sharing_analytics')
            .add({
          'userId': user.uid,
          'method': method,
          'enrolled': enrolled,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('❌ Error tracking sharing action: $e');
    }
  }
  
  /// Increment user's sharing statistics
  static Future<void> _incrementSharingStats() async {
    final prefs = await SharedPreferences.getInstance();
    final currentStats = prefs.getInt(_userSharingStatsKey) ?? 0;
    await prefs.setInt(_userSharingStatsKey, currentStats + 1);
  }
  
  /// Get user's sharing statistics
  static Future<int> getUserSharingStats() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_userSharingStatsKey) ?? 0;
  }
  
  /// Reset all sharing cooldowns (for testing)
  static Future<void> resetAllCooldowns() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => 
        key.startsWith(_sharingCooldownPrefix) || 
        key.startsWith('contextual_prompt_') ||
        key == _lastSharingPromptKey
    );
    
    for (final key in keys) {
      await prefs.remove(key);
    }
    
    print('🔧 All sharing cooldowns reset');
  }
} 