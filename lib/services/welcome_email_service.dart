import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class WelcomeEmailService {
  static const String _cloudFunctionUrl = 
      'https://us-central1-jachtproefalert.cloudfunctions.net/send-welcome-email';

  /// Send welcome email to new user
  static Future<bool> sendWelcomeEmail({
    required String userEmail,
    required String userName,
  }) async {
    try {
      // Get Firebase Auth token for security
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No authenticated user for welcome email');
        return false;
      }

      final idToken = await user.getIdToken();

      final response = await http.post(
        Uri.parse(_cloudFunctionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'email': userEmail,
          'name': userName,
        }),
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        print('✅ Welcome email sent successfully');
        print('📧 Email ID: ${result['email_id']}');
        return true;
      } else {
        print('❌ Failed to send welcome email: ${response.statusCode}');
        print('Response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error sending welcome email: $e');
      return false;
    }
  }
} 