import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/analytics_service.dart';
import '../services/notification_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../utils/help_system.dart';
import '../utils/empty_state_widget.dart';
import '../utils/responsive_helper.dart';
import 'help_screen.dart';
import 'instellingen_page.dart';
import '../services/payment_service.dart';
import '../services/email_notification_service.dart';
import '../services/enrollment_confirmation_service.dart';
import '../widgets/debug_sharing_panel.dart';
import '../services/points_service.dart';
import 'match_details_page.dart';
import '../services/match_service.dart';
import 'mijn_agenda_page.dart';
import '../widgets/proef_card.dart';

const Color kMainColor = Color(0xFF535B22);

extension StringExtension on String {
  String capitalizeFirst() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

const List<String> matchTypes = [
  'Alle proeven', 'Favorieten', 'Veldwedstrijd', 'SJP', 'MAP', 'PJP', 'TAP', 'KAP', 'SWT', 'OWT'
];

// Notification setup
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> initializeNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  final DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings();
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

// Legacy function removed - now using NotificationService.scheduleNotification()

void addEventToCalendar(String title, String description, DateTime start, DateTime end) {
  final event = Event(
    title: title,
    description: description,
    location: '',
    startDate: start,
    endDate: end,
    allDay: false,
  );
  Add2Calendar.addEvent2Cal(event);
  
  // Track calendar add event
  AnalyticsService.logCalendarAdd(title); // Using title as exam ID
  AnalyticsService.logUserAction('calendar_add', parameters: {
    'exam_title': title,
    'exam_date': start.toIso8601String(),
  });
}

class ProevenMainPage extends StatefulWidget {
  final int initialIndex;
  const ProevenMainPage({Key? key, this.initialIndex = 0}) : super(key: key);

  @override
  State<ProevenMainPage> createState() => _ProevenMainPageState();
}

class _ProevenMainPageState extends State<ProevenMainPage> {
  late int _selectedIndex;
  String userName = '';
  String userEmail = '';

  List<Widget> get _pages {
    final isTourActive = HelpSystem.isTourActive;
    print('🎯 MAIN PAGE DEBUG: Creating pages, isTourActive = $isTourActive, selectedIndex = $_selectedIndex');
    
    // Demo mode should ONLY show during active tour, not based on recent activity
    final isAgendaInDemoMode = isTourActive;
    print('🎯 MAIN PAGE DEBUG: isAgendaInDemoMode = $isAgendaInDemoMode (isTourActive = $isTourActive)');
    
    return [
      const ProevenListPage(),
      MijnAgendaPage(fromDemo: isAgendaInDemoMode),
      // const LeaderboardWidget(), // Temporarily removed
      const InstellingenPage(),
    ];
  }

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    
    // Track app open and screen view
    AnalyticsService.logAppOpen();
    AnalyticsService.logScreenView('proeven_main_page');
  }

  void _loadUserData() async {
    try {
      final authService = context.read<AuthService>();
      final user = authService.currentUser;
      
      if (user == null) {
        if (!mounted) return;
        setState(() {
          userName = '';
          userEmail = '';
        });
        return;
      }
      
      // Get user data from Firestore instead of relying on displayName
      final userData = await authService.getUserData();
      if (!mounted) return;
      setState(() {
        // Use the name from Firestore, fallback to email prefix if not available
        userName = userData?['name'] ?? user.email?.split('@').first ?? '';
        userEmail = user.email ?? '';
      });
    } catch (e) {
      print('Error loading user data: $e');
      // Set defaults if there's an error
      final user = context.read<AuthService>().currentUser;
      if (!mounted) return;
      setState(() {
        // Fallback to email prefix if everything else fails
        userName = user?.email?.split('@').first ?? '';
        userEmail = user?.email ?? '';
      });
    }
  }

  Future<Map<String, dynamic>> _getSubscriptionStatus() async {
    try {
      final paymentService = PaymentService();
      final hasSubscription = await paymentService.hasActiveSubscription();
      final isInTrial = await paymentService.isInTrialPeriod();
      final trialDaysRemaining = await paymentService.getTrialDaysRemaining();
      
      return {
        'hasSubscription': hasSubscription,
        'isInTrial': isInTrial,
        'trialDaysRemaining': trialDaysRemaining,
      };
    } catch (e) {
      print('Error getting subscription status: $e');
      return {
        'hasSubscription': false,
        'isInTrial': false,
        'trialDaysRemaining': 0,
      };
    }
  }

