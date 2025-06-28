import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'welcome_email_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late SharedPreferences _prefs;


  // Add caching for user data
  Map<String, dynamic>? _cachedUserData;
  String? _cachedUserDataUid;
  DateTime? _lastUserDataFetch;
  static const Duration _cacheTimeout = Duration(minutes: 5);

  AuthService() {
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
  }



  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  String _getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Geen account gevonden met dit email adres';
      case 'wrong-password':
        return 'Ongeldig wachtwoord';
      case 'email-already-in-use':
        return 'Dit email adres is al in gebruik';
      case 'weak-password':
        return 'Het wachtwoord is te zwak';
      case 'invalid-email':
        return 'Ongeldig email adres';
      case 'user-disabled':
        return 'Dit account is uitgeschakeld';
      case 'too-many-requests':
        return 'Te veel pogingen. Probeer het later opnieuw';
      case 'operation-not-allowed':
        return 'Deze inlogmethode is niet toegestaan';
      case 'network-request-failed':
        return 'Netwerkfout. Controleer uw internetverbinding';
      default:
        return 'Er is een fout opgetreden: ${e.message}';
    }
  }

  // Sign in with email and password - Auto-creates account if user doesn't exist
  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    try {
      // First, try to sign in normally
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      // If user doesn't exist, automatically create the account
      if (e.code == 'user-not-found') {
        try {
          print('User not found, automatically creating account for: $email');
          
          // Automatically create the account with the provided credentials
          UserCredential result = await _auth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );

          // Extract name from email (before @) as a reasonable default
          String defaultName = email.split('@').first;
          // Capitalize first letter
          if (defaultName.isNotEmpty) {
            defaultName = defaultName[0].toUpperCase() + defaultName.substring(1);
          }

          // Create user document in Firestore
          await _firestore.collection('users').doc(result.user!.uid).set({
            'name': defaultName,
            'email': email,
            'createdAt': FieldValue.serverTimestamp(),
            'autoCreated': true, // Flag to indicate this was auto-created
            'preferences': {
              'notifications': true,
              'emailUpdates': true,
              'favoriteTypes': [],
              'favoriteLocations': [],
            },
          });

          // Send welcome email (non-blocking - don't fail registration if email fails)
          _sendWelcomeEmailAsync(email, defaultName);

          print('Account automatically created successfully for: $email');
          return result;
        } on FirebaseAuthException catch (createError) {
          // If account creation also fails, throw the original error
          print('Auto-creation failed: ${createError.code}');
          throw Exception(_getErrorMessage(createError));
        } catch (createError) {
          print('Auto-creation failed with general error: $createError');
          throw Exception('Er is een fout opgetreden bij het aanmaken van uw account');
        }
      } else {
        // For all other errors (wrong password, invalid email, etc.), throw the original error
        throw Exception(_getErrorMessage(e));
      }
    } catch (e) {
      throw Exception('Er is een fout opgetreden bij het inloggen');
    }
  }

  // Sign in with email and password - Original method for explicit login (kept for backwards compatibility)
  Future<UserCredential> signInWithEmailAndPasswordOnly(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_getErrorMessage(e));
    } catch (e) {
      throw Exception('Er is een fout opgetreden bij het inloggen');
    }
  }

  // Register with email and password
  Future<UserCredential> registerWithEmailAndPassword(
    String email,
    String password,
    String name,
  ) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user document in Firestore
      await _firestore.collection('users').doc(result.user!.uid).set({
        'name': name,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'preferences': {
          'notifications': true,
          'emailUpdates': true,
          'favoriteTypes': [],
          'favoriteLocations': [],
        },
      });

      // Send welcome email (non-blocking - don't fail registration if email fails)
      _sendWelcomeEmailAsync(email, name);

      return result;
    } on FirebaseAuthException catch (e) {
      throw Exception(_getErrorMessage(e));
    } catch (e) {
      throw Exception('Er is een fout opgetreden bij het registreren');
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
    
    // Clear cached user data
    _cachedUserData = null;
    _cachedUserDataUid = null;
    _lastUserDataFetch = null;
    print('🔥 User data cache cleared on sign out');
  }

  // Update user profile
  Future<void> updateUserProfile({
    String? name,
    Map<String, dynamic>? preferences,
  }) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('Geen gebruiker ingelogd');

      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (preferences != null) updates['preferences'] = preferences;

      await _firestore.collection('users').doc(user.uid).update(updates);
      
      // Clear cache to force fresh data on next fetch
      _cachedUserData = null;
      _cachedUserDataUid = null;
      _lastUserDataFetch = null;
      
      print('✅ User profile updated and cache cleared');
    } on FirebaseAuthException catch (e) {
      throw Exception(_getErrorMessage(e));
    } catch (e) {
      throw Exception('Er is een fout opgetreden bij het bijwerken van het profiel');
    }
  }

  // Get user data with improved caching
  Future<Map<String, dynamic>?> getUserData() async {
    try {
      final user = currentUser;
      if (user == null) {
        print('🔥 No user logged in');
        return null;
      }

      // Check if we have valid cached data
      if (_cachedUserData != null && 
          _cachedUserDataUid == user.uid && 
          _lastUserDataFetch != null &&
          DateTime.now().difference(_lastUserDataFetch!) < _cacheTimeout) {
        print('🔥 Returning cached user data for ${user.email}');
        return _cachedUserData;
      }

      print('🔥 Fetching fresh user data for ${user.email}');
      
      final doc = await _firestore.collection('users').doc(user.uid).get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Update cache
        _cachedUserData = data;
        _cachedUserDataUid = user.uid;
        _lastUserDataFetch = DateTime.now();
        
        print('✅ User data fetched and cached successfully');
        return data;
      } else {
        print('🔥 User document does not exist for ${user.email}');
        return null;
      }
    } on FirebaseException catch (e) {
      print('🔥 Firebase exception in getUserData: $e');
      if (e.code == 'permission-denied') {
        // This is a permission issue, not a missing document
        print('Permission denied - this might be a token or rules issue');
        print('User UID: ${currentUser?.uid}');
        print('User email: ${currentUser?.email}');
        print('User emailVerified: ${currentUser?.emailVerified}');
        
        // Try to reload the user and get a fresh token
        await currentUser?.reload();
        final newToken = await currentUser?.getIdToken(true);
        print('Fresh token obtained: ${newToken != null}');
        
        // Rethrow the original exception since we can't auto-fix permission issues
        throw Exception('Toegang geweigerd tot gebruikersgegevens. Probeer opnieuw in te loggen.');
      }
      throw Exception('Er is een fout opgetreden bij het ophalen van gebruikersgegevens: ${e.message}');
    } catch (e) {
      print('🔥 General exception caught in getUserData: $e');
      print('General error in getUserData: $e');
      throw Exception('Er is een fout opgetreden bij het ophalen van gebruikersgegevens');
    }
  }

  // Google Sign-In and Apple Sign-In methods removed

  // Reset password using Resend (better deliverability)
  Future<void> resetPasswordWithResend(String email) async {
    try {
      // Use standard Firebase Auth password reset
      await _auth.sendPasswordResetEmail(email: email);
      
      print('✅ Password reset email sent via Firebase Auth to $email');
    } on FirebaseAuthException catch (e) {
      throw Exception(_getErrorMessage(e));
    } catch (e) {
      throw Exception('Er is een fout opgetreden bij het resetten van het wachtwoord');
    }
  }

  // Send password reset email via Resend
  Future<bool> _sendPasswordResetEmailViaResend(String email, String resetLink) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final idToken = await user.getIdToken();

      final response = await http.post(
        Uri.parse('https://us-central1-jachtproefalert.cloudfunctions.net/send-password-reset'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'email': email,
          'reset_link': resetLink,
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Password reset email sent via Resend to $email');
        return true;
      } else {
        print('❌ Failed to send password reset via Resend: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Error sending password reset via Resend: $e');
      return false;
    }
  }

  // Reset password (original method - kept for backwards compatibility)
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw Exception(_getErrorMessage(e));
    } catch (e) {
      throw Exception('Er is een fout opgetreden bij het resetten van het wachtwoord');
    }
  }

  // Change password for logged-in user
  Future<void> changePassword(String newPassword) async {
    try {
      if (currentUser == null) throw Exception('Geen gebruiker ingelogd');
      await currentUser!.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw Exception(_getErrorMessage(e));
    } catch (e) {
      throw Exception('Er is een fout opgetreden bij het wijzigen van het wachtwoord');
    }
  }

  // Re-authenticate user with current password
  Future<void> reauthenticate(String currentPassword) async {
    try {
      if (currentUser == null) throw Exception('Geen gebruiker ingelogd');
      final cred = EmailAuthProvider.credential(
        email: currentUser!.email!,
        password: currentPassword,
      );
      await currentUser!.reauthenticateWithCredential(cred);
    } on FirebaseAuthException catch (e) {
      throw Exception(_getErrorMessage(e));
    } catch (e) {
      throw Exception('Er is een fout opgetreden bij het verifiëren van uw wachtwoord');
    }
  }

  // Delete user account and Firestore data
  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Geen gebruiker ingelogd');

      // Delete user data from Firestore
      await _firestore.collection('users').doc(user.uid).delete();

      // Delete the user account
      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw Exception(_getErrorMessage(e));
    } catch (e) {
      throw Exception('Er is een fout opgetreden bij het verwijderen van het account');
    }
  }

  // Get user name with caching
  Future<String> getUserName() async {
    try {
      final userData = await getUserData();
      return userData?['name'] ?? 'Jager';
    } catch (e) {
      print('Error getting user name: $e');
      return 'Jager';
    }
  }

  // Check if the current user account was auto-created
  Future<bool> isAutoCreatedAccount() async {
    try {
      if (currentUser == null) return false;

      final userData = await getUserData();
      return userData?['autoCreated'] == true;
    } catch (e) {
      print('Error checking auto-created status: $e');
      return false;
    }
  }

  // Mark auto-created flag as processed (called after user sees welcome message)
  Future<void> markAutoCreatedAsProcessed() async {
    try {
      if (currentUser == null) return;

      await _firestore.collection('users').doc(currentUser!.uid).update({
        'autoCreated': false,
        'profileCompleted': true,
        'welcomeShown': true,
      });
    } catch (e) {
      print('Error marking auto-created as processed: $e');
    }
  }

  // Update user profile after auto-creation (allows user to set proper name)
  Future<void> completeAutoCreatedProfile({
    required String name,
    Map<String, dynamic>? preferences,
  }) async {
    try {
      if (currentUser == null) throw Exception('Geen gebruiker ingelogd');

      Map<String, dynamic> updates = {
        'name': name,
        'autoCreated': false,
        'profileCompleted': true,
        'profileCompletedAt': FieldValue.serverTimestamp(),
      };
      
      if (preferences != null) {
        updates['preferences'] = preferences;
      }

      // Update Firestore document
      await _firestore.collection('users').doc(currentUser!.uid).update(updates);
      
      // Also update Firebase Auth user's displayName
      await currentUser!.updateDisplayName(name);
      // Reload the user to get the updated displayName
      await currentUser!.reload();
    } catch (e) {
      throw Exception('Er is een fout opgetreden bij het bijwerken van het profiel');
    }
  }

  // Force re-authentication to fix token issues
  Future<void> forceReAuthentication() async {
    try {
      final currentEmail = currentUser?.email;
      if (currentEmail == null) {
        throw Exception('No user currently signed in');
      }
      
      print('Forcing re-authentication for user: $currentEmail');
      
      // Sign out completely
      await signOut();
      
      print('User signed out, please sign in again');
      
    } catch (e) {
      print('Error during forced re-authentication: $e');
      throw Exception('Er is een fout opgetreden bij het vernieuwen van de authenticatie');
    }
  }

  // Send welcome email asynchronously (non-blocking)
  void _sendWelcomeEmailAsync(String email, String name) async {
    try {
      print('📧 Sending welcome email to $email...');
      final success = await WelcomeEmailService.sendWelcomeEmail(
        userEmail: email,
        userName: name,
      );
      if (success) {
        print('✅ Welcome email sent successfully to $email');
      } else {
        print('❌ Failed to send welcome email to $email');
      }
    } catch (e) {
      print('❌ Error sending welcome email: $e');
      // Don't throw - this is non-blocking
    }
  }
} 