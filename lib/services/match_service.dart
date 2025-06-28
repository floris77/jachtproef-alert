import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// IMPORTANT: This service reads from Firebase Firestore, NOT from an API.
/// 
/// JachtProef Alert uses a scraper system:
/// 1. Cloud Function scrapes ORWEJA website every 24 hours
/// 2. Data is stored in Firebase Firestore 'matches' collection
/// 3. This service reads directly from Firestore
/// 
/// There is NO API for this app and there never will be.
/// Do NOT implement or consider API endpoints for match data.
/// 
/// The scraper system is the correct and only approach for this project.

class MatchService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Fetch matches from Firestore (not API)
  static Future<List<Map<String, dynamic>>> fetchMatches() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('❌ No authenticated user for Firestore request');
        return [];
      }

      // Read directly from Firestore instead of API
      final snapshot = await _firestore.collection('matches').get();
      
      if (snapshot.docs.isEmpty) {
        print('📭 No matches found in Firestore');
        return [];
      }

      final matches = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();

      print('✅ Successfully fetched ${matches.length} matches from Firestore');
      return matches;
      
    } catch (e) {
      print('❌ Error fetching matches from Firestore: $e');
      return [];
    }
  }

  /// Get match details from Firestore (not API)
  static Future<Map<String, dynamic>?> getMatchDetails(String matchId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('❌ No authenticated user for Firestore request');
        return null;
      }

      // Read directly from Firestore instead of API
      final doc = await _firestore.collection('matches').doc(matchId).get();
      
      if (!doc.exists) {
        print('❌ Match not found in Firestore: $matchId');
        return null;
      }

      final data = doc.data()!;
      return {
        'id': doc.id,
        ...data,
      };
      
    } catch (e) {
      print('❌ Error fetching match details from Firestore: $e');
      return null;
    }
  }

  /// Update match in Firestore (not API)
  static Future<bool> updateMatch(String matchId, Map<String, dynamic> updates) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('❌ No authenticated user for Firestore request');
        return false;
      }

      // Update directly in Firestore instead of API
      await _firestore.collection('matches').doc(matchId).update({
        ...updates,
        'synced_at': FieldValue.serverTimestamp(),
      });
      
      print('✅ Successfully updated match in Firestore: $matchId');
      return true;
      
    } catch (e) {
      print('❌ Error updating match in Firestore: $e');
      return false;
    }
  }
} 