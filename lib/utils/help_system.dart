import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'responsive_dialogs.dart';
import 'responsive_helper.dart';
import 'dart:math' as math;
import 'dart:async';
import '../screens/proeven_main_page.dart';

class HelpSystem {
  static const String _firstLaunchKey = 'first_launch_completed';
  static const String _proevenHelpShownKey = 'proeven_help_shown';
  static const String _agendaHelpShownKey = 'agenda_help_shown';
  static const String _settingsHelpShownKey = 'settings_help_shown';
  static const String _helpButtonPopupCountKey = 'help_button_popup_count';
  static const String _quickTourShownKey = 'quick_tour_shown';
  static const String _cardClickCountKey = 'card_click_count';
  static const int _requiredCardClicks = 5;
  
  // Track if tour is currently active
  static bool _isTourActive = false;
  static DateTime? _lastTourActivity;

  // Global keys for widget targeting
  static final Map<String, GlobalKey> targetKeys = {
    'search_field': GlobalKey(),
    'filter_button': GlobalKey(),
    'status_tabs': GlobalKey(),
    'demo_card': GlobalKey(),
    'help_button': GlobalKey(),
    'help_screen_button': GlobalKey(),
  };
  
  // Separate demo keys to avoid conflicts with real app
  static final Map<String, GlobalKey> demoKeys = {
    'demo_search_field': GlobalKey(),
    'demo_filter_button': GlobalKey(),
    'demo_status_tabs': GlobalKey(),
    'demo_card': GlobalKey(),
  };

