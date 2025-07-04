import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';
import 'package:jachtproef_alert/services/points_service.dart';
import 'analytics_service.dart';

class EnrollmentConfirmationService {
  static const String _enrollmentPrefix = 'enrollment_confirmed_';
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Check if user has confirmed enrollment for a specific match
  static Future<bool> isEnrollmentConfirmed(String matchKey) async {
    final prefs = await SharedPreferences.getInstance();
    final enrollmentKey = '$_enrollmentPrefix$matchKey';
    return prefs.getBool(enrollmentKey) ?? false;
  }
  
  /// Save enrollment confirmation for a match
  static Future<void> saveEnrollmentConfirmation(String matchKey, {
    String? matchTitle,
    String? matchLocation,
    DateTime? enrollmentDate,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final enrollmentKey = '$_enrollmentPrefix$matchKey';
    await prefs.setBool(enrollmentKey, true);
    
    // Schedule 15-minute post-enrollment notification if enrollment date is provided and user has enabled it
    if (enrollmentDate != null && matchTitle != null) {
      final userWantsPostEnrollmentNotification = await _isPostEnrollmentNotificationEnabled();
      if (userWantsPostEnrollmentNotification) {
        await _schedulePostEnrollmentNotification(
          matchKey: matchKey,
          matchTitle: matchTitle,
          matchLocation: matchLocation ?? 'Onbekend',
          enrollmentDate: enrollmentDate,
        );
      }
    }
  }
  
  /// Check if user has enabled 15-minute post-enrollment notifications
  static Future<bool> _isPostEnrollmentNotificationEnabled() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return true; // Default to enabled for anonymous users
      
      // First try to load from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;
        final timings = data['notificationTimes'] as List<dynamic>?;
        
        if (timings != null && timings.length >= 5) {
          return timings[4] == true; // Index 4 is the 15-minute post-enrollment option
        }
      }
      
      // Fallback to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userKey = 'notification_times_${user.uid}';
      final savedTimes = prefs.getString(userKey);
      
      if (savedTimes != null) {
        final indices = savedTimes.split(',').map((e) => int.tryParse(e)).where((e) => e != null).cast<int>().toList();
        return indices.contains(4); // Check if index 4 (15-min post-enrollment) is enabled
      }
      
      return true; // Default to enabled if no preference found
    } catch (e) {
      print('❌ Error checking post-enrollment notification preference: $e');
      return true; // Default to enabled on error
    }
  }

  /// Schedule a notification 15 minutes after enrollment opens
  static Future<void> _schedulePostEnrollmentNotification({
    required String matchKey,
    required String matchTitle,
    required String matchLocation,
    required DateTime enrollmentDate,
  }) async {
    try {
      final notificationTime = enrollmentDate.add(const Duration(minutes: 15));
      
      // Only schedule if the notification time is in the future
      if (notificationTime.isAfter(DateTime.now())) {
        final abbreviatedTitle = matchTitle.length > 50 
            ? '${matchTitle.substring(0, 47)}...' 
            : matchTitle;
        final abbreviatedLocation = matchLocation.length > 30
            ? '${matchLocation.substring(0, 27)}...'
            : matchLocation;
            
        await NotificationService.scheduleNotification(
          id: '${matchKey}_post_enrollment'.hashCode,
          title: '⏰ Inschrijving Herinnering',
          body: 'Vergeet niet je in te schrijven voor "$abbreviatedTitle" in $abbreviatedLocation! De inschrijving is nu open.',
          scheduledTime: notificationTime,
          payload: 'post_enrollment_reminder|$matchKey',
        );
        
        print('📱 Scheduled 15-minute post-enrollment notification for $matchTitle at $notificationTime');
      }
    } catch (e) {
      print('❌ Error scheduling post-enrollment notification: $e');
    }
  }
  
  /// Remove enrollment confirmation for a match
  static Future<void> removeEnrollmentConfirmation(String matchKey) async {
    final prefs = await SharedPreferences.getInstance();
    final enrollmentKey = '$_enrollmentPrefix$matchKey';
    await prefs.remove(enrollmentKey);
  }
  
  /// Generate a consistent match key from match data
  static String generateMatchKey(Map<String, dynamic> match) {
    // Prefer unique ID if available
    final id = match['id']?.toString() ?? match['key']?.toString();
    if (id != null && id.isNotEmpty) {
      return id;
    }
    // Fallback to old logic
    final title = match['title']?.toString() ?? 
                 match['organizer']?.toString() ?? 
                 match['raw']?['title']?.toString() ?? 
                 match['raw']?['organizer']?.toString() ?? 'Unknown';
    final location = match['location']?.toString() ?? 
                    match['raw']?['location']?.toString() ?? 'Unknown';
    return '${title}_$location';
  }
  
  /// Clear all enrollment confirmations (for debugging or reset)
  static Future<void> clearAllEnrollmentConfirmations() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith(_enrollmentPrefix)) {
        await prefs.remove(key);
      }
    }
  }

  Future<void> confirmEnrollment(String matchId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Update enrollment status
      await _firestore.collection('matches').doc(matchId).update({
        'enrolledUsers': FieldValue.arrayUnion([user.uid]),
      });

      // Award points for enrollment
      await PointsService.awardEnrollmentPoints(matchId);

      // Track enrollment
      AnalyticsService.logUserAction('match_enroll', parameters: {
        'match_id': matchId,
      });
    } catch (e) {
      print('Error confirming enrollment: $e');
      rethrow;
    }
  }
} 