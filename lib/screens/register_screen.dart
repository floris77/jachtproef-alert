import 'package:flutter/material.dart';
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
    // Only set debug message initially, not the user status message
    setState(() {
      _debugMessage = '[DEBUG] Register button pressed with email: \u001b[32m${_emailController.text.trim()}\u001b[0m, name: ${_nameController.text.trim()}';
    });
    
    // Validate form first - if this fails, don't show "Account aanmaken..." message
    if (!_formKey.currentState!.validate()) {
      setState(() {
        _userStatusMessage = 'Controleer de ingevoerde gegevens en probeer opnieuw.';
      });
      return;
    }

    // Only now show that we're creating the account
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
        _debugMessage = '[DEBUG] Registration successful for email: \u001b[32m${_emailController.text.trim()}\u001b[0m';
        _userStatusMessage = 'Account succesvol aangemaakt! U wordt automatisch ingelogd...';
      });
      if (mounted) {
        await Future.delayed(const Duration(seconds: 1));
        // Navigate to plan selection for new users
        Navigator.pushNamedAndRemoveUntil(context, '/plan-selection', (route) => false);
      }
    } catch (e) {
      setState(() {
        _debugMessage = '[DEBUG] Registration error: \u001b[31m$e\u001b[0m';
        _userStatusMessage = 'Er is een fout opgetreden bij het aanmaken van uw account. Probeer het opnieuw.';
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registreren'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
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
                              ? Colors.red[50]
                              : _userStatusMessage!.contains('succesvol') 
                                  ? Colors.green[50]
                                  : Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _userStatusMessage!.contains('Controleer de ingevoerde gegevens') 
                                ? Colors.red
                                : _userStatusMessage!.contains('succesvol') 
                                    ? Colors.green
                                    : Colors.blue, 
                            width: 1
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _userStatusMessage!.contains('Controleer de ingevoerde gegevens') 
                                  ? Icons.error
                                  : _userStatusMessage!.contains('succesvol') 
                                      ? Icons.check_circle
                                      : Icons.info, 
                              color: _userStatusMessage!.contains('Controleer de ingevoerde gegevens') 
                                  ? Colors.red
                                  : _userStatusMessage!.contains('succesvol') 
                                      ? Colors.green
                                      : Colors.blue
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _userStatusMessage!,
                                style: TextStyle(
                                  color: _userStatusMessage!.contains('Controleer de ingevoerde gegevens') 
                                      ? Colors.red[900]
                                      : _userStatusMessage!.contains('succesvol') 
                                          ? Colors.green[900]
                                          : Colors.blue[900], 
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
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: 'Naam',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vul uw naam in';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      hintText: 'Email',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vul uw email in';
                      }
                      if (!value.contains('@')) {
                        return 'Vul een geldig email adres in';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      hintText: 'Wachtwoord',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vul een wachtwoord in';
                      }
                      if (value.length < 6) {
                        return 'Wachtwoord moet minimaal 6 tekens bevatten';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: InputDecoration(
                      hintText: 'Bevestig wachtwoord',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Bevestig uw wachtwoord';
                      }
                      if (value != _passwordController.text) {
                        return 'Wachtwoorden komen niet overeen';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Registreren', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 24),
                  // Back to login - more prominent button
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[200]!, width: 2),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.login,
                          color: Colors.blue[700],
                          size: 32.0,
                        ),
                        const SizedBox(height: 8.0),
                        Text(
                          'Al een account?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[900],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          'Log in met uw bestaande account',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue[700],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12.0),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            icon: const Icon(
                              Icons.login,
                              size: 20.0,
                            ),
                            label: const Text(
                              'Ga naar Inloggen',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[600],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _isLoading ? null : () {
                              Navigator.pop(context);
                            },
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
      ),
    );
  }
} 