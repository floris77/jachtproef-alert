import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:share_plus/share_plus.dart';
import '../services/auth_service.dart';
import '../services/enrollment_confirmation_service.dart';
import '../services/permission_service.dart';
import '../services/calendar_service.dart';

import '../services/notification_service.dart';
import '../utils/constants.dart';
import '../utils/responsive_helper.dart';
import '../utils/responsive_dialogs.dart';
import '../utils/help_system.dart';

class MatchDetailsPage extends StatelessWidget {
  final Map<String, dynamic> match;
  
  const MatchDetailsPage({required this.match, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _MatchDetailsPageContent(match: match);
  }
}

class _MatchDetailsPageContent extends StatefulWidget {
  final Map<String, dynamic> match;
  const _MatchDetailsPageContent({required this.match, Key? key}) : super(key: key);
  @override
  State<_MatchDetailsPageContent> createState() => _MatchDetailsPageContentState();
}

class _MatchDetailsPageContentState extends State<_MatchDetailsPageContent> with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? matchDetails;

  late String matchKey;
  String userNote = '';
  TextEditingController? _noteController;
  Timer? _debounceTimer;
  List<bool> userNotificationTimes = [true, true, true, true, true]; // Default all enabled
  
  // Action state variables
  bool notificationsOn = false;
  bool inAgenda = false;
  bool isEnrolled = false;
  bool isSavingEnrollment = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    CalendarService.initialize();
    _loadActionStates();
    _noteController = TextEditingController();
    _noteController?.addListener(_onNoteChanged);
    _loadUserNotificationPreferences();
  }

  @override
  void dispose() {
    _noteController?.removeListener(_onNoteChanged);
    _noteController?.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onNoteChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _saveNoteForMatch(auto: true);
    });
  }

  Future<void> _loadActionStates() async {
    final key = EnrollmentConfirmationService.generateMatchKey(widget.match);
    final enrolled = await EnrollmentConfirmationService.isEnrollmentConfirmed(key);
    final note = await _loadNoteForMatch(key);
    // Try to load previous actions from Firebase
    bool notifications = false;
    bool agenda = false;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final firebaseMatchKey = _getFirebaseMatchKey();
        final doc = await FirebaseFirestore.instance
            .collection('user_actions')
            .doc(user.uid)
            .collection('match_actions')
            .doc(firebaseMatchKey)
            .get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          notifications = data['notificationsOn'] ?? false;
          agenda = data['inAgenda'] ?? false;
        }
      }
    } catch (e) {
      print('⚠️ Error loading match action states from Firebase: $e');
    }
    setState(() {
      matchKey = key;
      notificationsOn = notifications;
      inAgenda = agenda;
      isEnrolled = enrolled;
      userNote = note;
      _noteController?.text = note;
    });
  }

  Future<String> _loadNoteForMatch(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('note_$key') ?? '';
  }

  Future<void> _saveNoteForMatch({bool auto = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('note_$matchKey', _noteController?.text ?? '');
    setState(() {
      userNote = _noteController?.text ?? '';
    });
    
    // Save note activity to Firebase (only for non-auto saves)
    if (!auto) {
      await _saveToFirebaseMatchActions(
        isRegistered: isEnrolled,
        notificationsOn: notificationsOn,
        inAgenda: inAgenda,
        hasNotes: userNote.isNotEmpty,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Notitie opgeslagen!'), backgroundColor: Colors.green),
      );
    }
  }



  Future<void> _saveToFirebaseMatchActions({
    required bool isRegistered,
    bool? notificationsOn,
    bool? inAgenda,
    bool? hasNotes,
    bool? shared,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No user logged in, cannot save to Firebase');
        return;
      }
      
      final firebaseMatchKey = _getFirebaseMatchKey();
      final currentData = await FirebaseFirestore.instance
          .collection('user_actions')
          .doc(user.uid)
          .collection('match_actions')
          .doc(firebaseMatchKey)
          .get();
      
      Map<String, dynamic> updateData = {
        'isRegistered': isRegistered,
        'matchData': widget.match,
        'lastUpdated': FieldValue.serverTimestamp(),
      };
      
      // Only update specific fields if provided, otherwise keep existing values
      if (notificationsOn != null) updateData['notificationsOn'] = notificationsOn;
      if (inAgenda != null) updateData['inAgenda'] = inAgenda;
      if (hasNotes != null) updateData['hasNotes'] = hasNotes;
      if (shared == true) updateData['shared'] = true;
      
      // If this is a new entry, add timestamp
      if (!currentData.exists) {
        updateData['timestamp'] = FieldValue.serverTimestamp();
      }
      
      await FirebaseFirestore.instance
          .collection('user_actions')
          .doc(user.uid)
          .collection('match_actions')
          .doc(firebaseMatchKey)
          .set(updateData, SetOptions(merge: true));
          
      print('💾 Updated Firebase - match activity tracked');
    } catch (e) {
      print('❌ Error saving to Firebase: $e');
    }
  }

  String _getFirebaseMatchKey() {
    // Use the same key format as the main app
    final org = widget.match['organizer'] ?? widget.match['raw']?['organizer'] ?? '';
    final date = widget.match['date'] ?? widget.match['raw']?['date'] ?? '';
    return '${org}_$date';
  }

  Future<void> _toggleNotifications() async {
    // Optimistic update - update UI immediately
    final newState = !notificationsOn;
    setState(() => notificationsOn = newState);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(newState ? 'Meldingen ingeschakeld!' : 'Meldingen uitgeschakeld!'),
        backgroundColor: newState ? Colors.green : Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
    
    // Handle background work asynchronously
    _handleNotificationsBackground(newState);
  }

  void _handleNotificationsBackground(bool enable) async {
    try {
      if (enable) {
        await NotificationService.requestPermissions().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception('Permission request timed out');
          },
        );
        
        final enrollmentDate = _getEnrollmentOpeningDate(widget.match);
        if (enrollmentDate != null) {
          int notificationId = matchKey.hashCode;
          int scheduledCount = 0;
          
            if (userNotificationTimes[0]) {
              await NotificationService.scheduleNotification(
                id: notificationId++,
                title: '⏰ Inschrijving Binnenkort Open!',
                body: 'Over 7 dagen opent de inschrijving voor deze jachtproef.',
              scheduledTime: _ensureDateTime(enrollmentDate.subtract(const Duration(days: 7))),
              ).timeout(const Duration(seconds: 5));
              scheduledCount++;
            }
            if (userNotificationTimes[1]) {
              await NotificationService.scheduleNotification(
                id: notificationId++,
                title: '⏰ Inschrijving Binnenkort Open!',
                body: 'Morgen opent de inschrijving voor deze jachtproef.',
              scheduledTime: _ensureDateTime(enrollmentDate.subtract(const Duration(days: 1))),
              ).timeout(const Duration(seconds: 5));
              scheduledCount++;
            }
            if (userNotificationTimes[2]) {
              await NotificationService.scheduleNotification(
                id: notificationId++,
                title: '⏰ Inschrijving Binnenkort Open!',
                body: 'Over 1 uur opent de inschrijving. Zorg dat je klaar bent!',
              scheduledTime: _ensureDateTime(enrollmentDate.subtract(const Duration(hours: 1))),
              ).timeout(const Duration(seconds: 5));
              scheduledCount++;
            }
            if (userNotificationTimes[3]) {
              await NotificationService.scheduleNotification(
                id: notificationId++,
                title: '🚨 Inschrijving Binnenkort Open!',
                body: 'Over 10 minuten opent de inschrijving. Zorg dat je klaar bent!',
              scheduledTime: _ensureDateTime(enrollmentDate.subtract(const Duration(minutes: 10))),
              ).timeout(const Duration(seconds: 5));
              scheduledCount++;
            }
            await NotificationService.scheduleNotification(
              id: notificationId++,
              title: '🚨 Inschrijving Open!',
              body: 'De inschrijving voor deze jachtproef is nu open. Schrijf je snel in!',
            scheduledTime: _ensureDateTime(enrollmentDate),
            ).timeout(const Duration(seconds: 5));
            scheduledCount++;
            if (userNotificationTimes[4]) {
              await NotificationService.scheduleNotification(
                id: notificationId++,
                title: '⏰ Inschrijving Herinnering',
                body: 'Vergeet niet je in te schrijven! De inschrijving is nu open.',
              scheduledTime: _ensureDateTime(enrollmentDate.add(const Duration(minutes: 15))),
              ).timeout(const Duration(seconds: 5));
              scheduledCount++;
            }
          
          // Update Firebase in background
          _saveToFirebaseMatchActions(
              isRegistered: isEnrolled,
              notificationsOn: true,
              inAgenda: inAgenda,
              hasNotes: userNote.isNotEmpty,
          ).catchError((e) {
            print('❌ Background Firebase update failed: $e');
          });
        } else {
          // Revert UI state if no enrollment date
          if (mounted) {
            setState(() => notificationsOn = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Geen inschrijvingsdatum beschikbaar voor deze proef.'), 
                backgroundColor: Colors.orange,
            ),
          );
          }
        }
      } else {
        // Disable notifications
          for (int i = 0; i < 10; i++) {
            await NotificationService.cancelNotification(matchKey.hashCode + i)
                .timeout(const Duration(seconds: 2));
          }
        
        // Update Firebase in background
        _saveToFirebaseMatchActions(
          isRegistered: isEnrolled,
          notificationsOn: false,
          inAgenda: inAgenda,
          hasNotes: userNote.isNotEmpty,
        ).catchError((e) {
          print('❌ Background Firebase update failed: $e');
        });
      }
    } catch (e) {
      print('❌ Error in background notifications: $e');
      // Revert UI state if background work fails
      if (mounted) {
        setState(() => notificationsOn = !enable);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fout bij meldingen: $e'), 
            backgroundColor: Colors.red,
        ),
      );
      }
    }
  }



  Future<void> _addToCalendar() async {
    // Use the new calendar service
    final result = await CalendarService.addMatchToCalendar(
      context: context,
      match: widget.match,
      onStateUpdate: (bool inAgenda) {
        setState(() => this.inAgenda = inAgenda);
      },
    );
    
    // Update Firebase to persist the state
    await _saveToFirebaseMatchActions(
      isRegistered: isEnrolled,
      notificationsOn: notificationsOn,
      inAgenda: result.success,
      hasNotes: userNote.isNotEmpty,
    );
    
    // Show appropriate user feedback
    CalendarService.showUserFeedback(context, result);
  }



  void _shareMatch() {
    final title = widget.match['title']?.toString() ?? 
                 widget.match['organizer']?.toString() ?? 
                 widget.match['raw']?['title']?.toString() ?? 
                 widget.match['raw']?['organizer']?.toString() ?? 'Jachtproef';
    final location = widget.match['location']?.toString() ?? 
                    widget.match['raw']?['location']?.toString() ?? 'Onbekend';
    final date = _formatDate(widget.match['date'] ?? widget.match['raw']?['date']);
    final type = widget.match['type']?.toString() ?? 'Jachtproef';
    
    final shareText = '''🎯 JachtProef Alert!

📍 $title
🏞️ $location
📅 $date
🏆 $type

Gedeeld via JachtProef Alert 📱''';

    Share.share(shareText, subject: 'JachtProef: $title');
    
    // Save sharing activity to Firebase
    _saveToFirebaseMatchActions(
      isRegistered: isEnrolled,
      notificationsOn: notificationsOn,
      inAgenda: inAgenda,
      hasNotes: userNote.isNotEmpty,
      shared: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isVerySmallScreen = screenWidth < 350;
    
    // Use local state variables for immediate UI updates
    // These are updated optimistically when buttons are tapped
    
    // Use the passed-in match data directly - no async loading needed
    final match = widget.match;
    final matchDate = _getMatchDate(match);
    final enrollmentDate = _getEnrollmentOpeningDate(match);
    final hasValidDate = matchDate != null;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proef Details'),
        backgroundColor: Colors.grey[50],
        elevation: 0,
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // Organizer (RichText)
                RichText(
                  text: TextSpan(
                    text: match['organizer']?.toString() ?? 'Onbekend',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                    ),
                  ),
                      ),
                      const SizedBox(height: 8),
                // Type (RichText)
                  if (match['type'] != null && match['type'].toString().trim().isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: kMainColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: kMainColor.withOpacity(0.3)),
                          ),
                    child: RichText(
                      text: TextSpan(
                        children: _breakWord(match['type'].toString(), kMainColor, 14, FontWeight.w600),
                            ),
                    ),
                        ),
                      const SizedBox(height: 16),
                  // Status section (if applicable)
                  if (match['registration']?['text'] != null || match['registration_text'] != null)
                    _buildStatusSection(match),
                // Location (RichText)
                      _buildInfoRow(
                  icon: Icons.location_on,
                        title: 'Locatie',
                        subtitle: match['location']?.toString() ?? 'Onbekend',
                  useRichText: true,
                  ),
                // Date (RichText)
                      _buildInfoRow(
                  icon: Icons.calendar_today,
                        title: 'Datum',
                        subtitle: _formatDate(match['date']),
                  useRichText: true,
                  ),
                // Registration status (RichText)
                  if (match['registration']?['text'] != null)
                        _buildInfoRow(
                    icon: Icons.person_add,
                    title: _breakWordString('Inschrijven'),
                    subtitle: _breakWordString(match['registration']['text'].toString()),
                    useRichText: true,
                    ),
                // Additional details (RichText)
                  if (match['remark'] != null) ...[
                        const SizedBox(height: 16),
                  RichText(
                    text: TextSpan(
                      children: _breakWord('Opmerkingen', Colors.black, 18, FontWeight.bold),
                    ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                      color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                    child: RichText(
                      text: TextSpan(
                        children: _breakWord(match['remark'].toString(), Colors.black87, 16, FontWeight.normal),
                            ),
                          ),
                        ),
                  ],
                      const SizedBox(height: 24),
                  // ACTION BUTTONS
                  _buildActionButtons(context, match, isEnrolled, notificationsOn, inAgenda, hasValidDate),
                      const SizedBox(height: 20),
                  // NOTIFICATION INFO CARD
                  if (notificationsOn) _buildNotificationInfoCard(match),
                      const SizedBox(height: 32),
                  _buildNotesSection(context),
                ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String subtitle,
    bool useRichText = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: kMainColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    text: title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                useRichText
                    ? RichText(
                        text: TextSpan(
                          text: subtitle,
                          style: const TextStyle(
                            fontSize: 15,
                            color: CupertinoColors.systemGrey,
                          ),
                        ),
                      )
                    : Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 15,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection(Map<String, dynamic> match) {
    String regText = match['registration']?['text']?.toString() ?? match['registration_text']?.toString() ?? match['raw']?['registration_text']?.toString() ?? '';
    regText = regText.trim().toLowerCase();
    IconData icon;
    Color color;
    String statusLabel;
    if (regText == 'inschrijven') {
      icon = CupertinoIcons.checkmark_circle;
      color = const Color(0xFF4CAF50);
      statusLabel = 'Inschrijven';
    } else if (regText.startsWith('vanaf ')) {
      icon = CupertinoIcons.clock;
      color = const Color(0xFFFF9800);
      statusLabel = 'Binnenkort';
    } else if (regText == 'niet mogelijk' || regText == 'niet meer mogelijk') {
      icon = CupertinoIcons.xmark_circle;
      color = const Color(0xFFF44336);
      statusLabel = 'Gesloten';
    } else {
      icon = CupertinoIcons.question_circle;
      color = Colors.grey;
      statusLabel = 'Onbekend';
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
          children: [
            Icon(icon, color: color, size: 24),
          const SizedBox(width: 8),
          Text(
            statusLabel,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
        ),
          ),
            ],
          ),
    );
  }

  Widget _buildActionButtons(BuildContext context, Map<String, dynamic> match, bool isEnrolled, bool notificationsOn, bool inAgenda, bool hasValidDate) {
    final enrollmentDate = _getEnrollmentOpeningDate(match);
    final now = DateTime.now();
    final canEnableNotifications = enrollmentDate != null && enrollmentDate.isAfter(now);
    final matchDate = _getMatchDate(match);
    final canAddToAgenda = matchDate != null;
    // Get registration text for notification enabling
    String regText = match['registration']?['text']?.toString() ?? match['registration_text']?.toString() ?? match['raw']?['registration_text']?.toString() ?? '';
    // Determine registration status
    regText = regText.trim().toLowerCase();
    // Only disable for 'Binnenkort' (not yet open)
    final canEnroll = !regText.startsWith('vanaf ');

    return Column(
      children: [
        AbsorbPointer(
          absorbing: !canEnroll || isSavingEnrollment,
          child: Opacity(
            opacity: canEnroll ? 1.0 : 0.5,
            child: _buildCupertinoActionButton(
          icon: isEnrolled ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
              label: isSavingEnrollment
                  ? 'Bezig met opslaan...'
                  : 'Inschrijven',
          color: isEnrolled ? kMainColor : Colors.black,
          filled: isEnrolled,
              onTap: canEnroll && !isSavingEnrollment
                  ? () {
                      _handleEnrollmentTap();
                  }
                  : null,
                ),
          ),
        ),
        const SizedBox(height: 12),
        AbsorbPointer(
          absorbing: !canEnableNotifications,
          child: Opacity(
            opacity: canEnableNotifications ? 1.0 : 0.5,
            child: _buildCupertinoActionButton(
              icon: notificationsOn ? CupertinoIcons.bell_fill : CupertinoIcons.bell,
          label: notificationsOn ? 'Meldingen aan' : 'Meldingen uit',
          color: notificationsOn ? Colors.orange : Colors.black,
          filled: notificationsOn,
              onTap: canEnableNotifications
                  ? _toggleNotifications
                  : () => _showFeatureUnavailableDialog(
                      context,
                      'Meldingen niet beschikbaar',
                      'Meldingen zijn alleen beschikbaar voor proeven waarvan de inschrijvingsdatum nog niet is verstreken.'
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        AbsorbPointer(
          absorbing: !canAddToAgenda,
          child: Opacity(
            opacity: canAddToAgenda ? 1.0 : 0.5,
            child: GestureDetector(
              onLongPress: canAddToAgenda ? () => _showCalendarStatusDialog() : null,
            child: _buildCupertinoActionButton(
                icon: inAgenda ? CupertinoIcons.checkmark_circle : CupertinoIcons.calendar_badge_plus,
                label: inAgenda ? 'In agenda' : 'Toevoegen aan agenda',
              color: inAgenda ? Colors.blue : Colors.black,
              filled: inAgenda,
              onTap: canAddToAgenda
                  ? _addToCalendar
                  : () => _showFeatureUnavailableDialog(
                      context,
                      'Agenda niet beschikbaar',
                      'De datum voor deze proef is onbekend of ongeldig. Daarom kan deze niet aan je agenda worden toegevoegd.'
                  ),
            ),
          ),
        ),
        ),
        const SizedBox(height: 12),
        _buildCupertinoActionButton(
          icon: CupertinoIcons.square_arrow_up,
          label: 'Delen',
          color: Colors.black,
          filled: false,
          onTap: () {
            _shareMatch();
          },
        ),
      ],
    );
  }

  void _showFeatureUnavailableDialog(BuildContext context, String title, String message) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          content: Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: Text(
              message,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showCalendarStatusDialog() {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text(
            'Agenda Status',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          content: Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: Text(
              inAgenda 
                ? 'Deze proef is gemarkeerd als "in agenda". Als de proef niet in je agenda app staat, kun je de status hier aanpassen.'
                : 'Deze proef is niet gemarkeerd als "in agenda". Als de proef wel in je agenda app staat, kun je de status hier aanpassen.',
              style: const TextStyle(fontSize: 14),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              child: Text(inAgenda ? 'Verwijderen uit agenda' : 'Toevoegen aan agenda'),
              onPressed: () {
                Navigator.of(context).pop();
                _toggleCalendarStatus();
              },
            ),
            CupertinoDialogAction(
              child: const Text('Annuleren'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _toggleCalendarStatus() async {
    final newStatus = !inAgenda;
    
    if (newStatus) {
      // Use the new calendar service for adding
      final result = await CalendarService.addMatchToCalendar(
        context: context,
        match: widget.match,
        onStateUpdate: (bool inAgenda) {
          setState(() => this.inAgenda = inAgenda);
        },
      );
      
      // Update Firebase
      await _saveToFirebaseMatchActions(
        isRegistered: isEnrolled,
        notificationsOn: notificationsOn,
        inAgenda: result.success,
        hasNotes: userNote.isNotEmpty,
      );
      
      // Show appropriate feedback
      CalendarService.showUserFeedback(context, result);
    } else {
      // Just remove from agenda (no calendar events to remove)
      setState(() => inAgenda = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verwijderd uit agenda!'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
      
      // Update Firebase
      await _saveToFirebaseMatchActions(
        isRegistered: isEnrolled,
        notificationsOn: notificationsOn,
        inAgenda: false,
        hasNotes: userNote.isNotEmpty,
      );
    }
  }

  Widget _buildCupertinoActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool filled,
    required VoidCallback? onTap,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: filled ? color.withOpacity(0.1) : CupertinoColors.systemGrey6,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: filled ? color : CupertinoColors.systemGrey4,
            width: filled ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationInfoCard(Map<String, dynamic> match) {
    final enrollmentDate = _getEnrollmentOpeningDate(match);
    final List<Map<String, String>> notifications = [];
    
    if (enrollmentDate != null) {
      // Show only enabled notification times for enrollment
      if (userNotificationTimes[0]) {
        notifications.add({
          'label': '7 dagen voor inschrijving', 
          'date': DateFormat('d MMM yyyy HH:mm', 'nl_NL').format(enrollmentDate.subtract(const Duration(days: 7))),
          'priority': 'normal'
        });
      }
      if (userNotificationTimes[1]) {
        notifications.add({
          'label': '1 dag voor inschrijving', 
          'date': DateFormat('d MMM yyyy HH:mm', 'nl_NL').format(enrollmentDate.subtract(const Duration(days: 1))),
          'priority': 'normal'
        });
      }
      if (userNotificationTimes[2]) {
        notifications.add({
          'label': '1 uur voor inschrijving', 
          'date': DateFormat('d MMM yyyy HH:mm', 'nl_NL').format(enrollmentDate.subtract(const Duration(hours: 1))),
          'priority': 'high'
        });
      }
      if (userNotificationTimes[3]) {
        notifications.add({
          'label': '10 min voor inschrijving', 
          'date': DateFormat('d MMM yyyy HH:mm', 'nl_NL').format(enrollmentDate.subtract(const Duration(minutes: 10))),
          'priority': 'critical'
        });
      }
      // Always show the enrollment opening notification
      notifications.add({
        'label': '🚨 Bij openen inschrijving', 
        'date': DateFormat('d MMM yyyy HH:mm', 'nl_NL').format(enrollmentDate),
        'priority': 'critical'
      });
      if (userNotificationTimes[4]) {
        notifications.add({
          'label': '15 min na openen', 
          'date': DateFormat('d MMM yyyy HH:mm', 'nl_NL').format(enrollmentDate.add(const Duration(minutes: 15))),
          'priority': 'high'
        });
      }
    }
    
    if (notifications.isEmpty) {
      return Container(); // Don't show the card if no notifications are enabled
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CupertinoColors.systemGrey4),
      ),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          const Text(
            'Je ontvangt meldingen op:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          ...notifications.map((n) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
          children: [
            Icon(
                  n['priority'] == 'critical' ? CupertinoIcons.exclamationmark_triangle : 
                  n['priority'] == 'high' ? CupertinoIcons.clock : CupertinoIcons.bell, 
              color: n['priority'] == 'critical' ? Colors.red : 
                     n['priority'] == 'high' ? Colors.orange : Colors.grey, 
              size: 18
            ),
                const SizedBox(width: 6),
            Text(
              '${n['label']}: ', 
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: n['priority'] == 'critical' ? Colors.red : 
                       n['priority'] == 'high' ? Colors.orange : Colors.black87
              )
            ),
                Text(n['date'] ?? '', style: const TextStyle(color: Colors.black87)),
          ],
            ),
        )),
        if (enrollmentDate != null) ...[
            const SizedBox(height: 8),
          Container(
              padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
              child: const Text(
              '⚠️ Belangrijk: Inschrijvingen kunnen binnen minuten vol zijn!',
              style: TextStyle(
                fontSize: 12,
                  color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        ],
      ),
    );
  }

  Widget _buildNotesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Notities',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey6,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CupertinoColors.systemGrey4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: CupertinoTextField(
            controller: _noteController,
            minLines: 4,
            maxLines: 8,
            placeholder: 'Voeg hier je persoonlijke notities toe...',
            decoration: null,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
          ),
        ),
      ],
    );
  }

  String _formatDate(dynamic dateRaw) {
    if (dateRaw == null) return 'Onbekend';
    if (dateRaw is Timestamp) {
      final dt = dateRaw.toDate();
      return DateFormat('d MMMM yyyy', 'nl_NL').format(dt);
    }
    if (dateRaw is DateTime) {
      return DateFormat('d MMMM yyyy', 'nl_NL').format(dateRaw);
    }
    if (dateRaw is String) {
      // Try to parse as DateTime
      try {
        final dt = DateTime.parse(dateRaw);
        return DateFormat('d MMMM yyyy', 'nl_NL').format(dt);
      } catch (_) {
        return dateRaw;
      }
    }
    return dateRaw.toString();
  }

  DateTime? _parseDate(dynamic dateRaw) {
    if (dateRaw == null) return null;
    if (dateRaw is DateTime) return dateRaw;
    if (dateRaw is String) {
      try {
        return DateTime.parse(dateRaw);
      } catch (_) {
        // Try dd-MM-yyyy
        try {
          return DateFormat('dd-MM-yyyy').parse(dateRaw);
        } catch (_) {}
      }
    }
    // Handle Firestore Timestamp - convert to local timezone
    if (dateRaw is Timestamp) {
      final utcDate = dateRaw.toDate();
      // Convert UTC to local timezone (Netherlands is UTC+1 or UTC+2)
      final localDate = utcDate.toLocal();
      return localDate;
    }
    return null;
  }

  DateTime? _getMatchDate(Map<String, dynamic> match) {
    final rawDate = match['date'] ?? match['raw']?['date'];
    // Debug output for date parsing
    // ignore: avoid_print

    return _parseDate(rawDate);
  }

  DateTime? _getEnrollmentOpeningDate(Map<String, dynamic> match) {
    String regText = match['registration']?['text']?.toString() ?? match['registration_text']?.toString() ?? match['raw']?['registration_text']?.toString() ?? '';
    regText = regText.trim().toLowerCase();
    if (regText.startsWith('vanaf ')) {
      try {
        final dateTimeStr = regText.substring(6).trim(); // Remove 'vanaf ' and trim
        final parts = dateTimeStr.split(RegExp(r'\s+'));
        if (parts.length >= 1) {
          final datePart = parts[0]; // DD-MM-YYYY
          String timePart = '00:00'; // Default to midnight
          if (parts.length >= 2) {
            timePart = parts[1]; // HH:MM
          }
          final dateComponents = datePart.split('-');
          final timeComponents = timePart.split(':');
          if (dateComponents.length == 3 && timeComponents.length == 2) {
            return DateTime(
              int.parse(dateComponents[2]),
              int.parse(dateComponents[1]),
              int.parse(dateComponents[0]),
              int.parse(timeComponents[0]),
              int.parse(timeComponents[1]),
            );
          }
        }
      } catch (e) {
  
      }
    }
    return null;
  }

  Future<void> _loadUserNotificationPreferences() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Try to load from Firestore first
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (userDoc.exists && userDoc.data() != null) {
          final data = userDoc.data()!;
          final timings = data['notificationTimes'] as List<dynamic>?;
          if (timings != null && timings.length >= 5) {
            setState(() {
              userNotificationTimes = timings.cast<bool>();
            });
            return;
          }
        }
      }
      
      // Fallback to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userKey = user?.uid ?? 'anonymous';
      final savedTimes = prefs.getString('notification_times_$userKey');
      
      if (savedTimes != null) {
        final indices = savedTimes.split(',').map((e) => int.tryParse(e)).where((e) => e != null).cast<int>().toList();
        final times = List<bool>.filled(5, false);
        for (int i = 0; i < 5; i++) {
          times[i] = indices.contains(i);
        }
        setState(() {
          userNotificationTimes = times;
        });
      }
    } catch (e) {
      print('❌ Error loading notification preferences: $e');
    }
  }

  // Helper to break up words to prevent iOS data detectors
  List<TextSpan> _breakWord(String word, Color color, double fontSize, FontWeight fontWeight) {
    // Insert a zero-width space between every character
    final chars = word.split('');
    return [
      TextSpan(
        text: chars.join('\u200B'),
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
        ),
      ),
    ];
  }
  String _breakWordString(String word) {
    // Insert a zero-width space between every character
    return word.split('').join('\u200B');
  }

  Future<void> _handleEnrollmentTap() async {
    setState(() => isSavingEnrollment = true);
    try {
      if (!isEnrolled) {
        await _handleEnrollmentBackground(true, optimistic: false);
      } else {
        await _handleEnrollmentBackground(false, optimistic: false);
      }
    } finally {
      if (mounted) setState(() => isSavingEnrollment = false);
    }
  }

  Future<void> _handleEnrollmentBackground(bool enroll, {bool optimistic = true}) async {
    try {
      if (enroll) {
        if (optimistic) setState(() => isEnrolled = true);
        await EnrollmentConfirmationService.saveEnrollmentConfirmation(
          matchKey,
          matchTitle: widget.match['title'] ?? widget.match['organizer'],
          matchLocation: widget.match['location'],
        );
        await _saveToFirebaseMatchActions(isRegistered: true);
        if (!optimistic && mounted) {
          setState(() => isEnrolled = true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Inschrijving opgeslagen!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (optimistic) setState(() => isEnrolled = false);
        await EnrollmentConfirmationService.removeEnrollmentConfirmation(matchKey);
        await _saveToFirebaseMatchActions(isRegistered: false);
        if (!optimistic && mounted) {
          setState(() => isEnrolled = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Inschrijving verwijderd!'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fout bij opslaan: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Helper to ensure scheduledTime is always a DateTime
  DateTime _ensureDateTime(dynamic dt) {
    if (dt is DateTime) return dt;
    throw ArgumentError('scheduledTime must be a DateTime');
  }
} 