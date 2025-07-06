import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';


import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'proeven_main_page.dart';
import 'register_screen.dart';
import 'reset_password_screen.dart';
import '../utils/responsive_helper.dart';
import '../services/payment_service.dart';

class LoginScreen extends StatefulWidget {
  final bool showOnlyEmailLogin;
  
  const LoginScreen({Key? key, this.showOnlyEmailLogin = false}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _scrollController = ScrollController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _userStatusMessage;
  String? _pendingErrorDialog;
  OverlayEntry? _successBanner;

  @override
  void initState() {
    super.initState();
    // Listen to focus changes to scroll to active field
    _emailFocusNode.addListener(_onFocusChange);
    _passwordFocusNode.addListener(_onFocusChange);
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _successBanner?.remove();
    _successBanner = null;
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_emailFocusNode.hasFocus || _passwordFocusNode.hasFocus) {
      // Scroll to show the form fields when keyboard appears
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent * 0.7, // Scroll to 70% to show form
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  void _showErrorDialog(String message) {
    if (_pendingErrorDialog == message) return; // Prevent duplicate dialogs
    _pendingErrorDialog = message;
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text(
          'Inloggen mislukt',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            message,
            style: const TextStyle(fontSize: 14),
            textAlign: TextAlign.left,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () {
              Navigator.of(context).pop();
              _pendingErrorDialog = null;
            },
          ),
        ],
      ),
    );
  }

  void _showSuccessBanner(String message) {
    _successBanner?.remove();
    _successBanner = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 60,
        left: 24,
        right: 24,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.green.shade600,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    Overlay.of(context, rootOverlay: true)?.insert(_successBanner!);
    Future.delayed(const Duration(seconds: 2), () {
      _successBanner?.remove();
      _successBanner = null;
    });
  }

  Future<void> _signInWithEmailAndPassword() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _userStatusMessage = 'Inloggen...';
    });

    try {
      await context.read<AuthService>().signInWithEmailAndPasswordOnly(
        _emailController.text.trim(),
        _passwordController.text,
      );
      
      // Trigger autofill save after successful login
      _triggerAutofillSave();
      
      setState(() {
        _userStatusMessage = 'Succesvol ingelogd!';
      });
      // Show compact success banner
      if (mounted) _showSuccessBanner('Succesvol ingelogd!');
      if (mounted) {
        await Future.delayed(const Duration(seconds: 1));
        await _checkAndNavigateAfterLogin();
      }
    } catch (e) {
      final errorMessage = _getUserFriendlyErrorMessage(e.toString());
      setState(() {
        _userStatusMessage = errorMessage['title'];
        _errorMessage = errorMessage['details'];
      });
      // Show improved error dialog
      _showErrorDialog(errorMessage['details'] ?? 'Onbekende fout');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadSavedCredentials() async {
    print('🔐 [LOGIN] Loading saved credentials...');
    final authService = context.read<AuthService>();
    final creds = await authService.getSavedCredentials();
    if (creds['email'] != null) {
      _emailController.text = creds['email']!;
      print('🔐 [LOGIN] Email loaded: ${creds['email']}');
    }
    if (creds['password'] != null) {
      _passwordController.text = creds['password']!;
      print('🔐 [LOGIN] Password loaded: present');
      // Optionally, auto-login if both are present
      if (creds['email']!.isNotEmpty && creds['password']!.isNotEmpty) {
        print('🔐 [LOGIN] Both email and password present, triggering auto-login...');
        // Wait for the first frame to avoid setState in build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_isLoading) {
            _signInWithEmailAndPassword();
          }
        });
      }
    } else {
      print('🔐 [LOGIN] No saved password found');
    }
  }

  // Trigger autofill after successful login
  void _triggerAutofillSave() {
    // This will trigger the autofill system to save the credentials
    // The autofill hints in the text fields will handle the rest
    print('🔐 [AUTOFILL] Triggering autofill save for credentials');
  }

  Map<String, String> _getUserFriendlyErrorMessage(String error) {
    final errorLower = error.toLowerCase();
    
    if (errorLower.contains('internetverbinding') || errorLower.contains('network')) {
      return {
        'title': 'Geen internetverbinding',
        'details': 'Controleer uw wifi of mobiele data en probeer het opnieuw.',
      };
    } else if (errorLower.contains('user-not-found') || errorLower.contains('geen account')) {
      return {
        'title': 'Account niet gevonden',
        'details': 'Dit email adres is niet geregistreerd. Maak eerst een account aan.',
      };
    } else if (errorLower.contains('wrong-password') || errorLower.contains('ongeldig wachtwoord')) {
      return {
        'title': 'Verkeerd wachtwoord',
        'details': 'Het wachtwoord is niet juist. Probeer het opnieuw of gebruik "Wachtwoord vergeten".',
      };
    } else if (errorLower.contains('invalid-email') || errorLower.contains('ongeldig email')) {
      return {
        'title': 'Ongeldig email adres',
        'details': 'Vul een geldig email adres in (bijvoorbeeld: naam@email.nl).',
      };
    } else if (errorLower.contains('too-many-requests')) {
      return {
        'title': 'Te veel pogingen',
        'details': 'Wacht even en probeer het over een paar minuten opnieuw.',
      };
    } else if (errorLower.contains('user-disabled')) {
      return {
        'title': 'Account uitgeschakeld',
        'details': 'Neem contact op met support voor hulp.',
      };
    } else {
      return {
        'title': 'Inloggen mislukt',
        'details': 'Controleer uw email en wachtwoord en probeer het opnieuw.',
      };
    }
  }

  Future<void> _checkAndNavigateAfterLogin() async {
    setState(() { _isLoading = true; });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Ensure PaymentService is initialized
      await PaymentService().initialize();

      // Check if user has selected a plan or has premium access in Firestore
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      bool hasPremium = false;
      if (doc.exists) {
        final data = doc.data();
        final selectedPlan = data?['selectedPlan'];
        final isPremium = data?['isPremium'] == true;
        final paymentSetupCompleted = data?['paymentSetupCompleted'] == true;
        hasPremium = (selectedPlan != null && selectedPlan.toString().isNotEmpty) || isPremium || paymentSetupCompleted;
      }
      // Debug log
      print('🔍 LOGIN DEBUG: Firestore hasPremium=$hasPremium');

      if (!hasPremium) {
        // Fallback: check PaymentService directly for premium access
        try {
          final paymentServicePremium = await PaymentService().hasPremiumAccess();
          print('🔍 LOGIN DEBUG: PaymentService hasPremiumAccess=$paymentServicePremium');
          if (paymentServicePremium) {
            hasPremium = true;
          }
        } catch (e) {
          print('🔍 LOGIN DEBUG: Error checking PaymentService premium: $e');
        }
      }

      if (hasPremium) {
        // User has premium access, go to main flow
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
        return;
      }
      // User hasn't selected a plan and has no premium, go to plan selection
      Navigator.pushNamedAndRemoveUntil(context, '/plan-selection', (route) => false);
    } catch (e) {
      print('Error checking user plan/premium: $e');
      // Fallback to main flow if there's an error
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: widget.showOnlyEmailLogin ? CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemGrey6,
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Icon(CupertinoIcons.back, color: CupertinoColors.activeBlue),
        ),
        middle: const Text(
          'Inloggen',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ) : null,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: ResponsiveHelper.isTablet(context) ? 500.0 : double.infinity,
            ),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveHelper.getHorizontalPadding(context),
                vertical: ResponsiveHelper.getVerticalPadding(context),
              ),
              child: Form(
                key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                    // Logo and welcome text
                    if (!widget.showOnlyEmailLogin) ...[
                      const SizedBox(height: 40),
                      Container(
                        width: 120,
                        height: 120,
                            decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32),
                          borderRadius: BorderRadius.circular(24),
                            ),
                        child: const Icon(
                          CupertinoIcons.location_circle_fill,
                          color: Colors.white,
                          size: 60,
                                    ),
                                  ),
                      const SizedBox(height: 24),
                      Text(
                        'Welkom bij JachtProef Alert',
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getTitleFontSize(context),
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Blijf op de hoogte van jachtproeven in Nederland',
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getBodyFontSize(context),
                          color: CupertinoColors.systemGrey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                      const SizedBox(height: 40),
                    ] else ...[
                      const SizedBox(height: 20),
                    ],
                    
                    // Status messages
                    if (_userStatusMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: _userStatusMessage!.contains('Controleer de ingevoerde gegevens') 
                              ? CupertinoColors.systemRed.withOpacity(0.1)
                              : _userStatusMessage!.contains('succesvol') 
                                  ? CupertinoColors.systemGreen.withOpacity(0.1)
                                  : CupertinoColors.systemBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _userStatusMessage!.contains('Controleer de ingevoerde gegevens') 
                                ? CupertinoColors.systemRed
                                : _userStatusMessage!.contains('succesvol') 
                                    ? CupertinoColors.systemGreen
                                    : CupertinoColors.systemBlue,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _userStatusMessage!.contains('Controleer de ingevoerde gegevens') 
                                  ? CupertinoIcons.exclamationmark_triangle
                                  : _userStatusMessage!.contains('succesvol') 
                                      ? CupertinoIcons.checkmark_circle
                                      : CupertinoIcons.info_circle, 
                              color: _userStatusMessage!.contains('Controleer de ingevoerde gegevens') 
                                  ? CupertinoColors.systemRed
                                  : _userStatusMessage!.contains('succesvol') 
                                      ? CupertinoColors.systemGreen
                                      : CupertinoColors.systemBlue,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _userStatusMessage!,
                                style: TextStyle(
                                  color: _userStatusMessage!.contains('Controleer de ingevoerde gegevens') 
                                      ? CupertinoColors.systemRed
                                      : _userStatusMessage!.contains('succesvol') 
                                          ? CupertinoColors.systemGreen
                                          : CupertinoColors.systemBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemRed.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: CupertinoColors.systemRed),
                                ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: CupertinoColors.systemRed),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    
                    // Email field
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: AutofillGroup(
                        child: TextFormField(
                          controller: _emailController,
                          focusNode: _emailFocusNode,
                          decoration: InputDecoration(
                            hintText: 'Email',
                            filled: true,
                            fillColor: CupertinoColors.systemGrey6,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: CupertinoColors.systemGrey4),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: CupertinoColors.systemGrey4),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: CupertinoColors.activeBlue),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.username],
                          onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
                        ),
                      ),
                    ),
                    
                    // Password field
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      child: TextFormField(
                        controller: _passwordController,
                        focusNode: _passwordFocusNode,
                        decoration: InputDecoration(
                          hintText: 'Wachtwoord',
                          filled: true,
                          fillColor: CupertinoColors.systemGrey6,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: CupertinoColors.systemGrey4),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: CupertinoColors.systemGrey4),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: CupertinoColors.activeBlue),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _signInWithEmailAndPassword(),
                      ),
                    ),
                      
                    // Login button
                    CupertinoButton(
                      color: const Color(0xFF2E7D32),
                            borderRadius: BorderRadius.circular(12),
                      onPressed: _isLoading ? null : _signInWithEmailAndPassword,
                      child: _isLoading
                          ? const CupertinoActivityIndicator(color: Colors.white)
                          : const Text(
                              'Inloggen',
                                style: TextStyle(
                                color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                                  ),
                    
                    const SizedBox(height: 16),
                      
                    // Forgot password link
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ResetPasswordScreen()),
                            );
                          },
                      child: const Text(
                        'Wachtwoord vergeten?',
                        style: TextStyle(
                          color: CupertinoColors.activeBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    
                    if (!widget.showOnlyEmailLogin) ...[
                      const SizedBox(height: 32),
                      
                      // Divider
                      Row(
                        children: [
                          Expanded(child: Container(height: 1, color: CupertinoColors.systemGrey4)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                              'OF',
                              style: TextStyle(
                                color: CupertinoColors.systemGrey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(child: Container(height: 1, color: CupertinoColors.systemGrey4)),
                        ],
                            ),
                      
                      const SizedBox(height: 32),
                      
                      // Register button
                      CupertinoButton(
                        color: CupertinoColors.systemGrey6,
                        borderRadius: BorderRadius.circular(12),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const RegisterScreen()),
                          );
                        },
                        child: const Text(
                          'Account Aanmaken',
                                style: TextStyle(
                            color: CupertinoColors.activeBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                                ),
                              ),
                            ],
                    
                    const SizedBox(height: 40),
                      ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
} 