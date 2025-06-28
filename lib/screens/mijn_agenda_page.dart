import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MijnAgendaPage extends StatefulWidget {
  final bool fromDemo;
  const MijnAgendaPage({Key? key, this.fromDemo = false}) : super(key: key);

  @override
  State<MijnAgendaPage> createState() => _MijnAgendaPageState();
}

class _MijnAgendaPageState extends State<MijnAgendaPage> {
  @override
  Widget build(BuildContext context) {
    // Placeholder UI
    return Scaffold(
      appBar: AppBar(
        title: Text('Mijn Agenda'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 80, color: Colors.grey[300]),
            SizedBox(height: 16),
            Text(
              'Agenda is leeg',
              style: TextStyle(fontSize: 22, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Proeven die je hebt opgeslagen verschijnen hier.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to add to recently viewed (statically accessible)
  static Future<void> addRecentlyViewed(Map<String, dynamic> match) async {
    try {
      // Using a static method without context is tricky.
      // This assumes we can get the user from FirebaseAuth.
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final matchKey = '${match['organizer'] ?? match['raw']?['organizer'] ?? ''}_${match['date'] ?? match['raw']?['date'] ?? ''}';
      
      await FirebaseFirestore.instance
          .collection('user_activity')
          .doc(user.uid)
          .collection('recently_viewed')
          .doc(matchKey)
          .set({
            'matchData': match,
            'timestamp': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      print('Error adding recently viewed: $e');
    }
  }
} 