import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
import '../services/calendar_service.dart';
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
import '../utils/constants.dart';

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
  // Create a simple match data structure for the calendar service
  final matchData = {
    'title': title,
    'description': description,
    'date': '${start.day.toString().padLeft(2, '0')}-${start.month.toString().padLeft(2, '0')}-${start.year}',
    'location': '',
  };
  
  // Use the calendar service (note: this is a simplified version for legacy compatibility)
  // In a real implementation, you'd want to pass the proper context and handle the result
  print('📅 [LEGACY] Calendar add requested for: $title');
  
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
    final isVerySmallScreen = screenWidth < 350;
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
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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
  String selectedFilter = 'Alle proeven';
  List<String> selectedTypes = ['Alle proeven'];
  int selectedTab = 0;
  List<String> userFavoriteTypes = [];
  String userName = '';
  late TabController _tabController;
  
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
    _loadUserData();
    _loadUserPreferences();
    _showFirstTimeHelp();
    _tabController = TabController(length: 4, vsync: this);
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
      
        setState(() {
          userFavoriteTypes = savedTypes;
        selectedTypes = ['Alle proeven'];
          selectedFilter = 'Alle proeven';
        });
    } catch (e) {
      print('🎯 Error loading user preferences: $e');
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
    // Always show the list view; remove inline details view logic
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 375;
    final isLargeScreen = screenWidth > 414;
    final isVerySmallScreen = screenWidth < 350;
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Custom App Bar
            Padding(
              padding: EdgeInsets.only(top: isVerySmallScreen ? 8 : 10, left: 0, right: 0, bottom: 0),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Center(
                    child: Text(
                      'Proeven',
                      style: TextStyle(
                        fontSize: isVerySmallScreen ? 18 : 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  // iOS-style Help button
                  Positioned(
                    right: 20,
                    child: CupertinoButton(
                      padding: EdgeInsets.all(isVerySmallScreen ? 8 : 12),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (context) => const HelpScreen()),
                              );
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: kMainColor,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.question_circle,
                              color: kMainColor,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'HELP',
                              style: TextStyle(
                                color: kMainColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                          ),
                        ),
                      ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Greeting and subtitle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      'Hi,  0${userName.isNotEmpty ? userName : 'there'} 👋',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: kMainColor,
                        overflow: TextOverflow.ellipsis,
                      ),
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Laten we samen je volgende proef vinden!',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[400],
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            // Responsive Search and Filter Bar
            LayoutBuilder(
              builder: (context, constraints) {
                final isSmallScreen = constraints.maxWidth < 370;
                if (isSmallScreen) {
                  // Stack vertically on small screens
                  return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                        Container(
                      height: 48,
                          margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                            color: CupertinoColors.systemGrey6,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: CupertinoColors.systemGrey4,
                              width: 0.5,
                            ),
                          ),
                          child: CupertinoTextField(
                            placeholder: 'Zoeken',
                            placeholderStyle: TextStyle(
                              color: CupertinoColors.systemGrey,
                              fontSize: 16,
                            ),
                            prefix: Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Icon(
                                CupertinoIcons.search,
                                color: CupertinoColors.systemGrey,
                                size: 20,
                              ),
                            ),
                            style: const TextStyle(
                              fontSize: 16,
                              color: CupertinoColors.label,
                            ),
                            decoration: null,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        onChanged: (value) {
                          setState(() {
                            searchQuery = value;
                          });
                        },
                      ),
                    ),
                        Container(
                      height: 48,
                          margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                            color: _isFilterActive() ? kMainColor.withOpacity(0.10) : CupertinoColors.systemGrey6,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isFilterActive() ? kMainColor : CupertinoColors.systemGrey4,
                              width: _isFilterActive() ? 1.5 : 0.5,
                            ),
                      ),
                          child: CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            onPressed: () {
                              _showFilterPicker();
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    selectedFilter,
                          style: TextStyle(
                                      color: _isFilterActive() ? kMainColor : CupertinoColors.label,
                                      fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                  Icon(
                                  CupertinoIcons.chevron_down,
                                  color: _isFilterActive() ? kMainColor : CupertinoColors.systemGrey,
                                  size: 16,
                                  ),
                              ],
                            ),
                          ),
                        ),
                                ],
                              ),
                            );
                } else {
                  // Side by side on normal screens
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          width: 160, // Fixed width for search bar
                          height: 48,
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemGrey6,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: CupertinoColors.systemGrey4,
                              width: 0.5,
                            ),
                          ),
                          child: CupertinoTextField(
                            placeholder: 'Zoeken',
                            placeholderStyle: TextStyle(
                              color: CupertinoColors.systemGrey,
                              fontSize: 16,
                        ),
                            prefix: Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Icon(
                                CupertinoIcons.search,
                                color: CupertinoColors.systemGrey,
                                size: 20,
              ),
            ),
                            style: const TextStyle(
                              fontSize: 16,
                              color: CupertinoColors.label,
                            ),
                            decoration: null,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            onChanged: (value) {
                              setState(() {
                                searchQuery = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16), // More space between search and filter
                        Expanded(
              child: Container(
                            height: 48,
                decoration: BoxDecoration(
                              color: _isFilterActive() ? kMainColor : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: kMainColor,
                                width: 1.5,
                              ),
                            ),
                            child: CupertinoButton(
                              padding: const EdgeInsets.symmetric(horizontal: 18),
                              onPressed: () {
                                _showFilterPicker();
                              },
                child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                      Expanded(
                                    child: Text(
                                      selectedFilter,
                                      style: TextStyle(
                                        color: _isFilterActive() ? Colors.white : kMainColor,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Icon(
                                    CupertinoIcons.chevron_down,
                                    color: _isFilterActive() ? Colors.white : kMainColor,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 12),
            // Apple-style Segmented Control (Cupertino) with no scrolling and no truncation
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: CupertinoSlidingSegmentedControl<int>(
                groupValue: selectedTab,
                backgroundColor: Colors.white,
                thumbColor: kMainColor,
                children: {
                  0: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                    child: Center(
                            child: Text(
                                'Alle',
                        style: TextStyle(
                          fontSize: isVerySmallScreen ? 11 : 12.5,
                          fontWeight: FontWeight.w600,
                          color: selectedTab == 0 ? Colors.white : kMainColor,
                        ),
                      ),
                    ),
                  ),
                  1: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                    child: Center(
                      child: Text(
                                'Inschrijven',
                        style: TextStyle(
                          fontSize: isVerySmallScreen ? 11 : 12.5,
                          fontWeight: FontWeight.w600,
                          color: selectedTab == 1 ? Colors.white : kMainColor,
                        ),
                      ),
                    ),
                  ),
                  2: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                    child: Center(
                      child: Text(
                                'Binnenkort',
                        style: TextStyle(
                          fontSize: isVerySmallScreen ? 11 : 12.5,
                          fontWeight: FontWeight.w600,
                          color: selectedTab == 2 ? Colors.white : kMainColor,
                            ),
                          ),
                        ),
                      ),
                  3: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                    child: Center(
                      child: Text(
                        'Gesloten',
                        style: TextStyle(
                          fontSize: isVerySmallScreen ? 11 : 12.5,
                          fontWeight: FontWeight.w600,
                          color: selectedTab == 3 ? Colors.white : kMainColor,
                ),
              ),
            ),
                  ),
                },
                onValueChanged: (int? value) {
                  if (value != null) {
                    setState(() {
                      selectedTab = value;
                    });
                  }
                },
              ),
            ),
            const SizedBox(height: 18),
            // Result count and Match list
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: MatchService.fetchMatches(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Fout bij laden van proeven'),
                    );
                  }
                  final matches = snapshot.data ?? [];
                  final filteredMatches = _getFilteredMatches(matches);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          ' ${filteredMatches.length} resultaten',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[400],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          itemCount: filteredMatches.length,
                          itemBuilder: (context, index) {
                            final match = filteredMatches[index];
                            return ProefCard(
                              proef: match,
                              isFavorite: false,
                              onTap: () {
                                Navigator.of(context).push(
                                  CupertinoPageRoute(
                                    builder: (context) => MatchDetailsPage(
                                      match: match,
                                      key: ValueKey(match['id'] ?? match['title']),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to determine if a filter is active
  bool _isFilterActive() {
    return selectedFilter != 'Alle proeven';
  }

  // iOS-style filter picker
  void _showFilterPicker() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => Container(
        height: 300,
        padding: const EdgeInsets.only(top: 6.0),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey4,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: CupertinoPicker(
                  magnification: 1.2,
                  squeeze: 1.2,
                  useMagnifier: true,
                  itemExtent: 50,
                  scrollController: FixedExtentScrollController(
                    initialItem: matchTypes.indexOf(selectedFilter),
                  ),
                  onSelectedItemChanged: (int selectedIndex) {
                    setState(() {
                      selectedFilter = matchTypes[selectedIndex];
                      selectedTypes = [matchTypes[selectedIndex]];
                    });
                  },
                  children: List<Widget>.generate(matchTypes.length, (int index) {
                    final isFavorite = matchTypes[index] == 'Favorieten';
                    return Center(
                      child: Text(
                        matchTypes[index],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isFavorite ? FontWeight.bold : FontWeight.w500,
                          color: isFavorite ? kMainColor : CupertinoColors.label,
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
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
    List<Map<String, dynamic>> onbekend = [];

    for (final match in matches) {
      // Use the correct field for registration text
      String regText = '';
      if (match['registration'] != null && match['registration']['text'] != null) {
        regText = match['registration']['text'].toString();
      } else if (match['regText'] != null) {
        regText = match['regText'].toString();
      } else if (match['registration_text'] != null) {
        regText = match['registration_text'].toString();
      } else if (match['raw'] != null && match['raw']['registration_text'] != null) {
        regText = match['raw']['registration_text'].toString();
      }
      regText = regText.trim().toLowerCase();

      // Use exact matching for categories
      if (regText == 'inschrijven') {
        beschikbaar.add(match);
      } else if (regText.startsWith('vanaf ')) {
        binnenkort.add(match);
      } else if (regText == 'niet mogelijk' || regText == 'niet meer mogelijk') {
        gesloten.add(match);
      } else {
        onbekend.add(match);
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
        tabMatches = [...beschikbaar, ...binnenkort, ...gesloten, ...onbekend];
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
      // Favorites filter
      if (selectedTypes.contains('Favorieten')) {
        // Only show matches whose type is in userFavoriteTypes
        if (userFavoriteTypes.isEmpty) return false;
        if (!userFavoriteTypes.any((favType) => type.contains(favType.toLowerCase()))) {
          return false;
        }
      } else if (selectedTypes.isNotEmpty && !selectedTypes.contains('Alle proeven')) {
        // Type filter
        if (!selectedTypes.any((selectedType) => type.contains(selectedType.toLowerCase()))) {
          return false;
        }
      }
      return true;
    }).toList();
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

