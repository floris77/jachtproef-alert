import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class AccountCheckScreen extends StatefulWidget {
  const AccountCheckScreen({super.key});

  @override
  State<AccountCheckScreen> createState() => _AccountCheckScreenState();
}

class _AccountCheckScreenState extends State<AccountCheckScreen> {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 375;
    final isVerySmallScreen = screenHeight < 700; // iPhone SE has ~667 points height

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 20 : 32,
              vertical: isSmallScreen ? 16 : 20,
            ),
            child: Column(
              children: [
                // Header - flexible height based on screen size
                Container(
                  padding: EdgeInsets.symmetric(
                    vertical: isVerySmallScreen ? 20 : 40,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: isSmallScreen ? 70 : 90,
                        height: isSmallScreen ? 70 : 90,
                        decoration: BoxDecoration(
                          color: kMainColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.account_circle_outlined,
                          color: kMainColor,
                          size: isSmallScreen ? 35 : 45,
                        ),
                      ),
                      SizedBox(height: isVerySmallScreen ? 12 : (isSmallScreen ? 16 : 24)),
                      Text(
                        'Heb je al een\nJachtProef Alert account?',
                        style: TextStyle(
                          fontSize: isVerySmallScreen ? 20 : (isSmallScreen ? 22 : 26),
                          fontWeight: FontWeight.bold,
                          color: kMainColor,
                          height: 1.1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: isVerySmallScreen ? 6 : (isSmallScreen ? 8 : 12)),
                      Text(
                        'Kies hieronder om in te loggen of\neen nieuw account aan te maken',
                        style: TextStyle(
                          fontSize: isVerySmallScreen ? 13 : (isSmallScreen ? 14 : 16),
                          color: Colors.grey[600],
                          height: 1.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                // Account options - flexible spacing
                Column(
                  children: [
                    // Apple Sign-In has been removed
                    // Use email/password authentication only

                    // Email options row
                    Row(
                      children: [
                        // Login option
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _navigateToLogin(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: kMainColor,
                              padding: EdgeInsets.symmetric(
                                vertical: isVerySmallScreen ? 10 : (isSmallScreen ? 12 : 16),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide(
                                color: kMainColor,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.login,
                                  size: isVerySmallScreen ? 16 : (isSmallScreen ? 18 : 20),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Inloggen',
                                  style: TextStyle(
                                    fontSize: isVerySmallScreen ? 12 : (isSmallScreen ? 13 : 15),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(width: isVerySmallScreen ? 10 : (isSmallScreen ? 12 : 16)),

                        // Create account option
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _navigateToRegister(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: kMainColor,
                              padding: EdgeInsets.symmetric(
                                vertical: isVerySmallScreen ? 10 : (isSmallScreen ? 12 : 16),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide(
                                color: kMainColor,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.person_add,
                                  size: isVerySmallScreen ? 16 : (isSmallScreen ? 18 : 20),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Registreren',
                                  style: TextStyle(
                                    fontSize: isVerySmallScreen ? 12 : (isSmallScreen ? 13 : 15),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Bottom info - flexible spacing
                SizedBox(height: isVerySmallScreen ? 16 : (isSmallScreen ? 24 : 32)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Container(
                    width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[100]!),
                    ),
                    padding: const EdgeInsets.all(12),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                            'Maak gerust een account aan of log in. Je zit nergens aan vast—een abonnement of proefperiode kan pas gestart worden nadat je account gemaakt is',
                            style: const TextStyle(fontSize: 15, color: Colors.black87),
                        ),
                      ),
                    ],
                    ),
                  ),
                ),
                SizedBox(height: isVerySmallScreen ? 12 : (isSmallScreen ? 16 : 24)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToLogin(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const LoginScreen(showOnlyEmailLogin: true),
      ),
    );
  }

  void _navigateToRegister(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const RegisterScreen(),
      ),
    );
  }
} 