import 'package:share_plus/share_plus.dart';
import 'package:jachtproef_alert/services/points_service.dart';
import 'package:jachtproef_alert/services/analytics_service.dart';
import 'package:jachtproef_alert/services/match_service.dart';
import 'package:flutter/material.dart';

class MatchDetailsPage extends StatefulWidget {
  final Map<String, dynamic> match;

  const MatchDetailsPage({required this.match, Key? key}) : super(key: key);

  @override
  _MatchDetailsPageState createState() => _MatchDetailsPageState();
}

class _MatchDetailsPageState extends State<MatchDetailsPage> {
  bool isLoading = false;
  Map<String, dynamic>? matchDetails;

  @override
  void initState() {
    super.initState();
    _loadMatchDetails();
  }

  Future<void> _loadMatchDetails() async {
    if (widget.match['id'] == null) return;
    
    setState(() => isLoading = true);
    try {
      final details = await MatchService.getMatchDetails(widget.match['id']);
      if (details != null) {
        setState(() {
          matchDetails = details;
        });
      }
    } catch (e) {
      print('❌ Error loading match details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fout bij laden proef details: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final match = matchDetails ?? widget.match;
    
    return isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Organizer
                  Text(
                    match['organizer'] ?? 'Onbekend',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  SizedBox(height: 8),
                  
                  // Type
                  if (match['type'] != null)
                    Chip(
                      label: Text(match['type']),
                      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                    ),
                  SizedBox(height: 16),
                  
                  // Location
                  ListTile(
                    leading: Icon(Icons.location_on),
                    title: Text('Locatie'),
                    subtitle: Text(match['location'] ?? 'Onbekend'),
                  ),
                  
                  // Date
                  ListTile(
                    leading: Icon(Icons.calendar_today),
                    title: Text('Datum'),
                    subtitle: Text(match['date'] ?? 'Onbekend'),
                  ),
                  
                  // Registration status
                  if (match['registration']?['text'] != null)
                    ListTile(
                      leading: Icon(Icons.how_to_reg),
                      title: Text('Inschrijving'),
                      subtitle: Text(match['registration']['text']),
                    ),
                  
                  // Additional details
                  if (match['remark'] != null) ...[
                    SizedBox(height: 16),
                    Text(
                      'Opmerkingen',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: 8),
                    Text(match['remark']),
                  ],
                ],
              ),
            );
  }

  void _shareMatch() async {
    try {
      final match = matchDetails ?? widget.match;
      final shareText = 'Bekijk deze ${match['type']} op JachtProef Alert: ${match['title'] ?? match['organizer']}';
      
      await Share.share(shareText);
      
      // Award points for sharing
      if (match['id'] != null) {
        await PointsService.awardSharingPoints(match['id']);
      }
      
      // Track share action
      AnalyticsService.logUserAction('match_share', parameters: {
        'match_id': match['id'],
        'match_type': match['type'],
      });
    } catch (e) {
      print('Error sharing match: $e');
    }
  }
} 