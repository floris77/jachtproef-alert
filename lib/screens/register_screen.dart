import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'proeven_main_page.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _debugMessage;
  String? _userStatusMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    // Validate form first
    if (!_formKey.currentState!.validate()) {
      setState(() {
        _userStatusMessage = 'Controleer de ingevoerde gegevens en probeer opnieuw.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _userStatusMessage = 'Account aanmaken...';
    });

    try {
      await context.read<AuthService>().registerWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text,
        _nameController.text.trim(),
      );
      
      setState(() {
        _userStatusMessage = 'Account succesvol aangemaakt! U wordt automatisch ingelogd...';
      });
      
      if (mounted) {
        await Future.delayed(const Duration(seconds: 1));
        Navigator.pushNamedAndRemoveUntil(context, '/plan-selection', (route) => false);
      }
    } catch (e) {
      final errorMessage = _getUserFriendlyErrorMessage(e.toString());
      setState(() {
        _userStatusMessage = errorMessage['title'];
        _errorMessage = errorMessage['details'];
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Map<String, String> _getUserFriendlyErrorMessage(String error) {
    final errorLower = error.toLowerCase();
    
    if (errorLower.contains('internetverbinding') || errorLower.contains('network')) {
      return {
        'title': 'Geen internetverbinding',
        'details': 'Controleer uw wifi of mobiele data en probeer het opnieuw.',
      };
    } else if (errorLower.contains('email-already-in-use') || errorLower.contains('al in gebruik')) {
      return {
        'title': 'Email adres al in gebruik',
        'details': 'Dit email adres is al geregistreerd. Probeer in te loggen of gebruik een ander email adres.',
      };
    } else if (errorLower.contains('weak-password') || errorLower.contains('te zwak')) {
      return {
        'title': 'Wachtwoord te zwak',
        'details': 'Kies een wachtwoord van minimaal 6 karakters met letters en cijfers.',
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
    } else {
      return {
        'title': 'Account aanmaken mislukt',
        'details': 'Er ging iets mis. Controleer uw gegevens en probeer het opnieuw.',
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Registreren'),
        backgroundColor: CupertinoColors.systemGrey6,
        border: null,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_userStatusMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: _userStatusMessage!.contains('Controleer de ingevoerde gegevens') 
                              ? CupertinoColors.systemRed.withOpacity(0.1)
                              : _userStatusMessage!.contains('succesvol') 
                                  ? CupertinoColors.systemGreen.withOpacity(0.1)
                                  : CupertinoColors.systemBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _userStatusMessage!.contains('Controleer de ingevoerde gegevens') 
                                ? CupertinoColors.systemRed
                                : _userStatusMessage!.contains('succesvol') 
                                    ? CupertinoColors.systemGreen
                                    : CupertinoColors.systemBlue, 
                            width: 1
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
                                      : CupertinoColors.systemBlue
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
                                  fontWeight: FontWeight.bold
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_debugMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        _debugMessage!,
                        style: const TextStyle(color: Colors.blue, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: CupertinoTextField(
                    controller: _nameController,
                      placeholder: 'Naam',
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: CupertinoColors.systemGrey4),
                    ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: CupertinoTextField(
                    controller: _emailController,
                      placeholder: 'Email',
                      keyboardType: TextInputType.emailAddress,
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: CupertinoColors.systemGrey4),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: CupertinoTextField(
                    controller: _passwordController,
                      placeholder: 'Wachtwoord',
                      obscureText: true,
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: CupertinoColors.systemGrey4),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    child: CupertinoTextField(
                    controller: _confirmPasswordController,
                      placeholder: 'Bevestig wachtwoord',
                      obscureText: true,
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: CupertinoColors.systemGrey4),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  CupertinoButton(
                    color: const Color(0xFF2E7D32),
                    borderRadius: BorderRadius.circular(12),
                    onPressed: _isLoading ? null : _register,
                    child: _isLoading
                        ? const CupertinoActivityIndicator(color: Colors.white)
                        : const Text(
                            'Account Aanmaken',
                          style: TextStyle(
                              color: Colors.white,
                            fontWeight: FontWeight.bold,
                                fontSize: 16,
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
} 