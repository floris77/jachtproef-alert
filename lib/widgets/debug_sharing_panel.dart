import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/enrollment_confirmation_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/viral_sharing_service.dart';

// Debug widget for testing friend sharing notifications
class DebugSharingPanel extends StatefulWidget {
  final Map<String, dynamic> match;
  final VoidCallback? onStateChanged;
  
  const DebugSharingPanel({Key? key, required this.match, this.onStateChanged}) : super(key: key);

  @override
  _DebugSharingPanelState createState() => _DebugSharingPanelState();
}

class _DebugSharingPanelState extends State<DebugSharingPanel> {
  String _status = "Checking...";
  String _timeRemaining = "";
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    _updateStatus();
    // Set up notification response callback
    NotificationService.onEnrollmentResponse = _handleNotificationEnrollmentResponse;
  }

  @override
  void dispose() {
    // Clean up callback
    NotificationService.onEnrollmentResponse = null;
    super.dispose();
  }

  void _handleNotificationEnrollmentResponse(
    String matchKey,
    String huntTitle,
    String huntLocation, 
    String huntType,
    bool enrolled,
  ) {
    // Handle the enrollment response from the notification
    print('📱 DEBUG: Received notification response for $huntTitle: ${enrolled ? "YES" : "NO"}');
    _handleEnrollmentResponse(enrolled);
  }

  Future<void> _updateStatus() async {
    final matchKey = _getMatchKey();
    final canShow = await ViralSharingService.shouldShowSharingPrompt(matchKey);
    final timeRemaining = await _getTimeUntilNextSharingAllowed();
    
    setState(() {
      _status = canShow ? "✅ Can show sharing prompt" : "⏰ In cooldown period";
      _timeRemaining = "Time until next: $timeRemaining";
    });
  }

  // Debug version with configurable timing
  static const int DEBUG_COOLDOWN_SECONDS = 30;
  static const String LAST_SHARING_NOTIFICATION_KEY = 'last_friend_sharing_notification';

  Future<bool> _canShowFriendSharingNotification() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSharingTimestamp = prefs.getInt(LAST_SHARING_NOTIFICATION_KEY);
    
    if (lastSharingTimestamp == null) return true;
    
    final lastSharingDate = DateTime.fromMillisecondsSinceEpoch(lastSharingTimestamp);
    final timeSinceLastSharing = DateTime.now().difference(lastSharingDate);
    final secondsSinceLastSharing = timeSinceLastSharing.inSeconds;
    
    return secondsSinceLastSharing >= DEBUG_COOLDOWN_SECONDS;
  }

  Future<String> _getTimeUntilNextSharingAllowed() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSharingTimestamp = prefs.getInt(LAST_SHARING_NOTIFICATION_KEY);
    
    if (lastSharingTimestamp == null) return "Can show now";
    
    final lastSharingDate = DateTime.fromMillisecondsSinceEpoch(lastSharingTimestamp);
    final timeSinceLastSharing = DateTime.now().difference(lastSharingDate);
    final secondsRemaining = DEBUG_COOLDOWN_SECONDS - timeSinceLastSharing.inSeconds;
    
    return secondsRemaining > 0 ? "$secondsRemaining seconds" : "Can show now";
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue),
        borderRadius: BorderRadius.circular(8),
        color: Colors.blue.withOpacity(0.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text('🔧 DEBUG: Friend Sharing Test', 
                     style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              IconButton(
                icon: Icon(Icons.close, size: 20),
                onPressed: () => setState(() => _isVisible = false),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(_status, style: TextStyle(fontSize: 14)),
          Text(_timeRemaining, style: TextStyle(fontSize: 14)),
          SizedBox(height: 8),
          Text('Match: ${_getMatchTitle()}', style: TextStyle(fontSize: 12)),
          Text('Location: ${_getMatchLocation()}', style: TextStyle(fontSize: 12)),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _triggerTestEnrollmentCheck,
                  child: Text('Test Enrollment Check', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _resetCooldown,
                  child: Text('Reset Cooldown', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _updateStatus,
                  child: Text('Refresh Status', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _clearEnrollmentConfirmation,
                  child: Text('Clear Enrollment', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _testPushNotifications,
                  child: Text('Test Push', style: TextStyle(fontSize: 10)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    padding: EdgeInsets.symmetric(vertical: 6),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _clearAllEnrollmentConfirmations,
                  child: Text('Clear All', style: TextStyle(fontSize: 10)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: EdgeInsets.symmetric(vertical: 6),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getMatchTitle() {
    return widget.match['title']?.toString() ?? 
           widget.match['organizer']?.toString() ?? 
           widget.match['raw']?['title']?.toString() ?? 
           widget.match['raw']?['organizer']?.toString() ?? 'Unknown';
  }

  String _getMatchLocation() {
    return widget.match['location']?.toString() ?? 
           widget.match['raw']?['location']?.toString() ?? 'Unknown';
  }

  String _getMatchType() {
    return widget.match['type']?.toString() ?? 
           widget.match['raw']?['type']?.toString() ?? 'Proef';
  }

  void _triggerTestEnrollmentCheck() {
    _sendEnrollmentCheckNotification();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Test enrollment check sent! Check your notifications.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );

    print('\n🧪 TEST INSTRUCTIONS:');
    print('1️⃣ Check your notification panel for the enrollment question');
    print('2️⃣ Tap YES or NO on the notification');
    print('3️⃣ If YES: Enrollment button will be enabled for this match');
    print('4️⃣ If cooldown is clear, you should get a friend sharing notification');
    print('5️⃣ Wait 30 seconds, then try again - should NOT get friend sharing');
    print('6️⃣ After 30+ seconds, try again - should get friend sharing again\n');
  }

  void _sendEnrollmentCheckNotification() async {
    final huntTitle = _getMatchTitle();
    final huntLocation = _getMatchLocation();
    final huntType = _getMatchType();
    final matchKey = _getMatchKey();

    // Create a test enrollment deadline (5 hours from now for testing)
    final enrollmentDeadline = DateTime.now().add(Duration(hours: 5));

    print('📝 DEBUG: Sending enrollment check for:');
    print('  Title: $huntTitle');
    print('  Location: $huntLocation');
    print('  Type: $huntType');
    print('  Deadline: $enrollmentDeadline');
    print('');
    print('🔍 DEBUG: Raw match data:');
    print('  match[\'title\']: ${widget.match['title']}');
    print('  match[\'organizer\']: ${widget.match['organizer']}');
    print('  match[\'location\']: ${widget.match['location']}');
    print('  match[\'raw\'][\'title\']: ${widget.match['raw']?['title']}');
    print('  match[\'raw\'][\'organizer\']: ${widget.match['raw']?['organizer']}');
    print('  match[\'raw\'][\'location\']: ${widget.match['raw']?['location']}');
    print('');
    print('🧪 TEST INSTRUCTIONS:');
    print('1️⃣ Check your notification panel for the enrollment question');
    print('2️⃣ Tap YES or NO on the notification action buttons');
    print('3️⃣ If YES: Enrollment button will be enabled for this match');
    print('4️⃣ If cooldown is clear, you should get a friend sharing notification');
    print('5️⃣ Wait 30 seconds, then try again - should NOT get friend sharing');
    print('6️⃣ After 30+ seconds, try again - should get friend sharing again');

    // Send real push notification with action buttons
    try {
      await NotificationService.showEnrollmentConfirmationNotification(
        huntTitle: huntTitle,
        huntLocation: huntLocation,
        huntType: huntType,
        enrollmentDeadline: enrollmentDeadline,
        matchKey: matchKey,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📱 Push notification sent! Check your notification panel and tap the action buttons.'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      print('❌ Error sending push notification: $e');
      // Fallback to dialog if push notifications fail
      _showEnrollmentChoiceDialog(huntTitle, huntLocation, enrollmentDeadline);
    }
  }

  void _showEnrollmentChoiceDialog(String huntTitle, String huntLocation, DateTime enrollmentDeadline) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('📱 Enrollment Check Notification'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('🎯 JachtProef Alert', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              SizedBox(height: 8),
              Text('Did you enroll for this hunting exam?'),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('📍 $huntTitle', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('🏞️ $huntLocation'),
                    Text('⏰ Deadline: ${DateFormat('dd MMM yyyy HH:mm').format(enrollmentDeadline)}'),
                  ],
                ),
              ),
              SizedBox(height: 12),
              Text('(This simulates a real push notification)', 
                   style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _handleEnrollmentResponse(false);
              },
              child: Text('❌ No', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _handleEnrollmentResponse(true);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: Text('✅ Yes', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _simulateNotificationResponse(bool enrolled) {
    // This method is kept for potential future use
    Future.delayed(Duration(seconds: 2), () {
      _handleEnrollmentResponse(enrolled);
    });
  }

  Future<void> _handleEnrollmentResponse(bool enrolled) async {
    final huntTitle = _getMatchTitle();
    final huntLocation = _getMatchLocation();
    final huntType = _getMatchType();
    final enrollmentDeadline = DateTime.now().add(Duration(hours: 5));
    final matchKey = _getMatchKey();

    print('🔍 DEBUG: User ${enrolled ? "confirmed enrollment" : "confirmed miss"} for $huntTitle');

    // NEW: Save enrollment confirmation to enable button
    if (enrolled) {
      await _saveEnrollmentConfirmation(matchKey);
      
      // IMPORTANT: Also save to Firebase so it shows up in agenda
      await _saveToFirebaseMatchActions();
      
      // Trigger parent page refresh to update button state
      if (widget.onStateChanged != null) {
        widget.onStateChanged!();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Enrollment confirmed! Match added to agenda.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }

    // NEW: Use policy-compliant viral sharing service
    await _checkAndTriggerSharingPrompt(huntTitle, huntLocation, enrolled, matchKey);
  }

  Future<void> _saveEnrollmentConfirmation(String matchKey) async {
    final matchTitle = _getMatchTitle();
    final matchLocation = _getMatchLocation();
    
    // Try to get enrollment date from match data
    DateTime? enrollmentDate;
    final regText = (widget.match['registration_text'] ?? 
                    widget.match['raw']?['registration_text'] ?? '').toString().toLowerCase();
    
    if (regText.startsWith('vanaf ')) {
      try {
        // Parse "vanaf DD-MM-YYYY HH:MM" format
        final dateTimeStr = regText.substring(6); // Remove "vanaf "
        final parts = dateTimeStr.split(' ');
        if (parts.length >= 2) {
          final datePart = parts[0]; // DD-MM-YYYY
          final timePart = parts[1]; // HH:MM
          
          final dateComponents = datePart.split('-');
          final timeComponents = timePart.split(':');
          
          if (dateComponents.length == 3 && timeComponents.length == 2) {
            enrollmentDate = DateTime(
              int.parse(dateComponents[2]), // year
              int.parse(dateComponents[1]), // month
              int.parse(dateComponents[0]), // day
              int.parse(timeComponents[0]), // hour
              int.parse(timeComponents[1]), // minute
            );
          }
        }
      } catch (e) {
        print('❌ DEBUG: Error parsing enrollment date: $e');
      }
    }
    
    await EnrollmentConfirmationService.saveEnrollmentConfirmation(
      matchKey,
      matchTitle: matchTitle,
      matchLocation: matchLocation,
      enrollmentDate: enrollmentDate,
    );
    print('💾 DEBUG: Saved enrollment confirmation for match: $matchKey');
    if (enrollmentDate != null) {
      print('📅 DEBUG: Will schedule 15-minute post-enrollment notification for: $enrollmentDate');
    }
  }

  Future<void> _saveToFirebaseMatchActions() async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) {
      print('❌ DEBUG: No user logged in, cannot save to Firebase');
      return;
    }
    
    try {
      final matchKey = _getFirebaseMatchKey();
      await FirebaseFirestore.instance
          .collection('user_actions')
          .doc(user.uid)
          .collection('match_actions')
          .doc(matchKey)
          .set({
            'isRegistered': true,  // This is what makes it show up in agenda
            'notificationsOn': false,
            'inAgenda': false,
            'timestamp': FieldValue.serverTimestamp(),
          });
      print('💾 DEBUG: Saved to Firebase - match will now appear in agenda');
    } catch (e) {
      print('❌ DEBUG: Error saving to Firebase: $e');
    }
  }

  String _getFirebaseMatchKey() {
    // Use the same key format as the main app
    final org = widget.match['organizer'] ?? widget.match['raw']?['organizer'] ?? '';
    final date = widget.match['date'] ?? widget.match['raw']?['date'] ?? '';
    return '${org}_$date';
  }

  Future<void> _shareWithFriends(String huntTitle, String huntLocation, bool userEnrolled) async {
    // Create abbreviated versions for sharing
    final abbreviatedTitle = _abbreviateText(huntTitle, 60);
    final abbreviatedLocation = _abbreviateText(huntLocation, 50);
    
    // Get match date for sharing
    final matchDate = widget.match['date'] ?? widget.match['raw']?['date'] ?? '';
    final formattedDate = _formatDateForSharing(matchDate);
    
    final shareText = userEnrolled 
        ? '''🎯 Jachtproef Alert!

✅ Ik heb me ingeschreven voor deze jachtproef - er is nog plek!

📍 $abbreviatedTitle
🏞️ $abbreviatedLocation
📅 $formattedDate

🤝 Interesse? Schrijf je snel in!

Gedeeld via JachtProef Alert 📱'''
        : '''🎯 Jachtproef Alert!

📢 Er is nog plek voor deze jachtproef!

📍 $abbreviatedTitle
🏞️ $abbreviatedLocation
📅 $formattedDate

🤝 Interesse? Schrijf je snel in!

Gedeeld via JachtProef Alert 📱''';

    try {
      // Show options: Copy to clipboard or Share via system
      await _showSharingOptions(shareText);
    } catch (e) {
      print('❌ DEBUG: Error sharing: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Sharing failed: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _showSharingOptions(String shareText) async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('📤 Share with Friends', 
                   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 20),
              
              // Preview of the text
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                ),
                child: Text(shareText, style: TextStyle(fontSize: 12)),
              ),
              
              SizedBox(height: 20),
              
              // Sharing options
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: shareText));
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('📋 Copied to clipboard!'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: Icon(Icons.copy),
                      label: Text('Copy'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await Share.share(shareText);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('📤 Shared with friends!'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: Icon(Icons.share),
                      label: Text('Share'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 10),
              
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancel'),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDateForSharing(String dateString) {
    try {
      // Try to parse and format the date nicely
      if (dateString.isEmpty) return 'Datum onbekend';
      
      // Handle different date formats that might be in the data
      DateTime? date;
      
      // Try parsing ISO format first
      try {
        date = DateTime.parse(dateString);
      } catch (e) {
        // If that fails, try other common formats
        try {
          date = DateFormat('dd-MM-yyyy').parse(dateString);
        } catch (e) {
          // If all parsing fails, return the original string
          return dateString;
        }
      }
      
      if (date != null) {
        return DateFormat('EEEE d MMMM yyyy', 'nl_NL').format(date);
      }
      
      return dateString;
    } catch (e) {
      return dateString;
    }
  }

  Future<void> _checkAndTriggerFriendSharingNotification(
    String huntTitle,
    String huntLocation,
    String huntType,
    DateTime enrollmentDeadline, 
    bool userEnrolled
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final matchKey = _getMatchKey();
    final cooldownKey = 'friend_sharing_cooldown_$matchKey';
    final lastSentTimestamp = prefs.getInt(cooldownKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final cooldownDuration = kDebugMode ? 30 * 1000 : 14 * 24 * 60 * 60 * 1000; // 30 seconds vs 14 days

    if (now - lastSentTimestamp >= cooldownDuration) {
      // Send friend sharing notification
      _sendFriendSharingNotification(huntTitle, huntLocation, huntType, enrollmentDeadline, userEnrolled);
      
      // Update cooldown
      await prefs.setInt(cooldownKey, now);
      
      print('✅ DEBUG: Friend sharing notification sent');
      print('🕐 DEBUG: Next friend sharing allowed in ${kDebugMode ? '30 seconds' : '14 days'}');
      
      // Update status display
      _updateStatus();
    } else {
      final remainingMs = cooldownDuration - (now - lastSentTimestamp);
      final remainingSeconds = remainingMs ~/ 1000;
      print('⏰ DEBUG: Friend sharing on cooldown for ${remainingSeconds} more seconds');
    }
  }

  void _sendFriendSharingNotification(
    String huntTitle,
    String huntLocation, 
    String huntType,
    DateTime enrollmentDeadline,
    bool userEnrolled
  ) {
    // Create abbreviated versions for logging
    final abbreviatedTitle = _abbreviateText(huntTitle, 50);
    final abbreviatedLocation = _abbreviateText(huntLocation, 40);
    
    final String message = userEnrolled
        ? 'Je hebt je ingeschreven! Laat je vrienden weten dat er nog plek is!'
        : 'Er is nog steeds plek! Deel dit met vrienden die interesse hebben.';

    print('📨 DEBUG: Sending friend sharing notification:');
    print('  Message: $message');
    print('  User enrolled: $userEnrolled');
    print('  Match: $abbreviatedTitle at $abbreviatedLocation');
    
    // Show a dialog to simulate the friend sharing notification
    _showFriendSharingNotificationDialog(message, huntTitle, huntLocation, userEnrolled);
  }

  void _showFriendSharingNotificationDialog(String message, String huntTitle, String huntLocation, bool userEnrolled) {
    // Abbreviate long titles and locations for better readability
    final abbreviatedTitle = _abbreviateText(huntTitle, 40);
    final abbreviatedLocation = _abbreviateText(huntLocation, 35);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Text('📱'),
              SizedBox(width: 8),
              Expanded(child: Text('Friend Sharing Notification')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('🎯 JachtProef Alert', 
                   style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              SizedBox(height: 12),
              
              // Main sharing message - make it stand out
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: userEnrolled ? Colors.green.withOpacity(0.15) : Colors.blue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: userEnrolled ? Colors.green : Colors.blue,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Highlight the key message
                    Text(
                      userEnrolled 
                        ? '✅ Je hebt je ingeschreven!' 
                        : '📢 Er is nog plek!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: userEnrolled ? Colors.green[700] : Colors.blue[700],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '🤝 Laat je vrienden weten dat er nog plek is!',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange[700],
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 12),
              
              // Match details - smaller and less prominent
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('📍 $abbreviatedTitle', 
                         style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                    Text('🏞️ $abbreviatedLocation', 
                         style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                  ],
                ),
              ),
              
              SizedBox(height: 12),
              Text('(This simulates a friend sharing notification)', 
                   style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Dismiss'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _shareApp(huntTitle, userEnrolled);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: Text('📤 Share', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  String _abbreviateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    
    // Try to abbreviate common long words first
    String abbreviated = text
        .replaceAll('Stichting', 'St.')
        .replaceAll('Vereniging', 'Ver.')
        .replaceAll('Jachthonden', 'JH')
        .replaceAll('Jachthondentraining', 'JHT')
        .replaceAll('Jachthondenopleiding', 'JHO')
        .replaceAll('i.s.m:', '&')
        .replaceAll('Provincie', 'Prov.')
        .replaceAll('Nederland', 'NL')
        .replaceAll('Nederlandse', 'NL')
        .replaceAll('Aanvang:', 'Start:');
    
    // If still too long, truncate with ellipsis
    if (abbreviated.length > maxLength) {
      return abbreviated.substring(0, maxLength - 3) + '...';
    }
    
    return abbreviated;
  }

  /// NEW: Policy-compliant sharing prompt using ViralSharingService
  Future<void> _checkAndTriggerSharingPrompt(
    String huntTitle,
    String huntLocation,
    bool userEnrolled,
    String matchKey,
  ) async {
    // Check if sharing prompt should be shown (respects cooldown)
    final shouldShow = await ViralSharingService.shouldShowSharingPrompt(matchKey);
    
    if (shouldShow) {
      print('✅ DEBUG: Showing policy-compliant sharing prompt');
      
      // Show in-app sharing prompt (policy-compliant)
      await ViralSharingService.showSharingBottomSheet(
        context,
        matchTitle: huntTitle,
        matchLocation: huntLocation,
        userEnrolled: userEnrolled,
      );
      
      // Record that prompt was shown to start cooldown
      await ViralSharingService.recordSharingPromptShown(matchKey);
      
      print('🕐 DEBUG: Next sharing prompt allowed in ${kDebugMode ? '30 seconds' : '14 days'}');
      
      // Update status display
      _updateStatus();
    } else {
      print('⏰ DEBUG: Sharing prompt on cooldown');
      
      // Show debug feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⏰ Sharing prompt on cooldown - respecting user preferences'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  /// Share app using the system share dialog
  void _shareApp(String huntTitle, bool enrolled) async {
    final shareText = enrolled
        ? 'Ik heb me net ingeschreven voor $huntTitle via JachtProef Alert! 🎯\n\nDeze app is echt geweldig - je mist nooit meer een jachtproef. Download hem hier: https://play.google.com/store/apps/details?id=com.jachtproef.alert'
        : 'Ik gebruik JachtProef Alert om alle jachtproeven bij te houden! 🎯\n\nSuper handig om nooit meer een proef te missen. Probeer het zelf: https://play.google.com/store/apps/details?id=com.jachtproef.alert';
    
    try {
      await Share.share(
        shareText,
        subject: 'Check deze handige jachtproef app!',
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📤 App shared successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('❌ Error sharing app: $e');
    }
  }

  Future<void> _resetCooldown() async {
    // Use the new viral sharing service to reset cooldowns
    await ViralSharingService.resetAllCooldowns();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('All sharing cooldowns reset! You can get sharing prompts again.'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
    
    _updateStatus();
  }

  String _getMatchKey() {
    // Use the same key generation logic as the main page
    final org = widget.match['organizer'] ?? widget.match['raw']?['organizer'] ?? '';
    final date = widget.match['date'] ?? widget.match['raw']?['date'] ?? '';
    return '${org}_$date';
  }
  
  Future<void> _clearEnrollmentConfirmation() async {
    final matchKey = _getMatchKey();
    await EnrollmentConfirmationService.removeEnrollmentConfirmation(matchKey);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ Enrollment confirmation cleared! Button will be disabled.'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
    
    print('🗑️ DEBUG: Cleared enrollment confirmation for match: $matchKey');
  }

  Future<void> _clearAllEnrollmentConfirmations() async {
    await EnrollmentConfirmationService.clearAllEnrollmentConfirmations();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🧹 All enrollment confirmations cleared!'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 3),
      ),
    );
    
    print('🧹 DEBUG: Cleared ALL enrollment confirmations');
  }

  void _testPushNotifications() async {
    print('🔔 DEBUG: Testing push notifications...');
    
    // Show immediate feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🔔 Starting notification test...'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 2),
      ),
    );
    
    try {
      // First, request permissions explicitly
      print('🔐 DEBUG: Requesting notification permissions...');
      await NotificationService.requestPermissions();
      
      // Wait a moment for permissions to be processed
      await Future.delayed(Duration(milliseconds: 500));
      
      // Test 1: Simple notification
      print('📤 DEBUG: Sending simple test notification with ID 999...');
      await NotificationService.showNotification(
        id: 999,
        title: 'JachtProef Test',
        body: 'If you see this, notifications are working! 🎉',
      );
      print('✅ DEBUG: Simple notification sent successfully');
      
      // Show feedback for first notification
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📱 First notification sent! Check notification center.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      
      // Wait before second notification
      await Future.delayed(Duration(seconds: 3));
      
      // Test 2: Enrollment confirmation notification (with action buttons)
      print('📤 DEBUG: Sending enrollment confirmation notification with action buttons...');
      await NotificationService.showEnrollmentConfirmationNotification(
        huntTitle: _getMatchTitle(),
        huntLocation: _getMatchLocation(),
        huntType: _getMatchType(),
        enrollmentDeadline: DateTime.now().add(Duration(hours: 5)),
        matchKey: _getMatchKey(),
      );
      print('✅ DEBUG: Enrollment notification sent successfully');
      
      // Final success feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 Both notifications sent! Swipe down to see them.'),
          backgroundColor: Colors.purple,
          duration: Duration(seconds: 5),
        ),
      );
      
      print('🔔 DEBUG: All test notifications sent successfully! Check your notification panel.');
    } catch (e) {
      print('❌ Error sending test notifications: $e');
      print('❌ Stack trace: ${e.toString()}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 6),
        ),
      );
    }
  }
} 