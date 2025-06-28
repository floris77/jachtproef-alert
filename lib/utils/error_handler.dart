import 'package:flutter/material.dart';

class ErrorHandler {
  static const String _defaultErrorMessage = 'Er is een fout opgetreden. Probeer het opnieuw.';
  
  /// Get user-friendly error message from various error types
  static String getUserFriendlyMessage(dynamic error) {
    if (error == null) return _defaultErrorMessage;
    
    final errorString = error.toString().toLowerCase();
    
    // Network errors
    if (errorString.contains('network') || 
        errorString.contains('connection') ||
        errorString.contains('timeout') ||
        errorString.contains('socket')) {
      return 'Geen internetverbinding. Controleer je verbinding en probeer het opnieuw.';
    }
    
    // Firebase Auth errors
    if (errorString.contains('user-not-found')) {
      return 'Geen account gevonden met dit email adres.';
    }
    if (errorString.contains('wrong-password') || 
        errorString.contains('invalid-credential')) {
      return 'Ongeldig wachtwoord. Probeer het opnieuw.';
    }
    if (errorString.contains('email-already-in-use')) {
      return 'Dit email adres is al in gebruik.';
    }
    if (errorString.contains('weak-password')) {
      return 'Het wachtwoord is te zwak. Gebruik minimaal 6 karakters.';
    }
    if (errorString.contains('invalid-email')) {
      return 'Ongeldig email adres.';
    }
    if (errorString.contains('too-many-requests')) {
      return 'Te veel pogingen. Probeer het later opnieuw.';
    }
    if (errorString.contains('user-disabled')) {
      return 'Dit account is uitgeschakeld.';
    }
    if (errorString.contains('operation-not-allowed')) {
      return 'Deze inlogmethode is niet toegestaan.';
    }
    
    // Payment errors
    if (errorString.contains('payment') || errorString.contains('purchase')) {
      if (errorString.contains('cancelled') || errorString.contains('canceled')) {
        return 'Betaling geannuleerd.';
      }
      if (errorString.contains('invalid')) {
        return 'Ongeldige betaling. Controleer je betaalgegevens.';
      }
      if (errorString.contains('not available')) {
        return 'Betaling niet beschikbaar. Probeer het later opnieuw.';
      }
      return 'Er is een fout opgetreden bij de betaling. Probeer het opnieuw.';
    }
    
    // Permission errors
    if (errorString.contains('permission') || errorString.contains('access')) {
      return 'Geen toegang. Probeer opnieuw in te loggen.';
    }
    
    // Generic error patterns
    if (errorString.contains('exception:')) {
      return errorString.split('exception:').last.trim();
    }
    
    return _defaultErrorMessage;
  }
  
  /// Show error snackbar with consistent styling
  static void showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
  
  /// Show success snackbar with consistent styling
  static void showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
  
  /// Show info snackbar with consistent styling
  static void showInfoSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
  
  /// Handle error with automatic snackbar display
  static void handleError(BuildContext context, dynamic error) {
    final message = getUserFriendlyMessage(error);
    showErrorSnackBar(context, message);
  }
  
  /// Log error for debugging while showing user-friendly message
  static void handleErrorWithLogging(BuildContext context, dynamic error, {String? tag}) {
    // Log the actual error for debugging
    print('❌ ${tag ?? 'ERROR'}: $error');
    if (error is Exception) {
      print('❌ ${tag ?? 'ERROR'} Stack trace: ${StackTrace.current}');
    }
    
    // Show user-friendly message
    handleError(context, error);
  }
} 