  void _showFirstTimeHelp() async {
    // Show help tips for first-time users
    if (await HelpSystem.shouldShowProevenHelp()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        HelpSystem.showFeatureDiscovery(
          context,
          'Welkom bij Proeven!',
          'Hier vind je alle beschikbare jachtproeven. Gebruik de zoekbalk om te zoeken, de filter knop voor specifieke types, en de tabs om proeven te sorteren op status.',
          () async {
            await HelpSystem.markProevenHelpShown();
            // Show quick tour if first time (only if not already completed)
                          if (await HelpSystem.shouldShowQuickTour()) {
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted) {
                    HelpSystem.showSimpleTour(context);
                  }
                });
            } else {
            // Show help button popup after a short delay
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                _showHelpButtonPopupIfNeeded();
              }
            });
            }
          },
        );
      });
    } else {
      // If proeven help was already shown, check for help button popup
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showHelpButtonPopupIfNeeded();
      });
    }
  }

  void _showHelpButtonPopupIfNeeded() async {
    if (await HelpSystem.shouldShowHelpButtonPopup()) {
      if (!mounted) return;
      HelpSystem.showHelpButtonPopup(
        context,
        () {
          if (!mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const HelpScreen()),
          );
        },
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 375;
    final isLargeScreen = screenWidth > 414;
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: kMainColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Proeven',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Agenda',
          ),
          // BottomNavigationBarItem(
          //   icon: Icon(Icons.leaderboard),
          //   label: 'Ranking',
          // ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Instellingen',
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

class ProevenListPage extends StatefulWidget {
  const ProevenListPage({Key? key}) : super(key: key);

  @override
  State<ProevenListPage> createState() => _ProevenListPageState();
}

class _ProevenListPageState extends State<ProevenListPage> with TickerProviderStateMixin {
  Map<String, dynamic>? _selectedMatch;
  String searchQuery = '';
  List<String> selectedTypes = ['Alle proeven']; // Will be updated based on user preferences
  int selectedTab = 0;
  List<String> userFavoriteTypes = []; // Store user's favorite types from Quick Setup
  String userName = ''; // State variable for user name from Firestore
  late TabController _tabController; // Add TabController
  String selectedFilter = 'Alle proeven'; // For the dropdown filter
  
  // Enhanced scroll tracking for better UX
  bool _showHeader = true;
  double _hideHeaderScrollPosition = 0.0;
  static const double _scrollBufferDistance = 120.0; // About 1 match card height - more reasonable
  static const double _topThreshold = 150.0; // Show header when within 150px of top

  // Temporary fix: define match lists to resolve build errors
  List<Map<String, dynamic>> inschrijvenMatches = [];
  List<Map<String, dynamic>> binnenkortMatches = [];
  List<Map<String, dynamic>> geslotenMatches = [];
  // TODO: Implement actual fetching and categorization logic for matches

  @override
  void initState() {
    super.initState();
    _loadUserData(); // Load user data from Firestore
    _loadUserPreferences();
    _showFirstTimeHelp();
    _tabController = TabController(length: 4, vsync: this); // Updated to 4 tabs
  }

  void _loadUserData() async {
    try {
      final authService = context.read<AuthService>();
      final user = authService.currentUser;
      
      if (user == null) {
        if (!mounted) return;
        setState(() {
          userName = '';
        });
        return;
      }
      
      // Get user data from Firestore instead of relying on displayName
      final userData = await authService.getUserData();
      if (!mounted) return;
      setState(() {
        // Use the name from Firestore, fallback to email prefix if not available
        userName = userData?['name'] ?? user.email?.split('@').first ?? '';
      });
    } catch (e) {
      print('Error loading user data: $e');
      // Set defaults if there's an error
      final user = context.read<AuthService>().currentUser;
      if (!mounted) return;
      setState(() {
        // Fallback to email prefix if everything else fails
        userName = user?.email?.split('@').first ?? '';
      });
    }
  }
  
  /// Load user preferences from Quick Setup to enable "Favorieten" filter
  Future<void> _loadUserPreferences() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('🎯 No user logged in - using default filter');
        return;
      }
      
      // Check Firebase for user-specific preferences first
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      List<String> savedTypes = [];
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>?;
        final preferences = userData?['preferences'] as Map<String, dynamic>?;
        final selectedProefTypes = preferences?['selectedProefTypes'] as List<dynamic>?;
        
        if (selectedProefTypes != null) {
          savedTypes = selectedProefTypes.cast<String>();
          print('🎯 User preferences loaded from Firebase: $savedTypes');
        }
      }
      
      // Fallback to SharedPreferences only if Firebase data doesn't exist
      if (savedTypes.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final userId = user.uid;
        savedTypes = prefs.getStringList('selected_proef_types_$userId') ?? [];
        print('🎯 User preferences loaded from SharedPreferences: $savedTypes');
      }
      
      if (savedTypes.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          userFavoriteTypes = savedTypes;
          // Auto-select Favorieten if user has preferences
          selectedTypes = ['Favorieten'];
          selectedFilter = 'Favorieten';
        });
        print('🎯 Auto-selecting Favorieten filter for user ${user.email}');
      } else {
        if (!mounted) return;
        setState(() {
          userFavoriteTypes = [];
          selectedTypes = ['Alle proeven']; // Default for new users
          selectedFilter = 'Alle proeven';
        });
        print('🎯 New user ${user.email} - no preferences found, using default filter');
      }
    } catch (e) {
      print('🎯 Error loading user preferences: $e');
      // Fallback to default
      if (!mounted) return;
      setState(() {
        userFavoriteTypes = [];
        selectedTypes = ['Alle proeven'];
        selectedFilter = 'Alle proeven';
      });
    }
  }

  void _showFirstTimeHelp() async {
    // Check if tour should be shown from quick setup
    final prefs = await SharedPreferences.getInstance();
    final user = context.read<AuthService>().currentUser;
    final userId = user?.uid ?? 'anonymous';
    final shouldShowTourFromSetup = prefs.getBool('should_show_tour_on_main_$userId') ?? false;
    
    if (shouldShowTourFromSetup) {
      // Clear the preference and show tour immediately
      await prefs.remove('should_show_tour_on_main_$userId');
      // Also check if tour was already completed to prevent duplicate tours
      if (await HelpSystem.shouldShowQuickTour()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            HelpSystem.showSimpleTour(context);
          }
        });
      });
      }
      return;
    }
    
    // Show help tips for first-time users
    if (await HelpSystem.shouldShowProevenHelp()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        HelpSystem.showFeatureDiscovery(
          context,
          'Welkom bij Proeven!',
          'Hier vind je alle beschikbare jachtproeven. Gebruik de zoekbalk om te zoeken, de filter knop voor specifieke types, en de tabs om proeven te sorteren op status.',
          () async {
            await HelpSystem.markProevenHelpShown();
            // Show quick tour if first time (only if not already completed)
            if (await HelpSystem.shouldShowQuickTour()) {
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) {
                  HelpSystem.showSimpleTour(context);
                }
              });
            } else {
            // Show help button popup after a short delay
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                _showHelpButtonPopupIfNeeded();
              }
            });
            }
          },
        );
      });
    } else {
      // If proeven help was already shown, check for help button popup
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showHelpButtonPopupIfNeeded();
      });
    }
  }

  void _showHelpButtonPopupIfNeeded() async {
    if (await HelpSystem.shouldShowHelpButtonPopup()) {
      if (!mounted) return;
      HelpSystem.showHelpButtonPopup(
        context,
        () {
          if (!mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const HelpScreen()),
          );
        },
      );
    }
  }

  // Comparison functions at the top of the class
  int compareAsc(Map<String, dynamic> a, Map<String, dynamic> b) {
    final rawDateA = a['raw']?['date'] ?? a['date'];
    final rawDateB = b['raw']?['date'] ?? b['date'];
    
    DateTime? dateA;
    DateTime? dateB;
    
    if (rawDateA is Timestamp) {
      dateA = rawDateA.toDate();
    } else if (rawDateA is DateTime) {
      dateA = rawDateA;
    }
    
    if (rawDateB is Timestamp) {
      dateB = rawDateB.toDate();
    } else if (rawDateB is DateTime) {
      dateB = rawDateB;
    }
    
    if (dateA == null || dateB == null) return 0;
    return dateA.compareTo(dateB);
  }

  int compareDesc(Map<String, dynamic> a, Map<String, dynamic> b) {
    final rawDateA = a['raw']?['date'] ?? a['date'];
    final rawDateB = b['raw']?['date'] ?? b['date'];
    
    DateTime? dateA;
    DateTime? dateB;
    
    if (rawDateA is Timestamp) {
      dateA = rawDateA.toDate();
    } else if (rawDateA is DateTime) {
      dateA = rawDateA;
    }
    
    if (rawDateB is Timestamp) {
      dateB = rawDateB.toDate();
    } else if (rawDateB is DateTime) {
      dateB = rawDateB;
    }
    
    if (dateA == null || dateB == null) return 0;
    return dateB.compareTo(dateA);
  }

  List<Map<String, dynamic>> get alleMatches {
    inschrijvenMatches.sort(compareAsc);
    binnenkortMatches.sort(compareAsc);
    geslotenMatches.sort(compareDesc);
    return [
      ...inschrijvenMatches,
      ...binnenkortMatches,
      ...geslotenMatches,
    ];
  }

  void _onMatchTapped(Map<String, dynamic> match) {
    // Add to recently viewed
    // MijnAgendaPage.addRecentlyViewed(match); // Temporarily commented out
      
      setState(() {
      _selectedMatch = match;
      });
  }

  void _onBackFromDetails() {
      setState(() {
      _selectedMatch = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedMatch != null) {
      // SHOW DETAILS VIEW
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: kMainColor),
            onPressed: () => setState(() {
              _selectedMatch = null;
            }),
          ),
          title: Text(
            _selectedMatch!['title'] ?? 'Proef Details',
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        ),
        body: MatchDetailsPage(match: _selectedMatch!),
      );
    }

    // SHOW LIST VIEW (Modernized build method)
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 375;
    final isLargeScreen = screenWidth > 414;
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification notification) {
          if (notification is ScrollUpdateNotification) {
            // Updated scroll logic for hiding header
            if (notification.metrics.pixels > _hideHeaderScrollPosition + _scrollBufferDistance) {
              if (_showHeader) setState(() => _showHeader = false);
              _hideHeaderScrollPosition = notification.metrics.pixels;
            } else if (notification.metrics.pixels < _hideHeaderScrollPosition - _scrollBufferDistance || notification.metrics.pixels < _topThreshold) {
              if (!_showHeader) setState(() => _showHeader = true);
              _hideHeaderScrollPosition = notification.metrics.pixels;
            }
          }
          return false;
        },
        child: Column(
          children: [
            // Modern header with greeting
            if (_showHeader) Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              color: Colors.white,
              child: Row(
                children: [
                  Text(
                    'Hi, ${userName.isNotEmpty ? userName : 'there'} 👋',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 20 : 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF535B22),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.help_outline, color: Color(0xFF535B22)),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const HelpScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
            
            // Modern search and filter section
            Container(
              padding: const EdgeInsets.all(20),
              color: Colors.white,
              child: Column(
                children: [
                  // Search bar with modern styling
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Zoek proeven…',
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onChanged: (value) {
                        setState(() {
                          searchQuery = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Modern filter dropdown
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedFilter,
                        isExpanded: true,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        items: matchTypes.map((String type) {
                          return DropdownMenuItem<String>(
                            value: type,
                            child: Text(type),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              selectedFilter = newValue;
                              selectedTypes = [newValue];
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Modern tab bar with correct labels
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildModernTabButton('Alle', selectedTab == 0),
                  _buildModernTabButton('Inschrijven', selectedTab == 1),
                  _buildModernTabButton('Binnenkort', selectedTab == 2),
                  _buildModernTabButton('Gesloten', selectedTab == 3),
                ],
              ),
            ),
            
            // Result count display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: Colors.white,
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: MatchService.fetchMatches(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final matches = snapshot.data!;
                    final filteredMatches = _getFilteredMatches(matches);
                    return Text(
                      '${filteredMatches.length} resultaten',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  }
                  return Text(
                    '0 resultaten',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  );
                },
              ),
            ),
            
            // Content area with modern styling
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: MatchService.fetchMatches(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'Er is een probleem met het laden van proeven',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Controleer je internetverbinding en probeer het opnieuw',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {}); // Re-runs the future builder
                            },
                            child: const Text('Opnieuw proberen'),
                          ),
                        ],
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'Geen proeven gevonden',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Pas je zoekopdracht of filters aan, of probeer het later opnieuw',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {}); // Re-runs the future builder
                            },
                            child: const Text('Opnieuw proberen'),
                          ),
                        ],
                      ),
                    );
                  }

                  return _buildModernMatchList(snapshot);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build modern tab buttons
  Widget _buildModernTabButton(String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          switch (label) {
            case 'Alle':
              selectedTab = 0;
              break;
            case 'Inschrijven':
              selectedTab = 1;
              break;
            case 'Binnenkort':
              selectedTab = 2;
              break;
            case 'Gesloten':
              selectedTab = 3;
              break;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? const Color(0xFF535B22) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: isSelected ? const Color(0xFF535B22) : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  // Helper method to get filtered matches
  List<Map<String, dynamic>> _getFilteredMatches(List<Map<String, dynamic>> matches) {
    // Categorize matches
    List<Map<String, dynamic>> beschikbaar = [];
    List<Map<String, dynamic>> binnenkort = [];
    List<Map<String, dynamic>> gesloten = [];

    for (final match in matches) {
      final regText = (match['registration_text'] ?? match['raw']?['registration_text'] ?? '').toString().toLowerCase();
      
      if (regText == 'inschrijven') {
        beschikbaar.add(match);
      } else if (regText.startsWith('vanaf ')) {
        binnenkort.add(match);
      } else if (regText == 'niet mogelijk' || regText == 'niet meer mogelijk') {
        gesloten.add(match);
      } else {
        gesloten.add(match);
      }
    }

    // Get matches for selected tab
    List<Map<String, dynamic>> tabMatches;
    switch (selectedTab) {
      case 1:
        tabMatches = beschikbaar;
        break;
      case 2:
        tabMatches = binnenkort;
        break;
      case 3:
        tabMatches = gesloten;
        break;
      default:
        tabMatches = [...beschikbaar, ...binnenkort, ...gesloten];
    }

    // Apply search and filter
    return tabMatches.where((match) {
      final title = match['title']?.toString().toLowerCase() ?? '';
      final organizer = match['organizer']?.toString().toLowerCase() ?? '';
      final type = match['type']?.toString().toLowerCase() ?? '';
      
      // Search filter
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        if (!title.contains(query) && !organizer.contains(query) && !type.contains(query)) {
          return false;
        }
      }
      
      // Type filter
      if (selectedTypes.isNotEmpty && !selectedTypes.contains('Alle proeven')) {
        if (!selectedTypes.any((selectedType) => type.contains(selectedType.toLowerCase()))) {
          return false;
        }
      }
      
      return true;
    }).toList();
  }

  // Modern match list builder
  Widget _buildModernMatchList(AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
    final matches = snapshot.data ?? [];
    final filteredMatches = _getFilteredMatches(matches);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: filteredMatches.length,
      itemBuilder: (context, index) {
        final match = filteredMatches[index];
        return ProefCard(
          proef: match,
          isFavorite: false, // TODO: Implement favorite functionality
          onTap: () {
            setState(() {
              _selectedMatch = match;
            });
          },
        );
      },
    );
  }
}

