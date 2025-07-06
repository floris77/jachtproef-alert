import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/proeven_main_page.dart';
import 'screens/quick_setup_screen.dart';
import 'screens/welcome_trial_screen.dart';
import 'screens/account_check_screen.dart';
import 'screens/payment_required_screen.dart';
import 'screens/plan_selection_screen.dart';
import 'services/auth_service.dart';
import 'services/payment_service.dart';
import 'services/notification_service.dart';
import 'services/deep_link_service.dart';
import 'services/debug_logging_service.dart';
import 'firebase_options.dart';
import 'package:jachtproef_alert/utils/last_page_manager.dart';
import 'dart:async';
import 'package:jachtproef_alert/screens/home_screen.dart';
import 'package:jachtproef_alert/screens/login_screen.dart';
import 'package:jachtproef_alert/services/performance_monitor.dart';
import 'services/match_actions_provider.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('nl_NL', null);

  // Start performance monitoring early
  PerformanceMonitor().startMonitoring();
  PerformanceMonitor().logAppStartup();

  // Initialize debug logging service first
  await DebugLoggingService().initialize();
  DebugLoggingService().info('🚀 App starting up...', tag: 'STARTUP');

  // Don't call PaymentService before initialization - this could cause issues
  // PaymentService().clearNavigationFlag();
  DebugLoggingService().info('🧹 Skipping early PaymentService call', tag: 'STARTUP');

  // Set system UI overlay style for edge-to-edge support
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  DebugLoggingService().info('🎨 System UI overlay style configured', tag: 'STARTUP');

  // Initialize services in parallel for better startup performance
  try {
    DebugLoggingService().info('🔥 Initializing Firebase...', tag: 'FIREBASE');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Initialize Firebase services in parallel
    await Future.wait([
      _initializeFirebaseAnalytics(),
      _initializeFirebasePerformance(),
      _initializeFirebaseCrashlytics(),
    ]);
    
    DebugLoggingService().info('✅ Firebase initialization completed successfully', tag: 'FIREBASE');
  } catch (e) {
    DebugLoggingService().error('❌ Firebase initialization failed: $e', tag: 'FIREBASE');
    print('Firebase initialization failed: $e');
    // Continue anyway to see what happens
  }

  // Initialize other services in parallel
  await Future.wait([
    _initializePaymentService(),
    _initializeDeepLinkService(),
    _initializeNotificationService(),
  ]);

  // CRITICAL: Do NOT call _clearDeviceStateOnStartup() here
  // This method calls PaymentService().cleanupOldDormantPayments() which
  // completely resets the PaymentService state (_isAvailable = false, _inAppPurchase = null)
  // after it was successfully initialized, breaking the payment flow.
  // 
  // The cleanup is only needed for debugging/testing, not normal app startup.
  // If cleanup is needed, it should be done manually via debug settings.
  DebugLoggingService().info('🚫 Skipping device state cleanup to preserve PaymentService initialization', tag: 'STARTUP');

  DebugLoggingService().info('🎉 All services initialized, starting app...', tag: 'STARTUP');
  PerformanceMonitor().endTrace('app_startup');
  
  // CRITICAL: Use the SAME PaymentService instance that was initialized
  // PaymentService uses singleton pattern, so this gets the initialized instance
  // ChangeNotifierProvider.value() ensures the widget tree uses this instance
  final paymentService = PaymentService();
  paymentService.clearNavigationFlag();
  DebugLoggingService().info('✅ Using initialized PaymentService instance in Provider', tag: 'STARTUP');
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
        final provider = MatchActionsProvider();
        provider.loadAllActions();
        return provider;
        }),
        ChangeNotifierProvider.value(value: paymentService),
        Provider<AuthService>(create: (_) => AuthService()),
      ],
      child: const MyApp(),
    ),
  );
}

Future<void> _initializeFirebaseAnalytics() async {
  FirebaseAnalytics.instance;
  DebugLoggingService().info('📊 Firebase Analytics initialized', tag: 'FIREBASE');
}

