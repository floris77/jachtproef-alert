import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MatchActionState {
  bool isEnrolled;
  bool inAgenda;
  bool notificationsOn;
  MatchActionState({this.isEnrolled = false, this.inAgenda = false, this.notificationsOn = false});
}

class MatchActionsProvider extends ChangeNotifier {
  final Map<String, MatchActionState> _actions = {};
  bool _initialized = false;

  MatchActionState getAction(String matchKey) => _actions[matchKey] ?? MatchActionState();

  Future<void> loadAllActions() async {
    if (_initialized) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('user_actions')
          .doc(user.uid)
          .collection('match_actions')
          .get();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        _actions[doc.id] = MatchActionState(
          isEnrolled: data['isRegistered'] ?? false,
          inAgenda: data['inAgenda'] ?? false,
          notificationsOn: data['notificationsOn'] ?? false,
        );
      }
      _initialized = true;
      notifyListeners();
    } catch (e) {
      print('❌ Error loading match actions: $e');
    }
  }

  Future<void> enroll(String matchKey, bool enrolled) async {
    _actions[matchKey] = getAction(matchKey)..isEnrolled = enrolled;
    notifyListeners();
    await _persist(matchKey);
  }

  Future<void> setInAgenda(String matchKey, bool inAgenda) async {
    _actions[matchKey] = getAction(matchKey)..inAgenda = inAgenda;
    notifyListeners();
    await _persist(matchKey);
  }

  Future<void> setNotificationsOn(String matchKey, bool notificationsOn) async {
    _actions[matchKey] = getAction(matchKey)..notificationsOn = notificationsOn;
    notifyListeners();
    await _persist(matchKey);
  }

  Future<void> _persist(String matchKey) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final state = getAction(matchKey);
    try {
      await FirebaseFirestore.instance
          .collection('user_actions')
          .doc(user.uid)
          .collection('match_actions')
          .doc(matchKey)
          .set({
        'isRegistered': state.isEnrolled,
        'inAgenda': state.inAgenda,
        'notificationsOn': state.notificationsOn,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('❌ Error persisting match action: $e');
    }
  }
} 