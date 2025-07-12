import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for tracking and providing insights about real user behavior
class UserInsightsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Track critical user milestones for cohort analysis
  static Future<void> trackUserMilestone(String milestone) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};
      
      // Calculate days since install
      final createdAt = userData['createdAt'] as Timestamp?;
      final daysSinceInstall = createdAt != null 
          ? DateTime.now().difference(createdAt.toDate()).inDays 
          : 0;

      await _firestore.collection('user_milestones').add({
        'userId': user.uid,
        'milestone': milestone,
        'timestamp': FieldValue.serverTimestamp(),
        'daysSinceInstall': daysSinceInstall,
        'userSegment': userData['subscriptionStatus'] ?? 'unknown',
        'selectedPlan': userData['selectedPlan'],
        'isPremium': userData['isPremium'] ?? false,
      });
    } catch (e) {
      print('❌ Error tracking user milestone: $e');
    }
  }

  /// Get real-time app health metrics
  static Future<Map<String, dynamic>> getAppHealthMetrics() async {
    try {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final weekAgo = now.subtract(const Duration(days: 7));

      // Active users in last 24h
      final dayActiveUsersQuery = await _firestore
          .collection('user_milestones')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(yesterday))
          .get();

      // Active users in last 7 days
      final weekActiveUsersQuery = await _firestore
          .collection('user_milestones')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(weekAgo))
          .get();

      // Premium users
      final premiumUsersQuery = await _firestore
          .collection('users')
          .where('isPremium', isEqualTo: true)
          .get();

      // Trial users
      final trialUsersQuery = await _firestore
          .collection('users')
          .where('subscriptionStatus', isEqualTo: 'trial')
          .get();

      return {
        'dailyActiveUsers': dayActiveUsersQuery.docs.map((d) => d['userId']).toSet().length,
        'weeklyActiveUsers': weekActiveUsersQuery.docs.map((d) => d['userId']).toSet().length,
        'totalPremiumUsers': premiumUsersQuery.docs.length,
        'totalTrialUsers': trialUsersQuery.docs.length,
        'lastUpdated': now.toIso8601String(),
      };
    } catch (e) {
      print('❌ Error getting app health metrics: $e');
      return {};
    }
  }

  /// Track user engagement patterns
  static Future<void> trackUserSession({
    required String screenName,
    required Duration sessionDuration,
    required int actionsPerformed,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('user_sessions').add({
        'userId': user.uid,
        'screenName': screenName,
        'sessionDuration': sessionDuration.inSeconds,
        'actionsPerformed': actionsPerformed,
        'timestamp': FieldValue.serverTimestamp(),
        'date': DateTime.now().toIso8601String().split('T')[0], // YYYY-MM-DD
      });
    } catch (e) {
      print('❌ Error tracking user session: $e');
    }
  }

  /// Get user engagement trends for the dashboard
  static Future<Map<String, dynamic>> getEngagementTrends() async {
    try {
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      
      final sessionsQuery = await _firestore
          .collection('user_sessions')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(weekAgo))
          .get();

      if (sessionsQuery.docs.isEmpty) {
        return {'avgSessionDuration': 0, 'avgActionsPerSession': 0, 'totalSessions': 0};
      }

      final sessions = sessionsQuery.docs.map((doc) => doc.data()).toList();
      
      final totalDuration = sessions.fold<int>(0, (sum, session) => 
          sum + (session['sessionDuration'] as int? ?? 0));
      final totalActions = sessions.fold<int>(0, (sum, session) => 
          sum + (session['actionsPerformed'] as int? ?? 0));

      return {
        'avgSessionDuration': totalDuration / sessions.length,
        'avgActionsPerSession': totalActions / sessions.length,
        'totalSessions': sessions.length,
        'uniqueUsers': sessions.map((s) => s['userId']).toSet().length,
      };
    } catch (e) {
      print('❌ Error getting engagement trends: $e');
      return {};
    }
  }

  /// Quick feature adoption tracking
  static Future<void> trackFeatureAdoption(String feature, bool firstTime) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('feature_adoption').add({
        'userId': user.uid,
        'feature': feature,
        'firstTime': firstTime,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (firstTime) {
        await trackUserMilestone('first_$feature');
      }
    } catch (e) {
      print('❌ Error tracking feature adoption: $e');
    }
  }

  /// Get most popular features
  static Future<List<Map<String, dynamic>>> getPopularFeatures() async {
    try {
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      
      final featuresQuery = await _firestore
          .collection('feature_adoption')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(weekAgo))
          .get();

      final featureCount = <String, int>{};
      for (final doc in featuresQuery.docs) {
        final feature = doc.data()['feature'] as String;
        featureCount[feature] = (featureCount[feature] ?? 0) + 1;
      }

      final sortedFeatures = featureCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sortedFeatures.map((entry) => {
        'feature': entry.key,
        'usage': entry.value,
      }).toList();
    } catch (e) {
      print('❌ Error getting popular features: $e');
      return [];
    }
  }
} 