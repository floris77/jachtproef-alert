import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PointsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Points constants
  static const int POINTS_FOR_ENROLLMENT = 1;
  static const int POINTS_FOR_SHARING = 1;
  
  /// Award points for enrolling in a match
  static Future<void> awardEnrollmentPoints(String matchId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    
    try {
      // Update user points
      await _firestore.collection('user_points').doc(userId).set({
        'totalPoints': FieldValue.increment(POINTS_FOR_ENROLLMENT),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      // Update leaderboard
      await _updateLeaderboard(userId);
    } catch (e) {
      print('Error awarding enrollment points: $e');
    }
  }
  
  /// Award points for sharing a match
  static Future<void> awardSharingPoints(String matchId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    
    try {
      // Update user points
      await _firestore.collection('user_points').doc(userId).set({
        'totalPoints': FieldValue.increment(POINTS_FOR_SHARING),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      // Update leaderboard
      await _updateLeaderboard(userId);
    } catch (e) {
      print('Error awarding sharing points: $e');
    }
  }
  
  /// Get user's total points
  static Future<int> getUserPoints() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return 0;
    
    try {
      final doc = await _firestore.collection('user_points').doc(userId).get();
      return doc.data()?['totalPoints'] ?? 0;
    } catch (e) {
      print('Error getting user points: $e');
      return 0;
    }
  }
  
  /// Get user's rank
  static Future<int> getUserRank() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return 0;
    
    try {
      final userPoints = await getUserPoints();
      final higherRankedUsers = await _firestore
          .collection('leaderboard')
          .where('totalPoints', isGreaterThan: userPoints)
          .count()
          .get();
      
      return (higherRankedUsers.count ?? 0) + 1;
    } catch (e) {
      print('Error getting user rank: $e');
      return 0;
    }
  }
  
  /// Get top users for leaderboard
  static Stream<QuerySnapshot> getTopUsers() {
    return _firestore
        .collection('leaderboard')
        .orderBy('totalPoints', descending: true)
        .limit(50)
        .snapshots();
  }
  
  /// Update leaderboard for a user
  static Future<void> _updateLeaderboard(String userId) async {
    try {
      final userDoc = await _firestore.collection('user_points').doc(userId).get();
      final userData = userDoc.data();
      
      if (userData != null) {
        await _firestore.collection('leaderboard').doc(userId).set({
          'userId': userId,
          'userName': userData['userName'] ?? 'Anonymous',
          'totalPoints': userData['totalPoints'] ?? 0,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error updating leaderboard: $e');
    }
  }
} 