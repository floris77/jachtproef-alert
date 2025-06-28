import 'package:flutter/material.dart';
import '../utils/constants.dart' as constants;
import 'plan_selection_screen.dart';

class PaymentRequiredScreen extends StatelessWidget {
  const PaymentRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 375;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 20 : 32,
            vertical: isSmallScreen ? 24 : 32,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: isSmallScreen ? 80 : 100,
                height: isSmallScreen ? 80 : 100,
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  Icons.stars,
                  color: Colors.green[700],
                  size: isSmallScreen ? 40 : 50,
                ),
              ),

              SizedBox(height: isSmallScreen ? 24 : 32),

              // Title
              Text(
                'Premium Functie',
                style: TextStyle(
                  fontSize: isSmallScreen ? 24 : 28,
                  fontWeight: FontWeight.bold,
                  color: constants.kMainColor,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: isSmallScreen ? 12 : 16),

              // Message
              Text(
                'Deze functie is alleen beschikbaar voor premium gebruikers.\n\n'
                'Start je gratis proefperiode om direct toegang te krijgen tot alle premium functies.',
                style: TextStyle(
                  fontSize: isSmallScreen ? 16 : 18,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: isSmallScreen ? 32 : 40),

              // Action button
              SizedBox(
                width: double.infinity,
                height: isSmallScreen ? 48 : 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const PlanSelectionScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: constants.kMainColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                  ),
                  child: Text(
                    'Start Gratis Proefperiode',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 16 : 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              SizedBox(height: isSmallScreen ? 16 : 20),

              // Alternative: logout
              TextButton(
                onPressed: () {
                  // Navigate back to onboarding/login
                  Navigator.pushNamedAndRemoveUntil(
                    context, 
                    '/', 
                    (route) => false,
                  );
                },
                child: Text(
                  'Uitloggen',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: isSmallScreen ? 14 : 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 