// Settings page now uses the standalone InstellingenPage from instellingen_page.dart

String _formatMatchDate(Map<String, dynamic> match) {
  final rawDate = match['date'] ?? match['raw']?['date'];
  if (rawDate == null) return 'Datum onbekend';
  if (rawDate is Timestamp) {
    final dateTime = rawDate.toDate();
    return DateFormat('dd MMM yyyy', 'nl_NL').format(dateTime);
  }
  if (rawDate is DateTime) {
    return DateFormat('dd MMM yyyy', 'nl_NL').format(rawDate);
  }
  if (rawDate is String) {
    try {
      final dateTime = DateTime.parse(rawDate);
      return DateFormat('dd MMM yyyy', 'nl_NL').format(dateTime);
    } catch (_) {
      return rawDate;
    }
  }
  return rawDate.toString();
}

Future<List<Map<String, String>>> _getNotificationTimersAsync(DateTime baseDate) async {
  final List<Map<String, String>> timers = [];
  timers.add({
    'label': '7 dagen van tevoren',
    'time': DateFormat('dd MMM yyyy HH:mm', 'nl_NL').format(baseDate.subtract(const Duration(days: 7))),
    'icon': 'calendar',
  });
  timers.add({
    'label': '1 dag van tevoren',
    'time': DateFormat('dd MMM yyyy HH:mm', 'nl_NL').format(baseDate.subtract(const Duration(days: 1))),
    'icon': 'calendar',
  });
  timers.add({
    'label': '1 uur van tevoren',
    'time': DateFormat('dd MMM yyyy HH:mm', 'nl_NL').format(baseDate.subtract(const Duration(hours: 1))),
    'icon': 'clock',
  });
  return timers;
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final Color? textColor;
  final Color? borderColor;
  final bool enabled;
  final VoidCallback? onTap;
  const _ActionButton({
    required this.icon,
    required this.label,
    this.color,
    this.textColor,
    this.borderColor,
    this.enabled = true,
    this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 375;
    final isLargeScreen = screenWidth > 414;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            vertical: isSmallScreen ? 12 : 16,
            horizontal: 12,
          ),
          decoration: BoxDecoration(
            color: color ?? Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor ?? Colors.transparent, width: 2),
          ),
          child: Row(
            children: [
              Icon(icon, color: textColor ?? Colors.black),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: textColor ?? Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: isSmallScreen ? 16 : (isLargeScreen ? 19 : 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