Future<void> _initializeFirebasePerformance() async {
  FirebasePerformance performance = FirebasePerformance.instance;
  await performance.setPerformanceCollectionEnabled(true);
  DebugLoggingService().info('⏱️ Firebase Performance initialized', tag: 'FIREBASE');
}

Future<void> _initializeFirebaseCrashlytics() async {
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
  DebugLoggingService().info('🛡️ Firebase Crashlytics initialized', tag: 'FIREBASE');
}

Future<void> _initializePaymentService() async {
  try {
    DebugLoggingService().info('💳 Initializing Payment Service...', tag: 'PAYMENT');
    await PaymentService().initialize();
    DebugLoggingService().info('✅ Payment Service initialized successfully', tag: 'PAYMENT');
  } catch (e) {
    DebugLoggingService().error('❌ Payment Service initialization FAILED: $e', tag: 'PAYMENT');
    print('❌ Payment Service initialization FAILED: $e');
    // Don't continue silently - this is critical for the app to work
    rethrow;
  }
}

Future<void> _initializeDeepLinkService() async {
  try {
    DebugLoggingService().info('🔗 Initializing Deep Link Service...', tag: 'DEEPLINK');
    await DeepLinkService.initialize();
    DebugLoggingService().info('✅ Deep Link Service initialized successfully', tag: 'DEEPLINK');
  } catch (e) {
    DebugLoggingService().error('❌ Deep Link Service initialization warning: $e', tag: 'DEEPLINK');
    print('Deep Link Service initialization warning: $e');
    // Continue even if Deep Link Service fails to initialize
  }
}

Future<void> _initializeNotificationService() async {
  try {
    DebugLoggingService().info('🔔 Initializing Notification Service...', tag: 'NOTIFICATION');
    await NotificationService.initialize();
    DebugLoggingService().info('✅ Notification Service initialized successfully', tag: 'NOTIFICATION');
  } catch (e) {
    DebugLoggingService().error('❌ Notification Service initialization warning: $e', tag: 'NOTIFICATION');
    print('Notification Service initialization warning: $e');
    // Continue even if Notification Service fails to initialize
  }
}