  static Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_firstLaunchKey) ?? false);
  }

  static Future<void> markFirstLaunchCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firstLaunchKey, true);
  }

  static Future<bool> shouldShowProevenHelp() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_proevenHelpShownKey) ?? false);
  }

  static Future<void> markProevenHelpShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_proevenHelpShownKey, true);
  }

  static Future<bool> shouldShowAgendaHelp() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_agendaHelpShownKey) ?? false);
  }

  static Future<void> markAgendaHelpShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_agendaHelpShownKey, true);
  }

  static Future<bool> shouldShowSettingsHelp() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_settingsHelpShownKey) ?? false);
  }

  static Future<void> markSettingsHelpShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_settingsHelpShownKey, true);
  }

  static Future<bool> shouldShowHelpButtonPopup() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_helpButtonPopupCountKey) ?? 0;
    return count < 2;
  }

  static Future<void> markHelpButtonPopupShown() async {
    final prefs = await SharedPreferences.getInstance();
    final currentCount = prefs.getInt(_helpButtonPopupCountKey) ?? 0;
    await prefs.setInt(_helpButtonPopupCountKey, currentCount + 1);
  }

  static Future<bool> shouldShowQuickTour() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid ?? 'anonymous';
      return !(prefs.getBool('${_quickTourShownKey}_$userId') ?? false);
    } catch (e) {
      // Fallback to global key if Firebase fails
      return !(prefs.getBool(_quickTourShownKey) ?? false);
    }
  }

  static Future<void> markQuickTourShown() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid ?? 'anonymous';
      await prefs.setBool('${_quickTourShownKey}_$userId', true);
    } catch (e) {
      // Fallback to global key if Firebase fails
      await prefs.setBool(_quickTourShownKey, true);
    }
  }



  static Future<bool> shouldShowVisualCardHints() async {
    final prefs = await SharedPreferences.getInstance();
    final clickCount = prefs.getInt(_cardClickCountKey) ?? 0;
    return clickCount < _requiredCardClicks;
  }

  static Future<void> incrementCardClickCount() async {
    final prefs = await SharedPreferences.getInstance();
    final currentCount = prefs.getInt(_cardClickCountKey) ?? 0;
    await prefs.setInt(_cardClickCountKey, currentCount + 1);
  }

  static Future<int> getCardClickCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_cardClickCountKey) ?? 0;
  }
  
  /// Check if the tour is currently active
  static bool get isTourActive => _isTourActive;
  
  /// Set tour active state (called when tour starts/ends)
  static void setTourActive(bool active) {
    print('🎯 HELP SYSTEM DEBUG: Setting tour active to $active');
    _isTourActive = active;
    // Don't set _lastTourActivity here - only when tour is actually completed
  }
  
  /// Mark tour as completed (only called when user finishes tour)
  static void markTourCompleted() {
    print('🎯 HELP SYSTEM DEBUG: Marking tour as completed');
      _lastTourActivity = DateTime.now();
  }
  
  /// Check if there was recent tour activity (within last 10 seconds)
  static bool isRecentTourActivity() {
    if (_lastTourActivity == null) return false;
    final timeSinceLastActivity = DateTime.now().difference(_lastTourActivity!);
    final isRecent = timeSinceLastActivity.inSeconds < 10;
    print('🎯 HELP SYSTEM DEBUG: isRecentTourActivity = $isRecent (${timeSinceLastActivity.inSeconds}s ago)');
    return isRecent;
  }

  /// Clear tour state (useful for debugging or manual reset)
  static void clearTourState() {
    print('🎯 HELP SYSTEM DEBUG: Clearing tour state manually');
    _isTourActive = false;
    _lastTourActivity = null;
  }

  static void showHelpTooltip(BuildContext context, String message, {Duration duration = const Duration(seconds: 3)}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.lightbulb_outline,
              color: Colors.white,
              size: ResponsiveHelper.getIconSize(context, 20.0),
            ),
            SizedBox(width: ResponsiveHelper.getSpacing(context, 8.0)),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: ResponsiveHelper.getCaptionFontSize(context),
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF535B22),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  static void showFeatureDiscovery(BuildContext context, String title, String description, VoidCallback onGotIt) {
    showDialog(
      context: context,
      builder: (context) => ResponsiveDialogs.createResponsiveAlertDialog(
        context: context,
        title: ResponsiveDialogs.createResponsiveDialogTitle(
          context: context,
          title: title,
          icon: Icons.tips_and_updates,
        ),
        content: Text(
          description,
          style: TextStyle(
            fontSize: ResponsiveHelper.getBodyFontSize(context),
            height: 1.4,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onGotIt();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF535B22),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: ResponsiveHelper.getButtonPadding(context),
            ),
            child: Text(
              'Begrepen!',
              style: TextStyle(
                fontSize: ResponsiveHelper.getCaptionFontSize(context),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void showHelpButtonPopup(BuildContext context, VoidCallback onHelpPressed) {
    showDialog(
      context: context,
      builder: (context) => ResponsiveDialogs.createResponsiveAlertDialog(
        context: context,
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(ResponsiveHelper.getSpacing(context, 8.0)),
              decoration: BoxDecoration(
                color: Color(0xFF535B22).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.help,
                color: const Color(0xFF535B22),
                size: ResponsiveHelper.getIconSize(context, 24.0),
              ),
            ),
            SizedBox(width: ResponsiveHelper.getSpacing(context, 12.0)),
            Expanded(
              child: Text(
                'Welkom bij Jachtproef Alert!',
                style: TextStyle(
                  fontSize: ResponsiveHelper.getSubtitleFontSize(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: ResponsiveDialogs.createResponsiveDialogContent(
          context: context,
          message: 'Ontdek alle functies met onze interactieve rondleiding! Een eenvoudige stap-voor-stap tour door alle belangrijke features.',
          benefits: [
            '🎯 Duidelijke introductie van alle app functies',
            '📱 Eenvoudige stap-voor-stap begeleiding',
            '⚡ Snel en overzichtelijk',
            '🎉 Makkelijk te volgen',
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              markHelpButtonPopupShown();
            },
            child: Text(
              'Later',
              style: TextStyle(
                color: Colors.grey,
                fontSize: ResponsiveHelper.getCaptionFontSize(context),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              markHelpButtonPopupShown();
              showSimpleTour(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF535B22),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: ResponsiveHelper.getButtonPadding(context),
            ),
            child: Text(
              'Start Interactieve Tour',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: ResponsiveHelper.getCaptionFontSize(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void showSimpleTour(BuildContext context) {
    // Prevent multiple tour instances
    if (_isTourActive) {
      print('🎯 HELP SYSTEM DEBUG: Tour already active, skipping...');
      return;
    }
    
    setTourActive(true); // Mark tour as active
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SimpleTourPage(),
      ),
    ).then((_) {
      // Tour finished, mark as inactive
      setTourActive(false);
    });
  }
}

class HelpButton extends StatelessWidget {
  final VoidCallback onPressed;
  
  const HelpButton({Key? key, required this.onPressed}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF535B22),
            Color(0xFF535B22).withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF535B22).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.help_outline,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 4),
                const Text(
                  'HELP',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SimpleTourPage extends StatefulWidget {
  @override
  _SimpleTourPageState createState() => _SimpleTourPageState();
}

class _SimpleTourPageState extends State<SimpleTourPage> with TickerProviderStateMixin {
  int currentPage = 0;
  int currentStep = 0;
  bool showingIntro = true;
  Timer? _autoProgressTimer;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  
  // Local demo keys for this tour instance
  final GlobalKey _demoSearchKey = GlobalKey();
  final GlobalKey _demoFilterKey = GlobalKey();  
  final GlobalKey _demoTabsKey = GlobalKey();
  final GlobalKey _demoCardKey = GlobalKey();
  // Detail page demo keys
  final GlobalKey _demoInschrijvenKey = GlobalKey();
  final GlobalKey _demoMeldingenKey = GlobalKey();
  final GlobalKey _demoAgendaKey = GlobalKey();
  final GlobalKey _demoDelenKey = GlobalKey();

  // Get the position and size of a target widget
  Rect? _getTargetRect(String targetKey) {
    print('🎯 DEBUG: Looking for targetKey: $targetKey');
    
    // Get screen dimensions for responsive calculations
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    
    // Handle fallback case for demo
    if (targetKey == 'fallback') {
      print('🎯 DEBUG: Using fallback for $targetKey');
      return null; // Will trigger fallback tooltip
    }
    
    // Handle search field with responsive position calculation
    if (targetKey == 'demo_search_field') {
      print('🎯 DEBUG: Using responsive position for search field');
      
      // Calculate search field position based on screen width
      // Search field starts at 16px margin and extends to leave room for filter button
      final searchFieldLeft = 16.0;
      final filterButtonWidth = 120.0; // Approximate filter button width
      final searchFieldRight = screenWidth - filterButtonWidth - 24.0; // 24px for spacing and margin
      final searchFieldTop = 220.0; // This remains relatively consistent
      final searchFieldHeight = 48.0;
      
      final rect = Rect.fromLTRB(searchFieldLeft, searchFieldTop, searchFieldRight, searchFieldTop + searchFieldHeight);
      print('🎯 DEBUG: Responsive search field rect: $rect (screen width: $screenWidth)');
      return rect;
    }
    
    // Handle demo_inschrijven with responsive position calculation
    if (targetKey == 'demo_inschrijven') {
      print('🎯 DEBUG: Using responsive position for inschrijven button');
      
      // Calculate inschrijven button position based on screen width
      final buttonLeft = 16.0;
      final buttonRight = screenWidth - 16.0; // Full width minus margins
      final buttonTop = 183.0; // This may need adjustment based on screen height
      final buttonHeight = 63.0; // Standard button height
      
      final rect = Rect.fromLTRB(buttonLeft, buttonTop, buttonRight, buttonTop + buttonHeight);
      print('🎯 DEBUG: Responsive inschrijven rect: $rect (screen width: $screenWidth)');
      return rect;
    }
    
    // Check local demo keys first, then static keys
    GlobalKey? key;
    switch (targetKey) {
      case 'demo_search_field':
        // This case is now handled above with hardcoded position - skip GlobalKey
        key = null; // Force to use hardcoded position above
        break;

      case 'demo_filter_button':
        key = _demoFilterKey;
        print('🎯 DEBUG: Using _demoFilterKey: ${key.currentContext != null}');
        break;
      case 'demo_status_tabs':
        key = _demoTabsKey;
        print('🎯 DEBUG: Using _demoTabsKey: ${key.currentContext != null}');
        break;
      case 'demo_card':
        key = _demoCardKey;
        print('🎯 DEBUG: Using _demoCardKey: ${key.currentContext != null}');
        break;
      case 'demo_inschrijven':
        key = _demoInschrijvenKey;
        print('🎯 DEBUG: Using _demoInschrijvenKey: ${key.currentContext != null}');
        break;
      case 'demo_meldingen':
        key = _demoMeldingenKey;
        print('🎯 DEBUG: Using _demoMeldingenKey: ${key.currentContext != null}');
        break;
      case 'demo_agenda':
        key = _demoAgendaKey;
        print('🎯 DEBUG: Using _demoAgendaKey: ${key.currentContext != null}');
        break;
      case 'demo_delen':
        key = _demoDelenKey;
        print('🎯 DEBUG: Using _demoDelenKey: ${key.currentContext != null}');
        break;
      default:
        key = HelpSystem.targetKeys[targetKey];
        print('🎯 DEBUG: Using static key for $targetKey: ${key?.currentContext != null}');
    }
    
    if (key?.currentContext == null) {
      print('🎯 DEBUG: No context found for $targetKey');
      return null;
    }
    
    final RenderBox renderBox = key!.currentContext!.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    
    final rect = Rect.fromLTWH(position.dx, position.dy, size.width, size.height);
    print('🎯 DEBUG: Found rect for $targetKey: $rect');
    
    return rect;
  }
  
  // Tour data
  final List<TourPage> tourPages = [
    TourPage(
      title: 'Proeven Zoeken',
      steps: [
        TourStep(
          title: 'Stap 1: Slim Zoeken 🔍',
          description: 'Typ hier de naam van een proef, locatie (bijv. "Hoogerheide") of type (bijv. "Eendenjacht"). De zoekfunctie is super snel!',
          targetKey: 'demo_search_field', // Target demo search field
        ),
        TourStep(
          title: 'Stap 2: Filters 🎯',
          description: 'Klik hier om te filteren op specifieke proef types zoals SJP, MAP, Veldwedstrijd, etc. Je kunt meerdere types tegelijk selecteren!',
          targetKey: 'demo_filter_button', // Target demo filter button
        ),
        TourStep(
          title: 'Stap 3: Status Overzicht 📊',
                      description: 'Deze tabs tonen je de proef status! "Inschrijven" = open voor inschrijving, "Binnenkort" = deadline nadert.',
          targetKey: 'demo_status_tabs', // Target demo status tabs
        ),
        TourStep(
          title: 'Stap 4: Proef Kaarten 📋',
          description: 'Elke proef kaart bevat alle info die je nodig hebt. Tik erop om details te zien en acties uit te voeren!',
          targetKey: 'demo_card', // Target demo card
          actionText: 'Tik op de kaart om door te gaan!',
        ),
      ],
    ),
    TourPage(
      title: 'Proef Details',
      steps: [
        TourStep(
          title: 'Stap 5: Inschrijving Beheren ✅',
          description: 'Markeer jezelf als "ingeschreven" om je deelnames bij te houden. Klik op deze knop om jezelf in te schrijven voor de proef.',
          targetKey: 'demo_inschrijven', // Target demo inschrijven button
        ),
        TourStep(
          title: 'Stap 6: Slimme Meldingen 🔔',
          description: 'Stel automatische herinneringen in voor deadlines. De app stuurt je precies op tijd een push notificatie zodat je geen belangrijke datums mist.',
          targetKey: 'demo_meldingen', // Target demo meldingen button
        ),
        TourStep(
          title: 'Stap 7: Agenda Synchronisatie 📅',
          description: 'Voeg proef datums toe aan je iPhone/Android agenda. Perfect voor planning! Zo heb je alle informatie direct in je telefoon.',
          targetKey: 'demo_agenda', // Target demo agenda button
        ),
        TourStep(
          title: 'Stap 8: Delen met Vrienden 📤',
          description: 'Deel proef details met je jachtmaatjes! Stuur via WhatsApp, e-mail of andere apps. Zo kunnen jullie samen naar dezelfde proeven gaan.',
          targetKey: 'demo_delen', // Target demo delen button
          actionText: 'Ga naar Mijn Agenda om door te gaan!',
        ),
      ],
    ),
    TourPage(
      title: 'Mijn Agenda',
      steps: [
        TourStep(
          title: 'Stap 9: Je Persoonlijke Cockpit 📋',
          description: 'Vind dit in de echte app via de "Mijn Agenda" tab onderaan! Hier zie je alle proeven waar je interesse in hebt getoond. De icoontjes tonen je status: ✅ ingeschreven, 🔔 meldingen aan, 📅 in agenda.',
          targetKey: 'fallback', // Use fallback for demo
        ),
      ],
    ),
  ];
  
  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _progressController, curve: Curves.linear));
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showIntroduction();
    });
  }

  @override
  void dispose() {
    _autoProgressTimer?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  void _showIntroduction() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: ResponsiveHelper.getResponsiveConstraints(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    padding: EdgeInsets.all(ResponsiveHelper.getSpacing(context, 24.0)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: EdgeInsets.all(ResponsiveHelper.getSpacing(context, 16.0)),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF535B22),
                                Color(0xFF535B22).withOpacity(0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Icon(
                            Icons.explore,
                            size: ResponsiveHelper.getIconSize(context, 48.0),
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: ResponsiveHelper.getSpacing(context, 20.0)),
                        Text(
                          'Welkom bij de Interactieve Tour! 🎯',
                          style: TextStyle(
                            fontSize: ResponsiveHelper.getTitleFontSize(context),
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF535B22),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: ResponsiveHelper.getSpacing(context, 16.0)),
                        Container(
                          padding: EdgeInsets.all(ResponsiveHelper.getSpacing(context, 16.0)),
                          decoration: BoxDecoration(
                            color: Color(0xFF535B22).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dit gaan we ontdekken:',
                                style: TextStyle(
                                  fontSize: ResponsiveHelper.getSubtitleFontSize(context),
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF535B22),
                                ),
                              ),
                              SizedBox(height: ResponsiveHelper.getSpacing(context, 12.0)),
                              _buildFeatureItem('🔍', 'Slim zoeken', 'Vind snel de perfecte proef'),
                              SizedBox(height: ResponsiveHelper.getSpacing(context, 8.0)),
                              _buildFeatureItem('🎯', 'Filter en sorteren', 'Personaliseer je zoekresultaten'),
                              SizedBox(height: ResponsiveHelper.getSpacing(context, 8.0)),
                              _buildFeatureItem('📱', 'Proef details', 'Alle info die je nodig hebt'),
                              SizedBox(height: ResponsiveHelper.getSpacing(context, 8.0)),
                              _buildFeatureItem('🔔', 'Slimme meldingen', 'Mis nooit een deadline'),
                              SizedBox(height: ResponsiveHelper.getSpacing(context, 8.0)),
                              _buildFeatureItem('📅', 'Agenda integratie', 'Sync met je telefoon'),
                            ],
                          ),
                        ),
                        SizedBox(height: ResponsiveHelper.getSpacing(context, 24.0)),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  left: ResponsiveHelper.getSpacing(context, 24.0),
                  right: ResponsiveHelper.getSpacing(context, 24.0),
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  top: 0,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      setState(() {
                        showingIntro = false;
                      });
                      _startTour();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF535B22),
                      foregroundColor: Colors.white,
                      padding: ResponsiveHelper.getButtonPadding(context),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_arrow, size: ResponsiveHelper.getIconSize(context, 20.0)),
                        SizedBox(width: ResponsiveHelper.getSpacing(context, 8.0)),
                        Flexible(
                          child: Text(
                            'Start Tour!',
                            style: TextStyle(
                              fontSize: ResponsiveHelper.getBodyFontSize(context),
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
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
      ),
    );
  }

  Widget _buildFeatureItem(String emoji, String title, String description) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: ResponsiveHelper.getCaptionFontSize(context),
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF535B22),
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: ResponsiveHelper.getCaptionFontSize(context) * 0.9,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _startTour() {
    _startAutoProgressTimer();
  }

  void _startAutoProgressTimer() {
    int duration = 15; // Default duration
    _progressController.duration = Duration(seconds: duration);
    _progressController.forward();
    
    _autoProgressTimer = Timer(Duration(seconds: duration), () {
      if (mounted) {
        _nextStep();
      }
    });
  }

  void _nextStep() {
    _autoProgressTimer?.cancel();
    _progressController.reset();
    
    if (currentStep < tourPages[currentPage].steps.length - 1) {
      setState(() {
        currentStep++;
      });
      _startAutoProgressTimer();
    } else if (currentPage < tourPages.length - 1) {
      setState(() {
        currentPage++;
        currentStep = 0;
      });
      _startAutoProgressTimer();
    } else {
      _completeTour();
    }
  }

  void _completeTour() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: ResponsiveHelper.getResponsiveConstraints(context),
          child: SingleChildScrollView(
            child: Container(
              padding: EdgeInsets.all(ResponsiveHelper.getSpacing(context, 24.0)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(ResponsiveHelper.getSpacing(context, 16.0)),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.green,
                          Colors.green.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Icon(
                      Icons.check_circle,
                      size: ResponsiveHelper.getIconSize(context, 48.0),
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.getSpacing(context, 20.0)),
                  
                  Text(
                    'Tour Voltooid! 🎉',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getTitleFontSize(context),
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF535B22),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: ResponsiveHelper.getSpacing(context, 16.0)),
                  
                  Text(
                    'Je hebt nu alle belangrijke functies gezien! Je kunt nu zelfstandig proeven zoeken, details bekijken en meldingen instellen.',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getBodyFontSize(context),
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: ResponsiveHelper.getSpacing(context, 24.0)),
                  
                  ElevatedButton(
                    onPressed: () async {
                      await HelpSystem.markQuickTourShown(); // Mark tour as completed
                      HelpSystem.markTourCompleted(); // Mark tour activity for demo mode
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF535B22),
                      foregroundColor: Colors.white,
                      padding: ResponsiveHelper.getButtonPadding(context),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Ga naar App',
                      style: TextStyle(
                        fontSize: ResponsiveHelper.getBodyFontSize(context),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (showingIntro) {
      return Scaffold(
        body: Container(),
      );
    }

    final currentTourPage = tourPages[currentPage];
    final currentTourStep = currentTourPage.steps[currentStep];
    
    return GestureDetector(
      onTap: _nextStep,
      child: Stack(
        children: [
          // Real app content based on current tour page
          _buildRealAppPage(),
          
          // Semi-transparent overlay to dim the background
          Container(
            color: Colors.black.withOpacity(0.3),
          ),
          
          // Custom overlay tooltip
          _buildTooltipOverlay(currentTourStep),
          
          // Progress indicator
          _buildProgressIndicator(),
        ],
      ),
    );
  }

  Widget _buildRealAppPage() {
    switch (currentPage) {
      case 0: // Proeven Zoeken page - exact copy of real app
        return _buildProevenReplicaDemo();
      case 1: // Proef Details page
        return _buildDetailDemo(); 
      case 2: // Mijn Agenda page - exact copy of real app
        return _buildAgendaReplicaDemo();
      default:
        return _buildProevenReplicaDemo();
    }
  }

  // Removed _buildProevenDemo - now using real ProevenMainPage

  Widget _buildDetailDemo() {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Proef Details'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Color(0xFF535B22).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xFF535B22).withOpacity(0.3)),
              ),
              child: const Text(
                'DEMO',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF535B22),
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {},
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Orweja Working Test',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('OWT', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            Column(
              children: [
                _buildActionButton(Icons.radio_button_unchecked, 'Inschrijven', _demoInschrijvenKey),
                const SizedBox(height: 12),
                _buildActionButton(Icons.notifications_off, 'Meldingen uit', _demoMeldingenKey),
                const SizedBox(height: 12),
                _buildActionButton(Icons.calendar_today, 'Toevoegen aan agenda', _demoAgendaKey),
                const SizedBox(height: 12),
                _buildActionButton(Icons.share, 'Delen', _demoDelenKey),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Removed _buildAgendaDemo - now using real ProevenMainPage

  // Demo pages that exactly replicate real app appearance but with separate keys
  
  Widget _buildProevenReplicaDemo() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Proeven'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Color(0xFF535B22).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xFF535B22).withOpacity(0.3)),
              ),
              child: const Text(
                'DEMO',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF535B22),
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hi, Jager 👋',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF535B22)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Laten we samen je volgende proef vinden!',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    key: _demoSearchKey, // Demo search field key - moved to Container
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Zoeken op naam, locatie of type...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[200],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                                 Container(
                   key: _demoFilterKey, // Demo filter button key
                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.tune),
                      const SizedBox(width: 6),
                      const Text('Filter', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
                         child: Row(
               key: _demoTabsKey, // Demo status tabs key
               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTabButton('Alle', true),
                                  _buildTabButton('Inschrijven', false),
                _buildTabButton('Binnenkort', false),
                _buildTabButton('Gesloten', false),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          Expanded(
            child: ListView(
              children: [
                _buildReplicaCard1(),
                _buildReplicaCard2(),
                _buildReplicaCard3(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, bool isSelected) {
    return TextButton(
      onPressed: () {},
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isSelected ? const Color(0xFF535B22) : Colors.grey,
        ),
      ),
    );
  }

  // Realistic demo cards that match actual app data
  Widget _buildReplicaCard1() {
    return Container(
      key: _demoCardKey, // Demo card key
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'INSCHRIJVEN',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
                const Spacer(),
                const Icon(Icons.favorite_border, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'MAP Samenwerkende Continentalen',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF535B22),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Barneveld, Gelderland',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  '18 juli 2025 • 19:00',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Inschrijving vanaf 18-07-2025 19:00',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplicaCard2() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'BINNENKORT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
                const Spacer(),
                const Icon(Icons.favorite_border, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Nederlandse Labrador Vereniging',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF535B22),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Almere, Flevoland',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  '14 juni 2025 • 19:00',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Inschrijving vanaf 14-06-2025 19:00',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplicaCard3() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'INSCHRIJVEN',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
                const Spacer(),
                const Icon(Icons.favorite, color: Colors.red),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Stichting Jachthonden Eemland',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF535B22),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Amersfoort, Utrecht',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  '18 juli 2025 • 19:00',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Inschrijving vanaf 18-07-2025 19:00',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgendaReplicaDemo() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Mijn Agenda'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Color(0xFF535B22).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xFF535B22).withOpacity(0.3)),
              ),
              child: const Text(
                'DEMO',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF535B22),
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildAgendaDemoContent(),
    );
  }

  Widget _buildAgendaDemoContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: ResponsiveHelper.getSpacing(context, 8.0)),
        // Tabs
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: ResponsiveHelper.getSpacing(context, 8.0), 
            vertical: ResponsiveHelper.getSpacing(context, 8.0)
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: ResponsiveHelper.getSpacing(context, 4.0)),
                  padding: EdgeInsets.symmetric(vertical: ResponsiveHelper.getSpacing(context, 8.0)),
                  decoration: BoxDecoration(
                    color: const Color(0xFF535B22),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      'Alle Interesses',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: ResponsiveHelper.getCaptionFontSize(context),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: ResponsiveHelper.getSpacing(context, 4.0)),
                  padding: EdgeInsets.symmetric(vertical: ResponsiveHelper.getSpacing(context, 8.0)),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      'Recent bekeken',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: ResponsiveHelper.getCaptionFontSize(context),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Demo matches list
        Expanded(
          child: ListView(
            padding: EdgeInsets.symmetric(
              horizontal: 0, 
              vertical: ResponsiveHelper.getSpacing(context, 8.0)
            ),
            children: [
              _buildDemoAgendaMatch(
                'Stichting Jachthonden Zuid-Holland',
                '15 Mrt 2025',
                isRegistered: true,
                notificationsOn: true,
                inAgenda: false,
                hasNotes: false,
              ),
              _buildDemoAgendaMatch(
                'KNJV Provincie Gelderland',
                '22 Mrt 2025',
                isRegistered: false,
                notificationsOn: true,
                inAgenda: true,
                hasNotes: true,
              ),
              _buildDemoAgendaMatch(
                'Nederlandse Labrador Vereniging',
                '5 Apr 2025',
                isRegistered: true,
                notificationsOn: false,
                inAgenda: true,
                hasNotes: false,
              ),
              
              // Icon explanation
              Container(
                margin: ResponsiveHelper.getCardMargin(context),
                padding: ResponsiveHelper.getCardPadding(context),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Icoon Betekenis:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        fontSize: ResponsiveHelper.getSubtitleFontSize(context)
                      ),
                    ),
                    SizedBox(height: ResponsiveHelper.getSpacing(context, 8.0)),
                    _buildIconExplanation(Icons.check, Colors.green, 'Ingeschreven'),
                    _buildIconExplanation(Icons.notifications, Colors.orange, 'Meldingen aan'),
                    _buildIconExplanation(Icons.event, Colors.blue, 'In agenda'),
                    _buildIconExplanation(Icons.note_alt, Colors.purple, 'Notities'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDemoAgendaMatch(
    String title,
    String date, {
    required bool isRegistered,
    required bool notificationsOn,
    required bool inAgenda,
    required bool hasNotes,
  }) {
    return Container(
      color: Colors.white,
      padding: ResponsiveHelper.getCardPadding(context),
      child: Row(
        children: [
          // Title and date column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: ResponsiveHelper.getSubtitleFontSize(context),
                  ),
                  maxLines: ResponsiveHelper.isSmallScreen(context) ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: ResponsiveHelper.getSpacing(context, 4.0)),
                Row(
                  children: [
                    Text(
                      date,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: ResponsiveHelper.getCaptionFontSize(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: ResponsiveHelper.getSpacing(context, 12.0)),
                    // Status icons
                    if (isRegistered) ...[
                      Container(
                        width: ResponsiveHelper.getIconSize(context, 24.0),
                        height: ResponsiveHelper.getIconSize(context, 24.0),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.check, color: Colors.green, size: ResponsiveHelper.getIconSize(context, 14.0)),
                      ),
                      SizedBox(width: ResponsiveHelper.getSpacing(context, 6.0)),
                    ],
                    if (notificationsOn) ...[
                      Container(
                        width: ResponsiveHelper.getIconSize(context, 24.0),
                        height: ResponsiveHelper.getIconSize(context, 24.0),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.notifications, color: Colors.orange, size: ResponsiveHelper.getIconSize(context, 14.0)),
                      ),
                      SizedBox(width: ResponsiveHelper.getSpacing(context, 6.0)),
                    ],
                    if (inAgenda) ...[
                      Container(
                        width: ResponsiveHelper.getIconSize(context, 24.0),
                        height: ResponsiveHelper.getIconSize(context, 24.0),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.event, color: Colors.blue, size: ResponsiveHelper.getIconSize(context, 14.0)),
                      ),
                      SizedBox(width: ResponsiveHelper.getSpacing(context, 6.0)),
                    ],
                    if (hasNotes) ...[
                      Container(
                        width: ResponsiveHelper.getIconSize(context, 24.0),
                        height: ResponsiveHelper.getIconSize(context, 24.0),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.note_alt, color: Colors.purple, size: 14),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          
          // Chevron only
          Icon(
            Icons.chevron_right,
            color: Colors.grey[400],
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildIconExplanation(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, [GlobalKey? key]) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF535B22).withOpacity(0.05),
            Color(0xFF535B22).withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF535B22).withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF535B22).withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
                 children: [
           Icon(icon, color: Color(0xFF2A2F14)),
           const SizedBox(width: 12),
           Text(
             label,
             style: const TextStyle(
               color: Color(0xFF2A2F14),
               fontWeight: FontWeight.bold,
               fontSize: 16,
             ),
           ),
         ],
      ),
    );
  }

  // Removed agenda item demo method

  Widget _buildTooltipOverlay(TourStep step) {
    final screenSize = MediaQuery.of(context).size;
    
    print('🎯 DEBUG: Building tooltip overlay for step: ${step.title}');
    
    // Get the actual widget position and size
    final targetRect = _getTargetRect(step.targetKey);
    print('🎯 DEBUG: Got targetRect: $targetRect');
    
    if (targetRect == null) {
      print('🎯 DEBUG: No target rect found, using fallback tooltip');
      // Fallback to center screen if widget not found
      return _buildFallbackTooltip(step, screenSize);
    }
    
    final targetX = targetRect.center.dx;
    final targetY = targetRect.center.dy;
    
    // Improved tooltip positioning calculation for better alignment
    const double tooltipMargin = 20.0;
    const double tooltipMinHeight = 140.0;
    
    // Calculate tooltip position (try to avoid overlapping with target)
    double tooltipY = targetRect.bottom + tooltipMargin;
    bool tooltipBelow = true;
    
    // If tooltip would go off screen, position it above the target
    if (tooltipY + tooltipMinHeight > screenSize.height - 50) {
      tooltipY = targetRect.top - tooltipMinHeight - tooltipMargin;
      tooltipBelow = false;
    }
    
    // Ensure tooltip doesn't go off the top of the screen
    if (tooltipY < 50) {
      tooltipY = 50;
      tooltipBelow = true;
    }
    
    // Calculate connecting line and arrow positions
    final double lineStartY = tooltipBelow ? targetRect.bottom : targetRect.top;
    final double lineEndY = tooltipBelow ? tooltipY - 12 : tooltipY + tooltipMinHeight + 12;
    final double lineHeight = (lineEndY - lineStartY).abs();
    
    // Arrow position - points from line to tooltip
    final double arrowY = tooltipBelow ? tooltipY - 12 : tooltipY + tooltipMinHeight;
    
    return Stack(
      children: [
        // Target rectangular highlight (using actual widget bounds)
        Positioned(
          left: targetRect.left - 6,
          top: targetRect.top - 6,
          child: Container(
            width: targetRect.width + 12,
            height: targetRect.height + 12,
            decoration: BoxDecoration(
              border: Border.all(
                color: const Color(0xFF535B22),
                width: 4,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF535B22).withOpacity(0.6),
                  blurRadius: 12,
                  offset: const Offset(0, 0),
                  spreadRadius: 3,
                ),
                BoxShadow(
                  color: const Color(0xFF535B22).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 0),
                  spreadRadius: 6,
                ),
              ],
            ),
          ),
        ),
        
        // Connecting line from target to tooltip
        if (lineHeight > 0)
        Positioned(
            left: targetX - 1,
            top: lineStartY,
            child: Container(
              width: 2,
              height: lineHeight,
              color: const Color(0xFF535B22).withOpacity(0.7),
          ),
        ),
        
        // Arrow pointing to tooltip
        Positioned(
          left: targetX - 10,
          top: arrowY,
          child: CustomPaint(
            size: const Size(20, 12),
            painter: ArrowPainter(pointingUp: !tooltipBelow),
          ),
        ),
        
        // Instruction box
        Positioned(
      left: 16,
      right: 16,
          top: tooltipY,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF535B22),
                  const Color(0xFF535B22).withOpacity(0.9),
                ],
              ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                  color: const Color(0xFF535B22).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              step.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              step.description,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
                decoration: TextDecoration.none,
              ),
            ),
            if (step.actionText != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  step.actionText!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    decoration: TextDecoration.none,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
        ),
      ],
    );
  }

  Widget _buildFallbackTooltip(TourStep step, Size screenSize) {
    // Provide a fallback tooltip positioned in the center when target not found
    return Positioned(
      left: 16,
      right: 16,
      top: screenSize.height * 0.4,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF535B22),
              const Color(0xFF535B22).withOpacity(0.9),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF535B22).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              step.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              step.description,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
                decoration: TextDecoration.none,
              ),
            ),
            if (step.actionText != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  step.actionText!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    decoration: TextDecoration.none,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Helper methods for dynamic highlighting
  double _getHighlightLeft(TourStep step) {
    if (step.title.contains('Filter')) {
      return MediaQuery.of(context).size.width * 0.65; // Filter button area
    }
    return 16; // Default full width
  }

  double? _getHighlightRight(TourStep step) {
    if (step.title.contains('Filter')) {
      return 16; // Filter button area
    }
    return 16; // Default full width
  }

  double _getHighlightTop(TourStep step, double targetY) {
    if (step.title.contains('Status Overzicht')) {
      return targetY - 5; // Tab bar needs less offset
    }
    return targetY - 10; // Default offset
  }

  double _getHighlightHeight(TourStep step) {
    if (step.title.contains('Filter')) {
      return 45; // Filter button height
    } else if (step.title.contains('Status Overzicht')) {
      return 35; // Tab bar height
    } else if (step.title.contains('Kaarten')) {
      return 120; // Card height
    }
    return 50; // Default button height
  }

  double _getHighlightRadius(TourStep step) {
    if (step.title.contains('Status Overzicht')) {
      return 8; // Tab bar radius
    } else if (step.title.contains('Kaarten')) {
      return 16; // Card radius
    }
    return 12; // Default radius
  }

  Widget _buildProgressIndicator() {
    return Positioned(
      bottom: 100,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF535B22),
              const Color(0xFF535B22).withOpacity(0.9),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF535B22).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.touch_app, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Stap ${currentStep + 1} van ${tourPages[currentPage].steps.length} - Tik om door te gaan',
                    style: TextStyle(
                    color: Colors.white,
                      fontSize: ResponsiveHelper.getCaptionFontSize(context),
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.none,
                  ),
                  textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            AnimatedBuilder(
              animation: _progressAnimation,
              builder: (context, child) {
                return LinearProgressIndicator(
                  value: _progressAnimation.value,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class TourPage {
  final String title;
  final List<TourStep> steps;

  TourPage({required this.title, required this.steps});
}

class TourStep {
  final String title;
  final String description;
  final String targetKey; // Global key identifier instead of position
  final String? actionText;

  TourStep({
    required this.title,
    required this.description,
    required this.targetKey,
    this.actionText,
  });
}

// Custom painter for connecting line
class ConnectingLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF535B22)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // Draw dashed line
    const dashWidth = 5;
    const dashSpace = 3;
    double startY = 0;
    
    while (startY < size.height) {
      canvas.drawLine(
        Offset(0, startY),
        Offset(0, startY + dashWidth),
        paint,
      );
      startY += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// Custom painter for arrow
class ArrowPainter extends CustomPainter {
  final bool pointingUp;

  ArrowPainter({this.pointingUp = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF535B22)
      ..style = PaintingStyle.fill;

    final path = Path();
    
    if (pointingUp) {
      // Create arrow pointing up toward the target
      path.moveTo(size.width / 2, size.height);
      path.lineTo(size.width / 2 - 8, 0);
      path.lineTo(size.width / 2 + 8, 0);
    } else {
    // Create arrow pointing down toward the instruction box
    path.moveTo(size.width / 2, 0);
      path.lineTo(size.width / 2 - 8, size.height);
      path.lineTo(size.width / 2 + 8, size.height);
    }
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// ... existing code ...
// ... existing code ...