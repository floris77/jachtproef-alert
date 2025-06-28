import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import '../services/payment_service.dart';
import '../utils/constants.dart';
import 'account_check_screen.dart';

class WelcomeTrialScreen extends StatefulWidget {
  const WelcomeTrialScreen({super.key});

  @override
  State<WelcomeTrialScreen> createState() => _WelcomeTrialScreenState();
}

class _WelcomeTrialScreenState extends State<WelcomeTrialScreen> 
    with SingleTickerProviderStateMixin {
  final PaymentService _paymentService = PaymentService();
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _goToAccountCheck() {
    // Navigate to account check screen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const AccountCheckScreen(),
      ),
    );
  }

  Future<void> _markWelcomeScreenSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid ?? 'anonymous';
      await prefs.setBool('welcome_trial_screen_seen_$userId', true);
    } catch (e) {
      print('Error marking welcome screen as seen: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 375;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 20 : 32,
                    vertical: isSmallScreen ? 16 : 20,
                  ),
                  child: Column(
                    children: [
                      // Header - compact
                      Container(
                        padding: EdgeInsets.only(top: isSmallScreen ? 8 : 16),
                        child: Column(
                          children: [
                            Container(
                              width: isSmallScreen ? 60 : 70,
                              height: isSmallScreen ? 60 : 70,
                              decoration: BoxDecoration(
                                color: kMainColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(
                                Icons.notifications_active,
                                color: kMainColor,
                                size: isSmallScreen ? 30 : 35,
                              ),
                            ),
                            SizedBox(height: isSmallScreen ? 8 : 12),
                            Text(
                              'Welkom bij\nJachtProef Alert! 🎯',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 20 : 24,
                                fontWeight: FontWeight.bold,
                                color: kMainColor,
                                height: 1.1,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: isSmallScreen ? 4 : 8),
                            Text(
                              'Mis nooit meer een jachtproef!\nKrijg instant alerts voor nieuwe examens.',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 12 : 14,
                                color: Colors.grey[600],
                                height: 1.2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      // Features section - compact
                      Expanded(
                        child: Container(
                          margin: EdgeInsets.symmetric(vertical: isSmallScreen ? 8 : 16),
                          child: Column(
                            children: [
                              Text(
                                'Wat krijg je?',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 16 : 20,
                                  fontWeight: FontWeight.bold,
                                  color: kMainColor,
                                ),
                              ),
                              SizedBox(height: isSmallScreen ? 8 : 12),
                              
                              // Feature list - very compact
                              ...const [
                                ('📱', 'Instant push notificaties'),
                                ('🔍', 'Geavanceerde filters'),
                                ('📅', 'Agenda integratie'),
                                ('🗓️', 'Persoonlijke proefagenda'),
                              ].map((feature) => Padding(
                                padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 3 : 5),
                                child: Row(
                                  children: [
                                    Container(
                                      width: isSmallScreen ? 32 : 40,
                                      height: isSmallScreen ? 32 : 40,
                                      decoration: BoxDecoration(
                                        color: kMainColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Center(
                                        child: Text(
                                          feature.$1,
                                          style: TextStyle(fontSize: isSmallScreen ? 14 : 18),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: isSmallScreen ? 10 : 12),
                                    Expanded(
                                      child: Text(
                                        feature.$2,
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 12 : 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )),

                              const Spacer(),

                              // Trial call-to-action - compact
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.green[200]!,
                                    width: 2,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      '🎉',
                                      style: TextStyle(fontSize: isSmallScreen ? 24 : 30),
                                    ),
                                    SizedBox(height: isSmallScreen ? 4 : 6),
                                    Text(
                                      'Ontgrendel alle functies!',
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 16 : 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green[800],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    SizedBox(height: isSmallScreen ? 2 : 4),
                                    Text(
                                      'Krijg direct toegang tot alle premium mogelijkheden en haal het maximale uit JachtProef Alert.',
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 13 : 15,
                                        color: Colors.green[700],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Button section - always visible
                      Container(
                        padding: EdgeInsets.only(
                          bottom: isSmallScreen ? 8 : 12,
                        ),
                        child: Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: isSmallScreen ? 44 : 52,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _goToAccountCheck,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green[600],
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 8,
                                  shadowColor: Colors.green.withOpacity(0.4),
                                ),
                                child: _isLoading
                                    ? SizedBox(
                                        width: isSmallScreen ? 18 : 22,
                                        height: isSmallScreen ? 18 : 22,
                                        child: const CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        'Direct Aan de Slag!',
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 15 : 17,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),

                            SizedBox(height: isSmallScreen ? 6 : 8),

                            // Fine print - very compact
                            Text(
                              'Risicovrije proefperiode • Altijd opzegbaar\nVeilige betaling via ${Platform.isIOS ? 'App Store' : 'Google Play'}',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 9 : 10,
                                color: Colors.grey[500],
                                height: 1.3,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
} 