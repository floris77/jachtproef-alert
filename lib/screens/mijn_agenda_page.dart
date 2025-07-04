import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/enrollment_confirmation_service.dart';
import 'match_details_page.dart';
import '../utils/empty_state_widget.dart';
import 'package:flutter/cupertino.dart';

const Color kShareStatusColor = Color(0xFF1DE9B6);

class MijnAgendaPage extends StatefulWidget {
  final bool fromDemo;
  const MijnAgendaPage({Key? key, this.fromDemo = false}) : super(key: key);

  @override
  State<MijnAgendaPage> createState() => _MijnAgendaPageState();
}

class _MijnAgendaPageState extends State<MijnAgendaPage> {
  List<Map<String, dynamic>> enrolledMatches = [];
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    if (!widget.fromDemo) {
      _loadEnrolledMatches();
    }
  }

  Future<void> _loadEnrolledMatches() async {
    if (!mounted) return;
    
    setState(() {
      isLoading = true;
      hasError = false;
    });

    try {
      final user = context.read<AuthService>().currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() {
          isLoading = false;
          hasError = true;
          errorMessage = 'Je bent niet ingelogd';
        });
        return;
      }

      // Load enrolled matches from Firebase
      final firebaseMatches = await _loadFirebaseEnrolledMatches(user.uid);
      
      // Load enrolled matches from SharedPreferences (local storage)
      final localMatches = await _loadLocalEnrolledMatches();
      
      // Combine and deduplicate matches
      final allMatches = <Map<String, dynamic>>[];
      final seenKeys = <String>{};
      
      // Add Firebase matches first
      for (final match in firebaseMatches) {
        final key = _generateMatchKey(match);
        if (!seenKeys.contains(key)) {
          allMatches.add(match);
          seenKeys.add(key);
        }
      }
      
      // Add local matches that aren't already included
      for (final match in localMatches) {
        final key = _generateMatchKey(match);
        if (!seenKeys.contains(key)) {
          allMatches.add(match);
          seenKeys.add(key);
        }
      }
      
      // Sort by date (earliest first)
      allMatches.sort((a, b) {
        final dateA = _parseDate(a['date'] ?? a['raw']?['date']);
        final dateB = _parseDate(b['date'] ?? b['raw']?['date']);
        if (dateA == null || dateB == null) return 0;
        return dateA.compareTo(dateB);
      });

      if (!mounted) return;
      setState(() {
        enrolledMatches = allMatches;
        isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading enrolled matches: $e');
      if (!mounted) return;
      setState(() {
        isLoading = false;
        hasError = true;
        errorMessage = 'Fout bij laden agenda: $e';
      });
    }
  }

  Future<List<Map<String, dynamic>>> _loadFirebaseEnrolledMatches(String userId) async {
    try {
      // Load ALL user interactions, not just enrollments
      final querySnapshot = await FirebaseFirestore.instance
          .collection('user_actions')
          .doc(userId)
          .collection('match_actions')
          .get();

      final matches = <Map<String, dynamic>>[];
      for (final doc in querySnapshot.docs) {
        try {
          final data = doc.data();
          if (data['matchData'] != null) {
            final matchData = Map<String, dynamic>.from(data['matchData']);
            
            // Add activity flags to the match data
            matchData['userActivities'] = {
              'isRegistered': data['isRegistered'] ?? false,
              'notificationsOn': data['notificationsOn'] ?? false,
              'inAgenda': data['inAgenda'] ?? false,
              'hasNotes': data['hasNotes'] ?? false,
              'shared': data['shared'] ?? false,
              'lastUpdated': data['lastUpdated'],
              'timestamp': data['timestamp'],
            };
            
            matches.add(matchData);
          }
        } catch (e) {
          print('❌ Error processing Firebase document: $e');
          // Continue with other documents
        }
      }
      return matches;
    } catch (e) {
      print('❌ Error loading Firebase enrolled matches: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadLocalEnrolledMatches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final enrolledKeys = keys.where((key) => key.startsWith('enrollment_confirmed_')).toList();
      
      final matches = <Map<String, dynamic>>[];
      for (final key in enrolledKeys) {
        // Extract match info from the key (format: enrollment_confirmed_title_location)
        final matchInfo = key.replaceFirst('enrollment_confirmed_', '');
        final parts = matchInfo.split('_');
        if (parts.length >= 2) {
          final title = parts[0];
          final location = parts[1];
          
          // Create a basic match object from the stored info
          matches.add({
            'title': title,
            'organizer': title,
            'location': location,
            'date': 'Datum onbekend',
            'type': 'Jachtproef',
            'isLocalMatch': true, // Flag to indicate this is from local storage
          });
        }
      }
      return matches;
    } catch (e) {
      print('❌ Error loading local enrolled matches: $e');
      return [];
    }
  }

  String _generateMatchKey(Map<String, dynamic> match) {
    // Use the same logic as EnrollmentConfirmationService to ensure consistency
    return EnrollmentConfirmationService.generateMatchKey(match);
  }

  DateTime? _parseDate(dynamic date) {
    if (date == null) return null;
    if (date is Timestamp) return date.toDate();
    if (date is DateTime) return date;
    if (date is String) {
      try {
        return DateTime.parse(date);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String _formatDate(dynamic date) {
    final parsedDate = _parseDate(date);
    if (parsedDate == null) return 'Datum onbekend';
    return DateFormat('dd MMM yyyy', 'nl_NL').format(parsedDate);
  }

  Future<void> _removeFromAgenda(Map<String, dynamic> match) async {
    try {
      final user = context.read<AuthService>().currentUser;
      if (user == null) return;

      final matchKey = _generateMatchKey(match);
      
      // Remove from Firebase
      await FirebaseFirestore.instance
          .collection('user_actions')
          .doc(user.uid)
          .collection('match_actions')
          .doc(matchKey)
          .delete();
      
      // Remove from local storage
      await EnrollmentConfirmationService.removeEnrollmentConfirmation(matchKey);
      
      // Refresh the list
      await _loadEnrolledMatches();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verwijderd uit agenda'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('❌ Error removing from agenda: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fout bij verwijderen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Mijn Agenda', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Icon(CupertinoIcons.refresh),
          onPressed: isLoading ? null : _loadEnrolledMatches,
          ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 0),
            Expanded(
              child: isLoading
                  ? Center(child: CupertinoActivityIndicator())
                  : hasError
                      ? Center(child: Text(errorMessage, style: TextStyle(color: CupertinoColors.systemRed)))
                      : enrolledMatches.isEmpty
                          ? EmptyStateWidget(
                              icon: CupertinoIcons.calendar,
                              title: 'Nog geen matches in je agenda',
                              description: 'Voeg proeven toe aan je agenda om ze hier te zien.',
                            )
                          : ListView.separated(
        itemCount: enrolledMatches.length,
                              separatorBuilder: (_, __) => Divider(height: 1, color: CupertinoColors.systemGrey4),
        itemBuilder: (context, index) {
            final match = enrolledMatches[index];
                                final activities = match['userActivities'] ?? {};
                                final isEnrolled = activities['isRegistered'] == true;
                                final notificationsOn = activities['notificationsOn'] == true;
                                final hasNote = activities['hasNotes'] == true;
                                final shared = activities['shared'] == true;
                                final inAgenda = activities['inAgenda'] == true;
                                final date = _parseDate(match['date'] ?? match['raw']?['date']);
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      CupertinoPageRoute(
                                        builder: (_) => MatchDetailsPage(match: match),
            ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                                                match['organizer']?.toString() ?? match['title']?.toString() ?? 'Onbekend',
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                              ),
                                            ),
                                            if (date != null)
                  Text(
                                                DateFormat('d MMM yyyy', 'nl_NL').format(date),
                                                style: TextStyle(fontSize: 15, color: CupertinoColors.systemGrey),
                  ),
                ],
              ),
                                        const SizedBox(height: 4),
                Row(
                  children: [
                                            if (isEnrolled) ...[
                                              Icon(CupertinoIcons.check_mark_circled_solid, color: CupertinoColors.activeGreen, size: 18),
                                              const SizedBox(width: 4),
                                              Text('Ingeschreven', style: TextStyle(color: CupertinoColors.activeGreen, fontSize: 13, fontWeight: FontWeight.w500)),
                                              const SizedBox(width: 10),
                                            ],
                                            if (notificationsOn) ...[
                                              Icon(CupertinoIcons.bell_solid, color: CupertinoColors.systemOrange, size: 18),
                                              const SizedBox(width: 4),
                                              Text('Meldingen', style: TextStyle(color: CupertinoColors.systemOrange, fontSize: 13, fontWeight: FontWeight.w500)),
                                              const SizedBox(width: 10),
                                            ],
                                            if (hasNote) ...[
                                              Icon(CupertinoIcons.doc_text_fill, color: CupertinoColors.systemPurple, size: 18),
                                              const SizedBox(width: 4),
                                              Text('Notitie', style: TextStyle(color: CupertinoColors.systemPurple, fontSize: 13, fontWeight: FontWeight.w500)),
                                              const SizedBox(width: 10),
                                            ],
                                            if (shared) ...[
                                              Icon(CupertinoIcons.share, color: kShareStatusColor, size: 18),
                                              const SizedBox(width: 4),
                                              Text('Gedeeld', style: TextStyle(color: kShareStatusColor, fontSize: 13, fontWeight: FontWeight.w500)),
                                              const SizedBox(width: 10),
                                            ],
                                            if (inAgenda) ...[
                                              Icon(CupertinoIcons.calendar, color: CupertinoColors.activeBlue, size: 18),
                                              const SizedBox(width: 4),
                                              Text('Agenda', style: TextStyle(color: CupertinoColors.activeBlue, fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ],
          ),
                  ],
                ),
              ),
            );
          },
        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDemoAgenda() {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mijn Agenda'),
        centerTitle: true,
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          _buildDemoAgendaItem(
            'Stichting Jachthonden Zuid-Holland',
            '15 Mrt 2025',
            'Rotterdam',
            true,
            false,
          ),
          _buildDemoAgendaItem(
            'KNJV Provincie Gelderland',
            '22 Mrt 2025',
            'Arnhem',
            false,
            true,
          ),
          _buildDemoAgendaItem(
            'Nederlandse Labrador Vereniging',
            '5 Apr 2025',
            'Amsterdam',
            true,
            true,
          ),
        ],
      ),
    );
  }

  Widget _buildDemoAgendaItem(String title, String date, String location, bool hasNotes, bool inAgenda) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
          child: Icon(
            Icons.calendar_today,
            color: Theme.of(context).primaryColor,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(location, style: TextStyle(color: Colors.grey[600])),
              ],
            ),
            SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(date, style: TextStyle(color: Colors.grey[600])),
              ],
            ),
            if (hasNotes) ...[
              SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.note, size: 16, color: Colors.blue[600]),
                  SizedBox(width: 4),
                  Text('Notitie toegevoegd', style: TextStyle(color: Colors.blue[600], fontSize: 12)),
                ],
              ),
            ],
            if (inAgenda) ...[
              SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.event, size: 16, color: Colors.green[600]),
                  SizedBox(width: 4),
                  Text('In agenda', style: TextStyle(color: Colors.green[600], fontSize: 12)),
                ],
              ),
            ],
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