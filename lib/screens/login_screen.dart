import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'proeven_main_page.dart';
import 'register_screen.dart';
import 'reset_password_screen.dart';
import '../utils/responsive_helper.dart';

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

  @override
  void initState() {
    super.initState();
    // Listen to focus changes to scroll to active field
    _emailFocusNode.addListener(_onFocusChange);
    _passwordFocusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
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

  Future<void> _signInWithEmailAndPassword() async {
    setState(() {
      _userStatusMessage = 'Inloggen...';
    });
    
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // First try to sign in
      await context.read<AuthService>().signInWithEmailAndPasswordOnly(
        _emailController.text.trim(),
        _passwordController.text,
      );
      setState(() {
        _userStatusMessage = 'Succesvol ingelogd!';
      });
      if (mounted) {
        await Future.delayed(const Duration(seconds: 1));
        // Check if user has selected a plan, if not redirect to plan selection
        await _checkAndNavigateAfterLogin();
      }
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      
      // Check if the error is due to user not found
      if (errorStr.contains('user-not-found') || 
          errorStr.contains('no user record') ||
          errorStr.contains('there is no user')) {
        
        setState(() {
          _userStatusMessage = 'Account niet gevonden. Ga naar registreren om een account aan te maken.';
          _errorMessage = 'Geen account gevonden. Klik op "Account Aanmaken" om een nieuw account aan te maken.';
        });
      } else if (errorStr.contains('wrong-password') || errorStr.contains('invalid-credential')) {
        setState(() {
          _userStatusMessage = 'Verkeerd wachtwoord ingevoerd.';
          _errorMessage = 'Het wachtwoord is niet juist. Probeer het opnieuw of klik op "Wachtwoord vergeten?".';
        });
      } else if (errorStr.contains('invalid-email')) {
        setState(() {
          _userStatusMessage = 'Email adres is niet geldig.';
          _errorMessage = 'Vul een geldig email adres in (bijvoorbeeld: naam@email.nl).';
        });
      } else if (errorStr.contains('network')) {
        setState(() {
          _userStatusMessage = 'Geen internetverbinding.';
          _errorMessage = 'Controleer uw internetverbinding en probeer het opnieuw.';
        });
      } else {
        // Simplified generic error
        setState(() {
          _userStatusMessage = 'Inloggen mislukt. Controleer uw gegevens en probeer opnieuw.';
          _errorMessage = 'Er ging iets mis. Controleer uw email en wachtwoord.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }



  Future<void> _checkAndNavigateAfterLogin() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Check if user has selected a plan in Firestore
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        final selectedPlan = data?['selectedPlan'];
        
        if (selectedPlan != null && selectedPlan.isNotEmpty) {
          // User has already selected a plan, go to main flow
          Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
          return;
        }
      }
      
      // User hasn't selected a plan yet, go to plan selection
      Navigator.pushNamedAndRemoveUntil(context, '/plan-selection', (route) => false);
    } catch (e) {
      print('Error checking user plan: $e');
      // Fallback to main flow if there's an error
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: widget.showOnlyEmailLogin ? AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).primaryColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Inloggen',
          style: TextStyle(
            color: Theme.of(context).primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ) : null,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
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
              controller: _scrollController,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height - 
                             MediaQuery.of(context).padding.top - 
                             MediaQuery.of(context).padding.bottom -
                             MediaQuery.of(context).viewInsets.bottom,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_userStatusMessage != null)
                        Padding(
                          padding: EdgeInsets.only(bottom: ResponsiveHelper.getSpacing(context, 8.0)),
                          child: Container(
                            padding: ResponsiveHelper.getCardPadding(context),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green, width: 1),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info, 
                                     color: Colors.green, 
                                     size: ResponsiveHelper.getIconSize(context, 20.0)),
                                SizedBox(width: ResponsiveHelper.getSpacing(context, 8.0)),
                                Expanded(
                                  child: Text(
                                    _userStatusMessage!,
                                    style: ResponsiveHelper.getResponsiveTextStyle(
                                      context,
                                      const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ResponsiveHelper.getResponsiveSpacing(context, 16.0),
                      Text(
                        'JachtProef Alert',
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getTitleFontSize(context),
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      ResponsiveHelper.getResponsiveSpacing(context, 40.0),
                      if (_errorMessage != null)
                        Padding(
                          padding: EdgeInsets.only(bottom: ResponsiveHelper.getSpacing(context, 16.0)),
                          child: Text(
                            _errorMessage!,
                            style: ResponsiveHelper.getResponsiveTextStyle(
                              context,
                              const TextStyle(color: Colors.red),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      // Email form section
                      // Container(
                      //   padding: EdgeInsets.symmetric(horizontal: ResponsiveHelper.getSpacing(context, 8.0)),
                      //   child: Text(
                      //     'of', 
                      //     style: ResponsiveHelper.getResponsiveTextStyle(
                      //       context,
                      //       TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold),
                      //     ),
                      //   ),
                      // ),
                      ResponsiveHelper.getResponsiveSpacing(context, 24.0),
                      
                      // Help text for users
                      Container(
                        padding: EdgeInsets.all(ResponsiveHelper.getSpacing(context, 12.0)),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!, width: 1),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, 
                                 color: Colors.grey[600], 
                                 size: ResponsiveHelper.getIconSize(context, 18.0)),
                            SizedBox(width: ResponsiveHelper.getSpacing(context, 8.0)),
                            Expanded(
                              child: Text(
                                widget.showOnlyEmailLogin 
                                    ? 'Log in met uw email adres en wachtwoord'
                                    : 'Voer uw email adres en wachtwoord in om in te loggen',
                                style: ResponsiveHelper.getResponsiveTextStyle(
                                  context,
                                  TextStyle(color: Colors.grey[700], fontSize: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      ResponsiveHelper.getResponsiveSpacing(context, 16.0),
                      
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                labelText: 'Uw email adres',
                                hintText: 'bijvoorbeeld: naam@email.nl',
                                hintStyle: TextStyle(fontSize: ResponsiveHelper.getBodyFontSize(context)),
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: ResponsiveHelper.getHorizontalPadding(context),
                                  vertical: ResponsiveHelper.getVerticalPadding(context) * 0.75,
                                ),
                              ),
                              style: TextStyle(fontSize: ResponsiveHelper.getBodyFontSize(context)),
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Vul uw email adres in';
                                }
                                if (!value.contains('@')) {
                                  return 'Vul een geldig email adres in (bijvoorbeeld: naam@email.nl)';
                                }
                                return null;
                              },
                              focusNode: _emailFocusNode,
                            ),
                            ResponsiveHelper.getResponsiveSpacing(context, 16.0),
                            TextFormField(
                              controller: _passwordController,
                              decoration: InputDecoration(
                                labelText: 'Uw wachtwoord',
                                hintText: 'Minimaal 6 tekens',
                                hintStyle: TextStyle(fontSize: ResponsiveHelper.getBodyFontSize(context)),
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: ResponsiveHelper.getHorizontalPadding(context),
                                  vertical: ResponsiveHelper.getVerticalPadding(context) * 0.75,
                                ),
                              ),
                              style: TextStyle(fontSize: ResponsiveHelper.getBodyFontSize(context)),
                              obscureText: true,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Vul uw wachtwoord in';
                                }
                                if (value.length < 6) {
                                  return 'Wachtwoord moet minimaal 6 tekens bevatten';
                                }
                                return null;
                              },
                              focusNode: _passwordFocusNode,
                            ),
                          ],
                        ),
                      ),
                      ResponsiveHelper.getResponsiveSpacing(context, 24.0),
                      SizedBox(
                        width: double.infinity,
                        height: ResponsiveHelper.getButtonHeight(context),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _signInWithEmailAndPassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  height: ResponsiveHelper.getIconSize(context, 20.0),
                                  width: ResponsiveHelper.getIconSize(context, 20.0),
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(
                                  'Inloggen', 
                                  style: TextStyle(
                                    fontSize: ResponsiveHelper.getBodyFontSize(context), 
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      
                      ResponsiveHelper.getResponsiveSpacing(context, 16.0),
                      
                      // Only show registration option if not in focused email-only mode
                      if (!widget.showOnlyEmailLogin)
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(ResponsiveHelper.getSpacing(context, 16.0)),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue[200]!, width: 2),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.person_add,
                                color: Colors.blue[700],
                                size: ResponsiveHelper.getIconSize(context, 32.0),
                              ),
                              SizedBox(height: ResponsiveHelper.getSpacing(context, 8.0)),
                              Text(
                                'Nog geen account?',
                                style: TextStyle(
                                  fontSize: ResponsiveHelper.getSubtitleFontSize(context),
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[900],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: ResponsiveHelper.getSpacing(context, 4.0)),
                              Text(
                                'Maak gratis een account aan om aan de slag te gaan!',
                                style: TextStyle(
                                  fontSize: ResponsiveHelper.getBodyFontSize(context),
                                  color: Colors.blue[700],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: ResponsiveHelper.getSpacing(context, 12.0)),
                              SizedBox(
                                width: double.infinity,
                                height: ResponsiveHelper.getButtonHeight(context),
                                child: ElevatedButton.icon(
                                  icon: Icon(
                                    Icons.person_add,
                                    size: ResponsiveHelper.getIconSize(context, 20.0),
                                  ),
                                  label: Text(
                                    'Account Aanmaken',
                                    style: TextStyle(
                                      fontSize: ResponsiveHelper.getBodyFontSize(context),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue[600],
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: _isLoading ? null : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const RegisterScreen()),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      ResponsiveHelper.getResponsiveSpacing(context, 20.0),
                      
                      // Forgot password link - made more pronounced
                      Container(
                        padding: EdgeInsets.symmetric(
                          vertical: ResponsiveHelper.getSpacing(context, 12.0),
                          horizontal: ResponsiveHelper.getSpacing(context, 16.0),
                        ),
                        child: GestureDetector(
                          onTap: _isLoading ? null : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ResetPasswordScreen()),
                            );
                          },
                          child: Text(
                            'Wachtwoord vergeten?', 
                            style: ResponsiveHelper.getResponsiveTextStyle(
                              context,
                              TextStyle(
                                color: Colors.grey[700], 
                                fontWeight: FontWeight.bold, 
                                decoration: TextDecoration.underline,
                                fontSize: ResponsiveHelper.getBodyFontSize(context),
                              ),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      
                      // Back to options when in focused mode
                      if (widget.showOnlyEmailLogin) ...[
                        ResponsiveHelper.getResponsiveSpacing(context, 16.0),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey[600],
                            padding: EdgeInsets.symmetric(vertical: ResponsiveHelper.getSpacing(context, 12.0)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.arrow_back, size: ResponsiveHelper.getIconSize(context, 18.0)),
                              SizedBox(width: ResponsiveHelper.getSpacing(context, 6.0)),
                              Text(
                                'Terug naar inlogopties',
                                style: TextStyle(
                                  fontSize: ResponsiveHelper.getBodyFontSize(context),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
} 