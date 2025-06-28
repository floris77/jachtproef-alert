import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _requestNotificationPermissions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _requestNotificationPermissions() async {
    await NotificationService.requestPermissions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('JachtProef Alert'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Alerts', icon: Icon(Icons.notifications)),
            Tab(text: 'Proeven', icon: Icon(Icons.calendar_today)),
          ],
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          AlertsTab(),
          ExamScheduleTab(),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final authService = context.read<AuthService>();
    await authService.signOut();
  }

  Future<void> _testNotification() async {
    await NotificationService.showExamAlert(
      message: 'Test notificatie van Jachtproef Alert',
      location: 'Test Locatie',
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test notificatie verzonden!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}

class AlertsTab extends StatelessWidget {
  const AlertsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recente Alerts',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          Expanded(
            child: ListView(
              children: [
                _buildAlertCard(
                                  'Nieuwe Jachtproef - Inschrijven Mogelijk',
                'Er is een nieuwe jachtproef waar je voor kunt inschrijven in Amsterdam op 15 juni 2024.',
                  Icons.new_releases,
                  Colors.green,
                  '2 uur geleden',
                ),
                _buildAlertCard(
                  'Locatie Wijziging',
                  'De jachtproef van 20 juni in Rotterdam is verplaatst naar een nieuwe locatie.',
                  Icons.location_on,
                  Colors.orange,
                  '1 dag geleden',
                ),
                _buildAlertCard(
                  'Herinnering',
                  'Je hebt je ingeschreven voor de jachtproef van morgen in Utrecht.',
                  Icons.access_time,
                  Colors.blue,
                  '3 dagen geleden',
                ),
                _buildAlertCard(
                  'Annulering',
                  'De jachtproef van 25 juni in Den Haag is geannuleerd wegens slecht weer.',
                  Icons.cancel,
                  Colors.red,
                  '1 week geleden',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(String title, String description, IconData icon, Color color, String time) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}

class ExamScheduleTab extends StatelessWidget {
  const ExamScheduleTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Komende Jachtproeven',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          Expanded(
            child: ListView(
              children: [
                _buildExamCard(
                  'Amsterdam',
                  DateTime.now().add(const Duration(days: 7)),
                  'Bos en Lommerplantsoen',
                  '25 beschikbare plaatsen',
                  true,
                ),
                _buildExamCard(
                  'Rotterdam',
                  DateTime.now().add(const Duration(days: 14)),
                  'Kralingse Bos',
                  '18 beschikbare plaatsen',
                  false,
                ),
                _buildExamCard(
                  'Utrecht',
                  DateTime.now().add(const Duration(days: 21)),
                  'Amelisweerd',
                  '30 beschikbare plaatsen',
                  false,
                ),
                _buildExamCard(
                  'Den Haag',
                  DateTime.now().add(const Duration(days: 28)),
                  'Haagse Bos',
                  '12 beschikbare plaatsen',
                  false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamCard(String city, DateTime date, String location, String availability, bool isRegistered) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  city,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isRegistered)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                        'Ingeschreven',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  '${date.day}/${date.month}/${date.year}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  location,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.people, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  availability,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            if (!isRegistered)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Handle registration
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Inschrijven'),
                ),
              ),
          ],
        ),
      ),
    );
  }
} 