/// Clear device state on app startup for clean testing
/// 
/// ⚠️ WARNING: This method is DANGEROUS and should NOT be called during normal startup!
/// It calls cleanupOldDormantPayments() which completely resets the PaymentService state.
/// 
/// This was the root cause of the payment dialog not appearing issue:
/// 1. PaymentService initializes successfully (_isAvailable = true, products loaded)
/// 2. This method calls cleanupOldDormantPayments()
/// 3. PaymentService state is reset (_isAvailable = false, _inAppPurchase = null)
/// 4. Payment flow fails with "payment_not_available" error
/// 
/// Use only for debugging/testing, never in production startup.
Future<void> _clearDeviceStateOnStartup() async {
  try {
    print('🔄 Clearing device state on startup...');
    print('⚠️ WARNING: This will break PaymentService! Only use for debugging!');
    
    // Enhanced cleanup for old/dormant payments (especially important for TestFlight)
    await PaymentService().cleanupOldDormantPayments();
    
    print('✅ Device state cleared on startup');
  } catch (e) {
    print('⚠️ Could not clear device state on startup: $e');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // PaymentService is already initialized in main() function
    // No need to initialize it again here
  }

  @override
  Widget build(BuildContext context) {
    return DeepLinkListener(
        child: MaterialApp(
        title: 'JachtProef Alert',
        debugShowCheckedModeBanner: false,
        routes: {
          '/main': (context) => const ProevenMainPage(),
          '/welcome': (context) => const WelcomeTrialScreen(),
          '/plan-selection': (context) => const PlanSelectionScreen(),
        },
        theme: ThemeData(
          primaryColor: kMainColor,
          colorScheme: ColorScheme.fromSeed(
            seedColor: kMainColor,
            primary: kMainColor,
            secondary: kMainColor,
            background: Colors.white,
            surface: Colors.white,
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: Colors.white,
          cardColor: Colors.white,
          switchTheme: SwitchThemeData(
            thumbColor: MaterialStateProperty.all(kMainColor),
            trackColor: MaterialStateProperty.all(kMainColor.withOpacity(0.5)),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: kMainColor,
              foregroundColor: Colors.white,
              textStyle: const TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.none),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          textTheme: const TextTheme(
            bodyLarge: TextStyle(decoration: TextDecoration.none),
            bodyMedium: TextStyle(decoration: TextDecoration.none),
            bodySmall: TextStyle(decoration: TextDecoration.none),
            titleLarge: TextStyle(decoration: TextDecoration.none),
            titleMedium: TextStyle(decoration: TextDecoration.none),
            titleSmall: TextStyle(decoration: TextDecoration.none),
            labelLarge: TextStyle(decoration: TextDecoration.none),
            labelMedium: TextStyle(decoration: TextDecoration.none),
            labelSmall: TextStyle(decoration: TextDecoration.none),
          ),
          fontFamily: 'Arial',
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isNavigating = false;
  bool _hasNavigatedToQuickSetup = false;

  @override
  void initState() {
    super.initState();
    
    // Reset navigation state on app startup and disable the state-restoration timer
    PaymentService().clearNavigationFlag();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    return Consumer<PaymentService>(
      builder: (context, paymentService, _) {
        return StreamBuilder<User?>(
          stream: authService.authStateChanges,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.active) {
              final User? user = snapshot.data;
              if (user == null) {
                // Check if user has seen onboarding first
                return FutureBuilder<bool>(
                  future: _hasSeenOnboarding(),
                  builder: (context, onboardingSnapshot) {
                    if (onboardingSnapshot.connectionState == ConnectionState.waiting) {
                      return const Scaffold(body: Center(child: CircularProgressIndicator()));
                    }

                    final hasSeenOnboarding = onboardingSnapshot.data ?? false;

                    if (hasSeenOnboarding) {
                      // User has seen onboarding, show account check
                      return const AccountCheckScreen();
                    } else {
                      // User hasn't seen onboarding, show onboarding first
                      return const OnboardingScreen();
                    }
                  },
                );
              }

              // User is logged in - check their subscription status and route accordingly
              return FutureBuilder<bool>(
                future: paymentService.hasCompletedPaymentSetup(),
                builder: (context, paymentSnapshot) {
                  if (paymentSnapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(body: Center(child: CircularProgressIndicator()));
                  }

                  final hasCompletedPaymentSetup = paymentSnapshot.data ?? false;

                  if (hasCompletedPaymentSetup) {
                    // Payment is done. Now, we MUST check if setup is also done.
                    return FutureBuilder<bool>(
                      future: _hasCompletedQuickSetup(), // Check our persistent flag
                      builder: (context, setupSnapshot) {
                        if (setupSnapshot.connectionState == ConnectionState.waiting) {
                          return const Scaffold(body: Center(child: CircularProgressIndicator()));
                        }

                        final hasCompletedSetup = setupSnapshot.data ?? false;

                        // Check if payment service is requesting navigation to Quick Setup
                        if (paymentService.shouldNavigateToQuickSetup) {
                          // Clear the flag and navigate to Quick Setup
                          paymentService.clearNavigationFlag();
                          return const QuickSetupScreen();
                        }

                        if (hasCompletedSetup) {
                          // Both payment and setup are done. Go to the main app.
                          // This prevents the setup loop.
                          return const ProevenMainPage();
                        } else {
                          // Payment is done, but setup is NOT.
                          // Send them to Quick Setup. This handles new users and users who quit before setup.
                          return const QuickSetupScreen();
                        }
                      },
                    );
                  } else {
                    // User is logged in but hasn't completed payment setup - go to plan selection
                    return const PlanSelectionScreen();
                  }
                },
              );
            }

            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          },
        );
      },
    );
  }

  Future<bool> _hasCompletedQuickSetup() async {
    final prefs = await SharedPreferences.getInstance();
    // We need to get the user without causing a rebuild loop, so listen: false
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user == null) {
      return false;
    }
    final userId = user.uid;
    
    // Check the persistent flag that is set at the end of the QuickSetupScreen
    final localFlag = prefs.getBool('quick_setup_completed_$userId') ?? false;
    
    // Also check Firestore flag for consistency
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      final firestoreFlag = doc.data()?['quickSetupCompleted'] == true;
      
      print('🔍 [QUICK SETUP CHECK] User: $userId, Local flag: $localFlag, Firestore flag: $firestoreFlag');
      
      // If Firestore flag is true, also set the local flag for consistency
      if (firestoreFlag && !localFlag) {
        print('🔍 [QUICK SETUP CHECK] Setting local flag to match Firestore');
        await prefs.setBool('quick_setup_completed_$userId', true);
      }
      
      // If either flag is true, consider Quick Setup completed
      final result = localFlag || firestoreFlag;
      print('🔍 [QUICK SETUP CHECK] Final result: $result');
      return result;
    } catch (e) {
      // If Firestore check fails, fall back to local flag
      print('⚠️ Error checking Firestore Quick Setup flag: $e');
      return localFlag;
    }
  }
  
  Future<bool> _hasSeenOnboarding() async {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('onboarding_completed') ?? false;
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 375;
    final isShortScreen = screenHeight < 700;
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 20 : 24,
            vertical: isShortScreen ? 16 : 24,
          ),
        child: Column(
          children: [
            Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App Icon
                    Container(
                      width: isSmallScreen ? 100 : 120,
                      height: isSmallScreen ? 100 : 120,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF535B22),
                            const Color(0xFF535B22).withOpacity(0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF535B22).withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/images/app_icon.png',
                          width: isSmallScreen ? 80 : 100,
                          height: isSmallScreen ? 80 : 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    
                    SizedBox(height: isShortScreen ? 32 : 48),
                    
                    // Title
                    Text(
                      'Jachtproef Alert',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 28 : 32,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF535B22),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    SizedBox(height: isShortScreen ? 12 : 16),
                    
                    // Subtitle
                    Text(
                      'Alle jachtproeven in Nederland\nop één plek',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 16 : 18,
                        color: Colors.grey[600],
                        height: 1.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    SizedBox(height: isShortScreen ? 32 : 48),
                    
                    // Simple feature list
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF535B22).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF535B22).withOpacity(0.1),
                        ),
                      ),
                      child: Column(
                          children: [
                          _buildFeatureItem(
                            Icons.list_alt,
                            'Overzicht van alle proeven',
                            isSmallScreen,
                          ),
                          SizedBox(height: isSmallScreen ? 12 : 16),
                          _buildFeatureItem(
                            Icons.notifications_outlined,
                            'Meldingen voor deadlines',
                            isSmallScreen,
                              ),
                          SizedBox(height: isSmallScreen ? 12 : 16),
                          _buildFeatureItem(
                            Icons.calendar_today,
                            'Agenda synchronisatie',
                            isSmallScreen,
                            ),
                          ],
                        ),
                    ),
                  ],
              ),
            ),
            
              // Get Started Button
              Container(
                width: double.infinity,
                margin: EdgeInsets.only(bottom: isShortScreen ? 16 : 24),
                child: ElevatedButton(
                  onPressed: () async {
                    // Mark onboarding as completed
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('onboarding_completed', true);
                    
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const AccountCheckScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF535B22),
                    foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                      vertical: isSmallScreen ? 16 : 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    'Aan de Slag',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 16 : 18,
                      fontWeight: FontWeight.bold,
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
  
  Widget _buildFeatureItem(IconData icon, String text, bool isSmallScreen) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
        decoration: BoxDecoration(
            color: const Color(0xFF535B22).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: isSmallScreen ? 18 : 20,
            color: const Color(0xFF535B22),
          ),
        ),
        SizedBox(width: isSmallScreen ? 12 : 16),
        Expanded(
      child: Text(
        text, 
        style: TextStyle(
          fontSize: isSmallScreen ? 14 : 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}


