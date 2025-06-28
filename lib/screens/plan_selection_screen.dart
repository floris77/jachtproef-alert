import 'dart:io';
import 'package:flutter/material.dart';
import '../services/payment_service.dart';
import '../utils/constants.dart';
import '../utils/responsive_helper.dart';
import '../utils/last_page_manager.dart';
import 'quick_setup_screen.dart';

// Import kMainColor explicitly to avoid ambiguous import
const Color kMainColor = Color(0xFF535B22);

class PlanSelectionScreen extends StatefulWidget {
  const PlanSelectionScreen({super.key});

  @override
  State<PlanSelectionScreen> createState() => _PlanSelectionScreenState();
}

class _PlanSelectionScreenState extends State<PlanSelectionScreen> {
  bool _isLoading = false;
  String? _selectedPlan;
  final PaymentService _paymentService = PaymentService();

  @override
  void initState() {
    super.initState();
    LastPageManager.setLastPage('/plan-selection');
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = ResponsiveHelper.isSmallScreen(context);
    final isIOS = Platform.isIOS;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80), // Added bottom padding for button
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kies je abonnement',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '14 dagen gratis proefperiode\nDaarna automatische verlenging',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Yearly Plan Card
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedPlan == 'yearly' ? kMainColor : Colors.grey.shade300,
                          width: 2,
                        ),
                      ),
                      child: InkWell(
                        onTap: () => _handlePlanSelection('yearly'),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Text(
                                  'AANBEVOLEN - BESPAAR 37%',
                                  style: TextStyle(
                                    color: Colors.deepOrange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    '€29,99',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '/jaar',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Monthly Plan Card
                    _buildPlanCard(
                      title: 'Flexibel maandelijks opzegbaar',
                      price: '€3,99',
                      period: '/maand',
                      onTap: () => _handlePlanSelection('monthly'),
                      isSelected: _selectedPlan == 'monthly',
                    ),
                    const SizedBox(height: 12),
                    // Features Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Wat krijg je met je abonnement?',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildTrialFeature('Onbeperkte exam alerts'),
                          _buildTrialFeature('Prioriteit notificaties'),
                          _buildTrialFeature('Geavanceerde filtering'),
                          _buildTrialFeature('Kalender integratie'),
                          _buildTrialFeature('Exclusieve content'),
                        ],
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '🎉 14 dagen volledig gratis',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildTrialFeature('Geen betaling vereist'),
                          _buildTrialFeature('Direct toegang tot alle functies'),
                          _buildTrialFeature('Altijd opzegbaar'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // DEBUG SECTION - Remove this in production
                    if (true) // Set to false in production
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '🔍 DEBUG: Payment Service Status',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            FutureBuilder<Map<String, dynamic>>(
                              future: _paymentService.getDiagnosticInfo(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return Text('Loading diagnostic info...');
                                }
                                
                                if (snapshot.hasError) {
                                  return Text('Error: ${snapshot.error}');
                                }
                                
                                final diagnostic = snapshot.data ?? {};
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Platform: ${diagnostic['platform'] ?? 'Unknown'}'),
                                    Text('IAP Available: ${diagnostic['iapAvailable'] ?? 'Unknown'}'),
                                    Text('Service Available: ${diagnostic['isAvailable'] ?? false}'),
                                    Text('Products loaded: ${diagnostic['productsLoaded'] ?? 0}'),
                                    const SizedBox(height: 4),
                                    Text('Product IDs requested:'),
                                    ...(diagnostic['productIds'] as List<dynamic>? ?? []).map((id) => 
                                      Text('  • $id')
                                    ),
                                    if (diagnostic['productsLoaded'] == 0) ...[
                                      const SizedBox(height: 4),
                                      Text('❌ No products loaded!', style: TextStyle(color: Colors.red)),
                                      if (diagnostic['productLoadResponse'] != null) ...[
                                        Text('Not found IDs: ${diagnostic['productLoadResponse']['notFoundIDs']}'),
                                        Text('Error: ${diagnostic['productLoadResponse']['error'] ?? 'None'}'),
                                      ],
                                      if (diagnostic['productLoadError'] != null) ...[
                                        Text('Load error: ${diagnostic['productLoadError']}'),
                                      ],
                                    ] else ...[
                                      const SizedBox(height: 4),
                                      Text('Available Products:'),
                                      ...(diagnostic['availableProducts'] as List<dynamic>? ?? []).map((product) => 
                                        Text('  • ${product['id']}: ${product['title']} - ${product['price']}')
                                      ),
                                    ],
                                  ],
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Sticky bottom button
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _selectedPlan != null && !_isLoading ? _startTrial : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              _selectedPlan == null ? 'Kies een abonnement' : 'Start Gratis Proefperiode',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(String feature) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              feature,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String price,
    required String period,
    required VoidCallback onTap,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.shade50 : Colors.white,
          border: Border.all(
            color: isSelected ? Colors.green.shade400 : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  period,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrialFeature(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '•',
            style: TextStyle(
              color: Colors.blue.shade700,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.blue.shade900,
            ),
          ),
        ],
      ),
    );
  }

  void _handlePlanSelection(String plan) {
    setState(() => _selectedPlan = plan);
  }

  Future<void> _startTrial() async {
    if (_selectedPlan == null) return;

    setState(() => _isLoading = true);

    try {
      await _paymentService.startTrialWithPlan(_selectedPlan!);
      
      // The trial setup is now asynchronous - the navigation will happen
      // in the purchase callback when the user confirms the payment.
      // We just show a waiting state.
      print('🔍 Trial purchase flow initiated - waiting for user confirmation...');
      
    } catch (e) {
      // THIS IS THE CRITICAL FIX: Show the error to the user.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fout bij starten proefperiode: ${e.toString().replaceAll("Exception: ", "")}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
} 