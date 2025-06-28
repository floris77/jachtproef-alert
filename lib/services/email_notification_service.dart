import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EmailNotificationService {
  static const String _cloudFunctionUrl = 
      'https://us-central1-jachtproefalert.cloudfunctions.net/send-match-notification';

  /// Send match-specific email notification
  static Future<bool> sendMatchNotification({
    required String userEmail,
    required String matchTitle,
    required String matchLocation,
    required String matchDate,
    required String notificationType, // 'enrollment_opening', 'enrollment_closing', 'match_reminder'
    required String matchKey,
  }) async {
    try {
      // Get Firebase Auth token
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No authenticated user for email notification');
        return false;
      }

      final idToken = await user.getIdToken();

      final response = await http.post(
        Uri.parse(_cloudFunctionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'email': userEmail,
          'matchTitle': matchTitle,
          'matchLocation': matchLocation,
          'matchDate': matchDate,
          'notificationType': notificationType,
          'matchKey': matchKey,
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Match notification email sent successfully');
        return true;
      } else {
        print('❌ Failed to send match notification: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error sending match notification: $e');
      return false;
    }
  }

  /// Schedule email notification for a specific match
  static Future<void> scheduleMatchNotification({
    required String matchKey,
    required Map<String, dynamic> matchData,
    required String notificationType,
    required DateTime scheduledTime,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Store notification schedule in Firestore
      await FirebaseFirestore.instance
          .collection('scheduled_notifications')
          .doc(user.uid)
          .collection('match_notifications')
          .doc('${matchKey}_$notificationType')
          .set({
        'userId': user.uid,
        'userEmail': user.email,
        'matchKey': matchKey,
        'matchData': matchData,
        'notificationType': notificationType,
        'scheduledTime': Timestamp.fromDate(scheduledTime),
        'status': 'scheduled',
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('✅ Match notification scheduled for ${scheduledTime.toString()}');
    } catch (e) {
      print('❌ Error scheduling match notification: $e');
    }
  }

  /// Cancel email notification for a specific match
  static Future<void> cancelMatchNotification({
    required String matchKey,
    required String notificationType,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('scheduled_notifications')
          .doc(user.uid)
          .collection('match_notifications')
          .doc('${matchKey}_$notificationType')
          .delete();

      print('✅ Match notification cancelled for $matchKey');
    } catch (e) {
      print('❌ Error cancelling match notification: $e');
    }
  }

  /// Check if user has email notifications enabled globally
  static Future<bool> areEmailNotificationsEnabled() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      final userData = userDoc.data() ?? {};
      return userData['emailNotifications'] == true;
    } catch (e) {
      print('Error checking email notification setting: $e');
      return false;
    }
  }

  /// Enable/disable email notifications globally for user
  static Future<void> setEmailNotificationsEnabled(bool enabled) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'emailNotifications': enabled,
      }, SetOptions(merge: true));

      print('✅ Email notifications ${enabled ? 'enabled' : 'disabled'}');
    } catch (e) {
      print('❌ Error updating email notification setting: $e');
    }
  }
} 