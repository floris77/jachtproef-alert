import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class PlanAbandonmentService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _cloudFunctionUrl = 
      'https://us-central1-jachtproefalert.cloudfunctions.net/send-plan-abandonment-email';

  /// Track when user visits plan selection screen
  static Future<void> trackPlanSelectionVisit() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final String userId = user.uid;
      final String userEmail = user.email ?? '';
      final String userName = user.displayName ?? 'daar';

      // Store plan visit data
      await _firestore.collection('plan_abandonment_tracking').doc(userId).set({
        'userId': userId,
        'userEmail': userEmail,
        'userName': userName,
        'visitedPlanSelection': true,
        'visitTimestamp': FieldValue.serverTimestamp(),
        'completedPurchase': false,
        'abandonmentEmailSent': false,
      }, SetOptions(merge: true));

      print('📊 Plan selection visit tracked for user: $userId');

      // Schedule abandonment check (24 hours later)
      _scheduleAbandonmentCheck(userId, userEmail, userName);
    } catch (e) {
      print('❌ Error tracking plan selection visit: $e');
    }
  }

  /// Track when user completes subscription purchase
  static Future<void> trackPurchaseCompletion() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final String userId = user.uid;

      // First check if the document exists, if not create it
      final docRef = _firestore.collection('plan_abandonment_tracking').doc(userId);
      final doc = await docRef.get();
      
      if (!doc.exists) {
        // Create the document first with basic data
        await docRef.set({
          'userId': userId,
          'userEmail': user.email ?? '',
          'userName': user.displayName ?? 'daar',
          'visitedPlanSelection': false,
          'visitTimestamp': FieldValue.serverTimestamp(),
          'completedPurchase': false,
          'abandonmentEmailSent': false,
        });
        print('📊 Created plan abandonment tracking document for user: $userId');
      }

      // Update tracking document to mark purchase as completed
      await docRef.update({
        'completedPurchase': true,
        'purchaseTimestamp': FieldValue.serverTimestamp(),
      });

      print('✅ Purchase completion tracked for user: $userId');
    } catch (e) {
      print('❌ Error tracking purchase completion: $e');
      // Don't throw the error - this is non-critical tracking
    }
  }

  /// Schedule an abandonment check for 24 hours later
  static void _scheduleAbandonmentCheck(String userId, String userEmail, String userName) {
    // In a real production app, you would use Cloud Scheduler or similar
    // For now, we'll use a simple delayed check
    Future.delayed(const Duration(hours: 24), () {
      _checkAndSendAbandonmentEmail(userId, userEmail, userName);
    });

    // Also schedule immediate check for testing (remove in production)
    Future.delayed(const Duration(minutes: 1), () {
      _checkAndSendAbandonmentEmail(userId, userEmail, userName);
    });
  }

  /// Check if user abandoned plan and send email if needed
  static Future<void> _checkAndSendAbandonmentEmail(String userId, String userEmail, String userName) async {
    try {
      // Get latest tracking data
      final doc = await _firestore.collection('plan_abandonment_tracking').doc(userId).get();
      
      if (!doc.exists) return;

      final data = doc.data()!;
      final bool completedPurchase = data['completedPurchase'] ?? false;
      final bool abandonmentEmailSent = data['abandonmentEmailSent'] ?? false;
      final bool visitedPlanSelection = data['visitedPlanSelection'] ?? false;

      // Send abandonment email if:
      // 1. User visited plan selection
      // 2. User hasn't completed purchase
      // 3. Abandonment email hasn't been sent yet
      if (visitedPlanSelection && !completedPurchase && !abandonmentEmailSent) {
        final success = await _sendAbandonmentEmail(userEmail, userName);
        
        if (success) {
          // Mark abandonment email as sent
          await _firestore.collection('plan_abandonment_tracking').doc(userId).update({
            'abandonmentEmailSent': true,
            'abandonmentEmailTimestamp': FieldValue.serverTimestamp(),
          });
          
          print('📧 Abandonment email sent successfully to: $userEmail');
        }
      }
    } catch (e) {
      print('❌ Error checking abandonment status: $e');
    }
  }

  /// Send plan abandonment email via cloud function
  static Future<bool> _sendAbandonmentEmail(String userEmail, String userName) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final idToken = await user.getIdToken();

      final response = await http.post(
        Uri.parse(_cloudFunctionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'email': userEmail,
          'name': userName,
        }),
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        print('✅ Plan abandonment email sent: ${result['message']}');
        print('📧 Email ID: ${result['email_id']}');
        return true;
      } else {
        print('❌ Failed to send abandonment email: ${response.statusCode}');
        print('Response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error sending abandonment email: $e');
      return false;
    }
  }

  /// Manual trigger for abandonment email (testing/admin use)
  static Future<bool> sendAbandonmentEmailManually(String userEmail, String userName) async {
    return await _sendAbandonmentEmail(userEmail, userName);
  }

  /// Get abandonment stats for analytics
  static Future<Map<String, dynamic>> getAbandonmentStats() async {
    try {
      final QuerySnapshot query = await _firestore
          .collection('plan_abandonment_tracking')
          .where('visitedPlanSelection', isEqualTo: true)
          .get();

      int totalVisits = query.docs.length;
      int completedPurchases = 0;
      int abandonmentEmailsSent = 0;

      for (var doc in query.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['completedPurchase'] == true) completedPurchases++;
        if (data['abandonmentEmailSent'] == true) abandonmentEmailsSent++;
      }

      final int abandoners = totalVisits - completedPurchases;
      final double conversionRate = totalVisits > 0 ? (completedPurchases / totalVisits) * 100 : 0.0;

      return {
        'totalPlanVisits': totalVisits,
        'completedPurchases': completedPurchases,
        'abandoners': abandoners,
        'abandonmentEmailsSent': abandonmentEmailsSent,
        'conversionRate': conversionRate.toStringAsFixed(1),
      };
    } catch (e) {
      print('❌ Error getting abandonment stats: $e');
      return {};
    }
  }
} 