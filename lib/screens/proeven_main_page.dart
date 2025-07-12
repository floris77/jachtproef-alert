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
  
  // Enhanced scroll tracking for better UX using ValueNotifier to prevent ListView rebuilds
  late ValueNotifier<bool> _showHeader;
  double _lastScrollPosition = 0.0;
  static const double _scrollBufferDistance = 120.0; // About 1 match card height - more reasonable
  static const double _topThreshold = 150.0; // Show header when within 150px of top
  
  // ScrollController for preserving scroll position
  late ScrollController _scrollController;
  
  // Scroll debounce to prevent feedback loops
  bool _isScrolling = false;

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
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _showHeader = ValueNotifier<bool>(true);
  }

  void _onScroll() {
    final currentScrollPosition = _scrollController.offset;
    final scrollDelta = currentScrollPosition - _lastScrollPosition;
    
    // Simple, stable logic - avoid complex state changes that cause jumping
    bool shouldShowHeader = _showHeader.value;
    
    // Show header when at the very top
    if (currentScrollPosition <= 50.0) {
      shouldShowHeader = true;
    }
    // Hide header when scrolled down far enough with downward momentum
    else if (currentScrollPosition > 150.0 && scrollDelta > 5.0 && _showHeader.value) {
      shouldShowHeader = false;
    }
    // Show header when scrolling up with upward momentum (but not at top)
    else if (scrollDelta < -15.0 && currentScrollPosition > 80.0 && !_showHeader.value) {
      shouldShowHeader = true;
    }
    
    // Only update ValueNotifier if there's actually a change - this WON'T rebuild ListView
    if (shouldShowHeader != _showHeader.value) {
      _showHeader.value = shouldShowHeader; // This doesn't trigger setState!
    }
    
    // Always update last position for next delta calculation
    _lastScrollPosition = currentScrollPosition;
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
            // Collapsible Header Section - use ValueListenableBuilder to prevent ListView rebuilds
            ValueListenableBuilder<bool>(
              valueListenable: _showHeader,
              builder: (context, showHeader, child) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  height: showHeader ? null : 0,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: showHeader ? 1.0 : 0.0,
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
                                  'Hi, ${userName.isNotEmpty ? userName : 'there'} 👋',
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
                        // Search and Filter Bar
                        Padding(
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
                              // Filter Dropdown - clean list without horizontal scrolling
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: GestureDetector(
                                  onTap: () => _showFilterPicker(context),
                                  child: Container(
                                    height: 48,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: CupertinoColors.systemGrey4,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          selectedFilter,
                                          style: TextStyle(
                                            color: kMainColor,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Icon(
                                          CupertinoIcons.chevron_down,
                                          color: kMainColor,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Tab selector
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: CupertinoSlidingSegmentedControl<int>(
                            groupValue: selectedTab,
                            backgroundColor: CupertinoColors.systemGrey6,
                            thumbColor: kMainColor,
                            children: {
                              0: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  'Inschrijven',
                                  style: TextStyle(
                                    fontSize: isVerySmallScreen ? 11 : 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: selectedTab == 0 ? Colors.white : kMainColor,
                                  ),
                                ),
                              ),
                              1: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  'Binnenkort',
                                  style: TextStyle(
                                    fontSize: isVerySmallScreen ? 11 : 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: selectedTab == 1 ? Colors.white : kMainColor,
                                  ),
                                ),
                              ),
                              2: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  'Gesloten',
                                  style: TextStyle(
                                    fontSize: isVerySmallScreen ? 11 : 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: selectedTab == 2 ? Colors.white : kMainColor,
                                  ),
                                ),
                              ),
                              3: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  'Onbekend',
                                  style: TextStyle(
                                    fontSize: isVerySmallScreen ? 11 : 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: selectedTab == 3 ? Colors.white : kMainColor,
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
                      ],
                    ),
                  ),
                );
              },
            ),
            // Result count and Match list
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: MatchService.getMatchesStream(),
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
                          '${filteredMatches.length} resultaten',
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
                          key: const PageStorageKey('proeven_list_scroll_position'),
                          controller: _scrollController,
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

  // Filter picker modal - shows all options in a clean list
  void _showFilterPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                                 margin: const EdgeInsets.only(top: 12),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                                 padding: const EdgeInsets.all(20),
                child: Text(
                  'Filter Proeven',
                                     style: const TextStyle(
                     fontSize: 18,
                     fontWeight: FontWeight.bold,
                     color: Colors.black,
                   ),
                ),
              ),
              // Filter options list
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.75,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: matchTypes.length,
                  itemBuilder: (context, index) {
                    final type = matchTypes[index];
                    final isSelected = selectedFilter == type;
                    
                    return ListTile(
                      title: Text(
                        type,
                        style: TextStyle(
                          color: isSelected ? kMainColor : Colors.black,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 16,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(
                              CupertinoIcons.checkmark,
                              color: kMainColor,
                              size: 20,
                            )
                          : null,
                      onTap: () {
                        setState(() {
                          selectedFilter = type;
                          selectedTypes = [type];
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
              // Bottom padding for safe area
              SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
            ],
          ),
        );
      },
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

      // Handle empty registration text - default to 'inschrijven'
      if (regText.isEmpty) {
        regText = 'inschrijven';
      }

      final matchDate = _parseMatchDate(match);
      
      // Categorize registration text patterns
      bool isAvailableForEnrollment = false;
      bool isFutureEnrollment = false;
      bool isClosed = false;
      
      if (regText == 'inschrijven') {
        isAvailableForEnrollment = true;
      } else if (regText.startsWith('vanaf ')) {
        isFutureEnrollment = true;
      } else if (regText == 'niet mogelijk' || regText == 'niet meer mogelijk') {
        isClosed = true;
      } else {
        // Handle specialized enrollment criteria (breed-specific, selection matches, etc.)
        if (regText.contains('selectie') || regText.contains('kwalificatie') || 
            regText.contains('alleen') || regText.contains('specifiek') ||
            regText.contains('staande hond') || regText.contains('rasgroep') ||
            regText.contains('aantekening') || regText.contains('bezitten')) {
          // These are specialized subcategory matches - treat as available but with restrictions
          isAvailableForEnrollment = true;
        } else {
          // Unknown pattern - default to available
          print('[DEBUG] Unknown registration text: "$regText" for match: ${match['organizer']} - defaulting to available');
          isAvailableForEnrollment = true;
        }
      }
      
      // Categorize matches based on analysis
      if (isAvailableForEnrollment && matchDate != null && matchDate.isAfter(DateTime.now())) {
        beschikbaar.add(match);
      } else if (isFutureEnrollment) {
        // Parse enrollment date once and attach to match object
        DateTime? enrollmentDate;
        try {
          final dateTimeStr = regText.substring(6).trim(); // Remove 'vanaf ' and trim
          // Format: "22-06-2025 19:00" or "22-06-2025"
          final parts = dateTimeStr.split(' ');
          if (parts.isNotEmpty) {
            final datePart = parts[0]; // DD-MM-YYYY
            String timePart = '00:00'; // Default to midnight
            if (parts.length >= 2) {
              timePart = parts[1]; // HH:MM
            }
            final dateComponents = datePart.split('-');
            final timeComponents = timePart.split(':');
            if (dateComponents.length == 3 && timeComponents.length == 2) {
              enrollmentDate = DateTime(
                int.parse(dateComponents[2]), // Year
                int.parse(dateComponents[1]), // Month
                int.parse(dateComponents[0]), // Day
                int.parse(timeComponents[0]), // Hour
                int.parse(timeComponents[1]), // Minute
              );
              match['enrollmentDate'] = enrollmentDate;
              print('[DEBUG] Parsed enrollmentDate for match: '
                '${match['title'] ?? match['organizer']} -> $enrollmentDate');
            }
          }
        } catch (e) {
          print('[DEBUG] Failed to parse enrollmentDate for match: '
            '${match['title'] ?? match['organizer']} - Error: $e');
        }
        if (enrollmentDate != null && enrollmentDate.isAfter(DateTime.now())) {
          binnenkort.add(match);
        } else {
          // If enrollment date is in the past, move to appropriate category
          // Check if the match date is also in the past
          final matchDate = _parseMatchDate(match);
          if (matchDate != null && matchDate.isBefore(DateTime.now())) {
            // Match is in the past, mark as closed
            gesloten.add(match);
          } else {
            // Enrollment date is in the past but match is in the future
            // This should be "Inschrijven" (open for enrollment)
            beschikbaar.add(match);
          }
        }
      } else if (isClosed) {
        gesloten.add(match);
      } else {
        // This should rarely happen now with our improved categorization
        onbekend.add(match);
      }
    }

    // Debug: Print categorization results
    print('[DEBUG] Match categorization: beschikbaar=${beschikbaar.length}, binnenkort=${binnenkort.length}, gesloten=${gesloten.length}, onbekend=${onbekend.length}');
    


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
      final location = match['location']?.toString().toLowerCase() ?? '';
      final registrationText = match['registration_text']?.toString().toLowerCase() ?? 
                              match['registration']?['text']?.toString().toLowerCase() ?? 
                              match['raw']?['registration_text']?.toString().toLowerCase() ?? '';
      final remarks = match['remarks']?.toString().toLowerCase() ?? 
                     match['remark']?.toString().toLowerCase() ?? '';
      final calendarType = match['calendar_type']?.toString().toLowerCase() ?? '';
      
      // Search filter - now searches through all relevant fields
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        if (!title.contains(query) && 
            !organizer.contains(query) && 
            !type.contains(query) &&
            !location.contains(query) &&
            !registrationText.contains(query) &&
            !remarks.contains(query) &&
            !calendarType.contains(query)) {
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
        // Type filter - handle both abbreviations and full names
        final matchFound = selectedTypes.any((selectedType) {
          final selectedLower = selectedType.toLowerCase();
          final typeLower = type.toLowerCase();
          
          // Handle abbreviation mappings
          if (selectedLower == 'swt' && typeLower.contains('spaniël workingtest')) {
            return true;
          }
          if (selectedLower == 'kjp' && typeLower.contains('kinder jachtproef')) {
            return true;
          }
          if (selectedLower == 'owt' && typeLower.contains('orweja working test')) {
            return true;
          }
          
          // Default case-insensitive matching
          return typeLower.contains(selectedLower);
        });
        
        // Debug logging for specific types
        if (selectedTypes.contains('PJP') && type.toLowerCase().contains('pjp')) {
          print('[DEBUG] PJP filtering working: found match "${match['organizer']}"');
        }
        if (selectedTypes.contains('SWT') && type.toLowerCase().contains('spaniël')) {
          print('[DEBUG] SWT filtering working: found match "${match['organizer']}" with type "${type}"');
        }
        if (selectedTypes.contains('MAP') && type.toLowerCase().contains('map')) {
          print('[DEBUG] MAP filtering working: found match "${match['organizer']}" with type "${type}"');
        }
        
        if (!matchFound) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  /// Helper method to parse match date from various formats
  DateTime? _parseMatchDate(Map<String, dynamic> match) {
    try {
      final rawDate = match['date'] ?? match['raw']?['date'];
      if (rawDate == null) return null;
      
      if (rawDate is Timestamp) {
        return rawDate.toDate();
      }
      if (rawDate is DateTime) {
        return rawDate;
      }
      if (rawDate is String) {
        // Try different date formats
        final formats = [
          'yyyy-MM-dd',
          'dd-MM-yyyy',
          'yyyy/MM/dd',
          'dd/MM/yyyy',
        ];
        
        for (final format in formats) {
          try {
            return DateFormat(format).parse(rawDate);
          } catch (_) {
            continue;
          }
        }
        
        // Try ISO format as fallback
        return DateTime.parse(rawDate);
      }
      return null;
    } catch (e) {
      print('[DEBUG] Failed to parse match date: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    _showHeader.dispose();
    super.dispose();
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

// Collapsible Header Widget to prevent ListView rebuilds
class _CollapsibleHeader extends StatefulWidget {
  final bool showHeader;
  final String userName;
  final String searchQuery;
  final String selectedFilter;
  final int selectedTab;
  final List<String> selectedTypes;
  final List<String> userFavoriteTypes;
  final Function(String) onSearchChanged;
  final Function(String, List<String>) onFilterChanged;
  final Function(int) onTabChanged;

  const _CollapsibleHeader({
    required this.showHeader,
    required this.userName,
    required this.searchQuery,
    required this.selectedFilter,
    required this.selectedTab,
    required this.selectedTypes,
    required this.userFavoriteTypes,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onTabChanged,
  });

  @override
  State<_CollapsibleHeader> createState() => _CollapsibleHeaderState();
}

class _CollapsibleHeaderState extends State<_CollapsibleHeader> {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 375;
    final isLargeScreen = screenWidth > 414;
    final isVerySmallScreen = screenWidth < 350;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: widget.showHeader ? null : 0,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: widget.showHeader ? 1.0 : 0.0,
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
                      'Hi, ${widget.userName.isNotEmpty ? widget.userName : 'there'} 👋',
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
          ],
        ),
      ),
    );
  }
}

