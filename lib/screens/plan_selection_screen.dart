import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../services/payment_service.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
import '../utils/last_page_manager.dart';

class PlanSelectionScreen extends StatefulWidget {
  const PlanSelectionScreen({super.key});

  @override
  State<PlanSelectionScreen> createState() => _PlanSelectionScreenState();
}

class _PlanSelectionScreenState extends State<PlanSelectionScreen> {
  bool _isLoading = false;
  String? _selectedPlan;
  final PaymentService _paymentService = PaymentService();
  String? _errorMessage;
  String? _userStatusMessage;
  bool _isProcessingButton = false; // Prevent multiple button taps

  @override
  void initState() {
    super.initState();
    LastPageManager.setLastPage('/plan-selection');
  }
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isVerySmallScreen = screenWidth < 350;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.fromLTRB(isVerySmallScreen ? 6 : 16, 0, isVerySmallScreen ? 6 : 16, 100), // Increased bottom padding to prevent overlap
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kies je abonnement',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: isVerySmallScreen ? 18 : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '14 dagen gratis proefperiode\nDaarna automatische verlenging',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.black54,
                        fontSize: isVerySmallScreen ? 12 : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: isVerySmallScreen ? 6 : 12),
                    // Yearly Plan Card
                    Container(
                      margin: EdgeInsets.symmetric(vertical: isVerySmallScreen ? 4 : 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(isVerySmallScreen ? 7 : 12),
                        border: Border.all(
                          color: _selectedPlan == 'yearly' ? kMainColor : Colors.grey.shade300,
                          width: 2,
                        ),
                      ),
                      child: InkWell(
                        onTap: () => _handlePlanSelection('yearly'),
                        child: Padding(
                          padding: EdgeInsets.all(isVerySmallScreen ? 8 : 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: isVerySmallScreen ? 4 : 8, vertical: isVerySmallScreen ? 2 : 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(isVerySmallScreen ? 10 : 16),
                                ),
                                child: Text(
                                  'AANBEVOLEN - BESPAAR 37%',
                                  style: TextStyle(
                                    color: Colors.deepOrange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: isVerySmallScreen ? 10 : 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '€29,99',
                                    style: TextStyle(
                                      fontSize: isVerySmallScreen ? 15 : 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '/jaar',
                                    style: TextStyle(
                                      fontSize: isVerySmallScreen ? 11 : 14,
                                      color: Colors.grey.shade600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: isVerySmallScreen ? 4 : 8),
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
                    // Debug info (remove in production)
                    if (kDebugMode)
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          'Debug: Selected: $_selectedPlan, Loading: $_isLoading',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ),
                    // Restore Purchases Button - Help users who already own the subscription
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
                          Row(
                            children: [
                              Icon(Icons.restore, color: Colors.blue.shade700, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Heb je al een abonnement?',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                  fontSize: isVerySmallScreen ? 14 : 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Als je al een abonnement hebt gekocht, kun je het hier herstellen.',
                            style: TextStyle(
                              fontSize: isVerySmallScreen ? 12 : 14,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _restorePurchases,
                              icon: const Icon(Icons.restore, color: Colors.white),
                              label: Text(
                                _isLoading ? 'Bezig...' : 'Herstel Aankopen',
                                style: const TextStyle(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade600,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton.icon(
                              onPressed: _isLoading ? null : _troubleshootRestore,
                              icon: const Icon(Icons.build, size: 16),
                              label: const Text(
                                'Problemen met herstellen?',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.blue.shade600,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Error message display
                    if (_errorMessage != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.error_outline, color: Colors.red.shade600, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    // User status message
                    if (_userStatusMessage != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _userStatusMessage!.contains('succesvol') 
                            ? Colors.green.shade50 
                            : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _userStatusMessage!.contains('succesvol') 
                              ? Colors.green.shade200 
                              : Colors.blue.shade200,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _userStatusMessage!.contains('succesvol') 
                                ? Icons.check_circle_outline 
                                : Icons.info_outline,
                              color: _userStatusMessage!.contains('succesvol') 
                                ? Colors.green.shade600 
                                : Colors.blue.shade600,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _userStatusMessage!,
                                style: TextStyle(
                                  color: _userStatusMessage!.contains('succesvol') 
                                    ? Colors.green.shade700 
                                    : Colors.blue.shade700,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
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
                      onPressed: () {
                        print('🔍 Plan Selection: Button pressed! _selectedPlan: $_selectedPlan, _isLoading: $_isLoading');
                        if (_selectedPlan != null && !_isLoading) {
                          print('🔍 Plan Selection: Calling _startTrial');
                          _startTrial();
                        } else {
                          print('🔍 Plan Selection: Button disabled - _selectedPlan: $_selectedPlan, _isLoading: $_isLoading');
                        }
                      },
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
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_selectedPlan != null) ...[
                                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                              _selectedPlan == null ? 'Kies een abonnement' : 'Start Gratis Proefperiode',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                                ),
                              ],
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
    print('🔍 Plan Selection: User selected plan: $plan');
    setState(() => _selectedPlan = plan);
    print('🔍 Plan Selection: _selectedPlan is now: $_selectedPlan');
  }

  Future<void> _startTrial() async {
    print('🔍 Plan Selection: _startTrial called with _selectedPlan: $_selectedPlan');
    if (_selectedPlan == null) {
      print('🔍 Plan Selection: _selectedPlan is null, returning early');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _userStatusMessage = _selectedPlan == 'monthly' 
        ? 'Maandabonnement aanschaffen...' 
        : 'Jaarabonnement aanschaffen...';
    });

    try {
      // Get PaymentService with error handling
      final paymentService = context.read<PaymentService>();
      if (paymentService == null) {
        print('❌ Plan Selection: PaymentService not found in widget tree');
        throw Exception('Payment service not available');
      }
      
      // Use platform-specific product IDs
      final productId = _selectedPlan == 'monthly' 
        ? PaymentService.monthlySubscriptionId 
        : PaymentService.yearlySubscriptionId;
      
      print('🔍 Plan Selection: Calling purchaseSubscriptionWithErrorHandling for product: $productId');
      final result = await paymentService.purchaseSubscriptionWithErrorHandling(
        productId,
        planType: _selectedPlan,
      );

      if (result['success']) {
        setState(() {
          _userStatusMessage = 'Aankoop succesvol! U wordt doorgestuurd...';
        });
        
        if (mounted) {
          await Future.delayed(const Duration(seconds: 2));
          Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false);
        }
      } else {
        setState(() {
          _userStatusMessage = result['userMessage'] ?? 'Aankoop mislukt';
          _errorMessage = context.read<PaymentService>().getUserFriendlyPurchaseErrorMessage(
            result['error'] ?? 'unknown_error'
          );
        });
      }
    } catch (e) {
      print('❌ Plan Selection: Error in _startTrial: $e');
      setState(() {
        _userStatusMessage = 'Er ging iets mis';
        _errorMessage = 'Probeer het opnieuw of neem contact op met support. Fout: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _isLoading = true);

    try {
      print('🔍 Plan Selection: Starting restore purchases');
      
      // Payment service is already initialized in main.dart, no need to initialize again
      
      // Restore purchases with comprehensive result handling and connectivity check
      final result = await _paymentService.restorePurchasesWithConnectivityCheck();
      
      print('🔍 Plan Selection: Restore purchases completed with result: $result');
      
      if (mounted) {
        if (result['success'] == true) {
          if (result['restoredPurchases'] == true || result['navigatedToQuickSetup'] == true) {
            // Successfully restored purchases or navigated to Quick Setup
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_getRestoreSuccessMessage(result)),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 4),
              ),
            );
          } else {
            // No purchases found to restore
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Geen aankopen gevonden om te herstellen. Je kunt een nieuw abonnement starten.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 4),
              ),
            );
          }
        } else {
          // Error occurred
          final errorMessage = result['error'] ?? 'Onbekende fout bij herstellen aankopen';
          
          // Show enhanced error dialog for iOS payment issues
          if (errorMessage.contains('In-app purchases not available on ios')) {
            _showIOSPaymentTroubleshootingDialog();
          } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fout bij herstellen aankopen: $errorMessage'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
          }
        }
      }
      
    } catch (e) {
      print('❌ Plan Selection: Error during restore: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fout bij herstellen aankopen: ${e.toString().replaceAll("Exception: ", "")}'),
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

  String _getRestoreSuccessMessage(Map<String, dynamic> result) {
    final reason = result['details']?['reason'] as String?;
    
    switch (reason) {
      case 'existing_payment_setup':
        return 'Je hebt al een abonnement! Je wordt doorgestuurd naar de app.';
      case 'payment_setup_completed':
        return 'Aankopen succesvol hersteld! Je wordt doorgestuurd naar de app.';
      case 'premium_activated':
        return 'Premium toegang geactiveerd! Je wordt doorgestuurd naar de app.';
      case 'existing_subscription_found':
        return 'Abonnement gevonden en hersteld! Je wordt doorgestuurd naar de app.';
      case 'premium_access_found':
        return 'Premium toegang gevonden! Je wordt doorgestuurd naar de app.';
      default:
        return 'Aankopen hersteld! Als je een abonnement hebt, wordt je automatisch doorgestuurd.';
    }
  }

  Future<void> _troubleshootRestore() async {
    setState(() => _isLoading = true);

    try {
      print('🔍 Plan Selection: Starting restore troubleshooting');
      
      // Get diagnostics
      final diagnostics = await _paymentService.getRestoreDiagnostics();
      
      print('🔍 Plan Selection: Diagnostics: $diagnostics');
      
      if (mounted) {
        // Show diagnostics in a dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text(
              'Diagnose Resultaten',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                Text('Platform: ${diagnostics['platform'] ?? 'Onbekend'}', style: const TextStyle(fontSize: 13)),
                Text('Netwerk: ${diagnostics['networkConnectivity'] == true ? '✅ Verbonden' : '❌ Niet verbonden'}', style: const TextStyle(fontSize: 13)),
                Text('Payment Service: ${diagnostics['paymentServiceAvailable'] == true ? '✅ Beschikbaar' : '❌ Niet beschikbaar'}', style: const TextStyle(fontSize: 13)),
                Text('Producten geladen: ${diagnostics['productsLoaded'] ?? 0}', style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 8),
                const Text('Mogelijke oplossingen:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                const Text('• Controleer je internetverbinding', style: TextStyle(fontSize: 12)),
                const Text('• Zorg dat je ingelogd bent met het juiste Apple ID', style: TextStyle(fontSize: 12)),
                const Text('• Probeer de app opnieuw op te starten', style: TextStyle(fontSize: 12)),
                const Text('• Neem contact op met support als het probleem aanhoudt', style: TextStyle(fontSize: 12)),
                ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Sluiten'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _forceRefreshPaymentService();
                },
                child: const Text('Vernieuwen'),
              ),
            ],
          ),
        );
      }
      
    } catch (e) {
      print('❌ Plan Selection: Error during troubleshooting: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fout bij diagnose: ${e.toString().replaceAll("Exception: ", "")}'),
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

  Future<void> _forceRefreshPaymentService() async {
    setState(() => _isLoading = true);

    try {
      print('🔍 Plan Selection: Force refreshing payment service');
      
      await _paymentService.forceRefreshPaymentService();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment service vernieuwd. Probeer nu opnieuw "Herstel Aankopen".'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      }
      
    } catch (e) {
      print('❌ Plan Selection: Error during force refresh: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fout bij vernieuwen: ${e.toString().replaceAll("Exception: ", "")}'),
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

  void _showIOSPaymentTroubleshootingDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Betalingen Niet Beschikbaar',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'In-app aankopen zijn momenteel niet beschikbaar op uw apparaat.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            ..._paymentService.getIOSTroubleshootingSteps().map((step) => 
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '• $step',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Als het probleem aanhoudt:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            const Text('• App verwijderen en opnieuw installeren via TestFlight', style: TextStyle(fontSize: 13)),
            const Text('• Apparaat opnieuw opstarten', style: TextStyle(fontSize: 13)),
            const Text('• Contact opnemen met support', style: TextStyle(fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Sluiten'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _forceRefreshPaymentService();
            },
            child: const Text('Vernieuwen'),
          ),
        ],
      ),
    );
  }


} 