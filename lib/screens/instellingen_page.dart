import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/payment_service.dart';
import '../services/analytics_service.dart';
import '../utils/constants.dart';
import '../utils/help_system.dart';
import 'debug_settings_screen.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/cupertino.dart';
import '../../core/theme/app_text_styles.dart';

// Define the color constants at the top
const kMainColor = Color(0xFF2E7D32);
const bool kShowDebug = false; // Set to true for debug/test users

// Place these at the top of the file, after imports:
const sectionHeaderStyle = TextStyle(
  color: CupertinoColors.systemGrey,
  fontWeight: FontWeight.w600,
  fontSize: 14,
  letterSpacing: 1.2,
);
const mainActionStyle = TextStyle(
  color: Colors.black,
  fontWeight: FontWeight.bold,
  fontSize: 17,
);
const descriptionStyle = TextStyle(
  color: CupertinoColors.systemGrey,
  fontWeight: FontWeight.normal,
  fontSize: 14,
);

class InstellingenPage extends StatefulWidget {
  const InstellingenPage({Key? key}) : super(key: key);

  @override
  State<InstellingenPage> createState() => _InstellingenPageState();
}

class _InstellingenPageState extends State<InstellingenPage> {
  String userName = '';
  String userEmail = '';
  List<String> selectedProefTypes = [];
  bool _analyticsEnabled = true;
  String? _chipTapped; // For chip animation

  // Proef type translations map
  final Map<String, String> proefTypeTranslations = {
    'Veldwedstrijd': 'Veldwedstrijd',
    'SJP': 'Standaard Jachthonden Proef',
    'MAP': 'Meervoudige Apporteer Proef',
    'PJP': 'Provinciale Jachthondenproef',
    'TAP': 'Team Apporteer Proef',
    'KAP': 'Koppel Apporteer Proef',
    'SWT': 'Spaniel Working Test',
    'OWT': 'Orweja Working Test',
  };

  // Demo toggles
  bool notificationsEnabled = true;
  bool emailNotifications = false; // Disabled for now
  bool pushNotifications = true;
  List<bool> notificationTimes = [true, true, true, true, true]; // All 5 notification options enabled by default

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadUserPreferences();
    _loadAnalyticsSettings();
    _loadEmailNotificationSetting();
    _loadNotificationTimingPreferences();
  }

  void _loadUserData() async {
    try {
      final authService = context.read<AuthService>();
      final user = authService.currentUser;
      
      if (user == null) {
        setState(() {
          userName = '';
          userEmail = '';
        });
        return;
      }
      
      // Get user data from Firestore instead of relying on displayName
      final userData = await authService.getUserData();
      
      setState(() {
        // Use the name from Firestore, fallback to email prefix if not available
        userName = userData?['name'] ?? user.email?.split('@').first ?? '';
        userEmail = user.email ?? '';
      });
    } catch (e) {
      print('Error loading user data: $e');
      // Set defaults if there's an error
      final user = context.read<AuthService>().currentUser;
      setState(() {
        // Fallback to email prefix if everything else fails
        userName = user?.email?.split('@').first ?? '';
        userEmail = user?.email ?? '';
      });
    }
  }

  void _loadAnalyticsSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = context.read<AuthService>().currentUser;
      final userId = user?.uid ?? 'anonymous';
      
      setState(() {
        _analyticsEnabled = prefs.getBool('analytics_enabled_$userId') ?? true;
      });
    } catch (e) {
      print('Error loading analytics settings: $e');
    }
  }

  void _toggleAnalytics(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = context.read<AuthService>().currentUser;
      final userId = user?.uid ?? 'anonymous';
      
      await prefs.setBool('analytics_enabled_$userId', value);
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(value);
      
      setState(() {
        _analyticsEnabled = value;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value 
              ? 'Analytics ingeschakeld voor app-verbetering' 
              : 'Analytics uitgeschakeld voor privacy'),
            backgroundColor: value ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Error updating analytics setting: $e');
    }
  }

  Future<void> _loadUserPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = context.read<AuthService>().currentUser;
      if (user == null) return;
      
      // Load user-specific preferences
      final userKey = 'selected_proef_types_${user.uid}';
      final storedTypes = prefs.getStringList(userKey);
      
      if (storedTypes != null && storedTypes.isNotEmpty) {
        setState(() {
          selectedProefTypes = storedTypes;
        });
      } else {
        // Try to load from Firebase if not in SharedPreferences
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          
          if (userDoc.exists) {
            final data = userDoc.data() as Map<String, dynamic>;
            final firebaseTypes = data['selectedProefTypes'] as List<dynamic>?;
            
            if (firebaseTypes != null && firebaseTypes.isNotEmpty) {
              final types = firebaseTypes.map((e) => e.toString()).toList();
              setState(() {
                selectedProefTypes = types;
              });
              // Also save to SharedPreferences for offline access
              await prefs.setStringList(userKey, types);
            }
          }
        } catch (e) {
          print('Error loading preferences from Firebase: $e');
        }
      }
    } catch (e) {
      print('Error loading user preferences: $e');
    }
  }

  Future<void> _saveUserPreferences(List<String> types) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = context.read<AuthService>().currentUser;
      if (user == null) return;
      
      // Save to user-specific SharedPreferences
      final userKey = 'selected_proef_types_${user.uid}';
      await prefs.setStringList(userKey, types);
      
      // Save to Firebase
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'selectedProefTypes': types,
      }, SetOptions(merge: true));
      
      setState(() {
        selectedProefTypes = types;
      });
      
      print('✅ User preferences saved: $types');
    } catch (e) {
      print('Error saving user preferences: $e');
    }
  }

  Future<Map<String, dynamic>> _getSubscriptionStatus() async {
    try {
      final paymentService = PaymentService();
      final hasSubscription = await paymentService.hasActiveSubscription();
      final isInTrial = await paymentService.isInTrialPeriod();
      final trialDaysRemaining = await paymentService.getTrialDaysRemaining();
      
      return {
        'hasSubscription': hasSubscription,
        'isInTrial': isInTrial,
        'trialDaysRemaining': trialDaysRemaining,
      };
    } catch (e) {
      print('Error getting subscription status: $e');
      return {
        'hasSubscription': false,
        'isInTrial': false,
        'trialDaysRemaining': 0,
      };
    }
  }

  Future<void> _showPreferencesDialog() async {
    List<String> tempSelected = List.from(selectedProefTypes);
    
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Voorkeuren Aanpassen', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Container(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Selecteer de proef types die je wilt zien:',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: SingleChildScrollView(
                        child: Column(
                          children: proefTypeTranslations.entries.map((entry) {
                            final type = entry.key;
                            final displayName = entry.value;
                            final isSelected = tempSelected.contains(type);
                            
                            return CheckboxListTile(
                              title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.w500)),
                              value: isSelected,
                              activeColor: kMainColor,
                              onChanged: (bool? value) {
                                setDialogState(() {
                                  if (value == true) {
                                    if (!tempSelected.contains(type)) {
                                      tempSelected.add(type);
                                    }
                                  } else {
                                    tempSelected.remove(type);
                                  }
                                });
                              },
                              contentPadding: EdgeInsets.zero,
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuleren'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kMainColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    await _saveUserPreferences(tempSelected);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Voorkeuren succesvol opgeslagen!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  child: const Text('Opslaan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _editProfileDialog() async {
    final nameController = TextEditingController(text: userName);
    final emailController = TextEditingController(text: userEmail);
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;
    
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                'Profiel Bewerken',
                style: TextStyle(fontSize: ResponsiveHelper.getSubtitleFontSize(context))
              ),
              content: ConstrainedBox(
                constraints: ResponsiveHelper.getResponsiveConstraints(context),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Naam',
                          labelStyle: TextStyle(fontSize: ResponsiveHelper.getCaptionFontSize(context))
                        ),
                        style: TextStyle(fontSize: ResponsiveHelper.getBodyFontSize(context)),
                        validator: (v) => v == null || v.isEmpty ? 'Vul uw naam in' : null,
                      ),
                      SizedBox(height: ResponsiveHelper.getSpacing(context, 8.0)),
                      TextFormField(
                        controller: emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          labelStyle: TextStyle(fontSize: ResponsiveHelper.getCaptionFontSize(context))
                        ),
                        style: TextStyle(fontSize: ResponsiveHelper.getBodyFontSize(context)),
                        validator: (v) => v == null || v.isEmpty ? 'Vul uw email in' : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Annuleren',
                    style: TextStyle(fontSize: ResponsiveHelper.getCaptionFontSize(context))
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: ResponsiveHelper.getButtonPadding(context),
                    minimumSize: Size(0, ResponsiveHelper.getButtonHeight(context) * 0.8),
                  ),
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isLoading = true);
                          try {
                            await context.read<AuthService>().updateUserProfile(
                              name: nameController.text.trim(),
                            );
                            // Update the main widget's state using the outer setState
                            setState(() {
                              userName = nameController.text.trim();
                              userEmail = emailController.text.trim();
                            });
                            Navigator.pop(context);
                            // Show success message
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Profiel succesvol bijgewerkt!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Fout bij opslaan: $e')),
                            );
                          } finally {
                            setDialogState(() => isLoading = false);
                          }
                        },
                  child: isLoading 
                    ? SizedBox(
                        width: ResponsiveHelper.getIconSize(context, 16.0),
                        height: ResponsiveHelper.getIconSize(context, 16.0),
                        child: const CircularProgressIndicator(strokeWidth: 2)
                      )
                    : Text(
                        'Opslaan',
                        style: TextStyle(fontSize: ResponsiveHelper.getCaptionFontSize(context))
                      ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _logout() async {
    await context.read<AuthService>().signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  Future<void> _updatePreferences() async {
    try {
      final user = context.read<AuthService>().currentUser;
      if (user == null) return;
      
      // Save to SharedPreferences for offline access
      final prefs = await SharedPreferences.getInstance();
      final userKey = user.uid;
      await prefs.setBool('notifications_enabled_$userKey', notificationsEnabled);
      await prefs.setBool('push_notifications_$userKey', pushNotifications);
      
      // Save to AuthService for backward compatibility
      await context.read<AuthService>().updateUserProfile(
        preferences: {
          'notifications': notificationsEnabled,
          'emailUpdates': emailNotifications,
          'pushNotifications': pushNotifications,
          'notificationTimes': notificationTimes,
        },
      );
      
      // Also save notification times directly to Firestore for email scheduling
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'notificationTimes': notificationTimes,
      }, SetOptions(merge: true));
      
      print('✅ Notification preferences saved to Firebase and SharedPreferences');
    } catch (e) {
      print('❌ Error saving notification preferences: $e');
    }
  }

  Future<void> _loadEmailNotificationSetting() async {
    final enabled = await EmailNotificationService.areEmailNotificationsEnabled();
    setState(() {
      emailNotifications = enabled;
    });
  }

  Future<void> _updateEmailNotificationSetting(bool enabled) async {
    await EmailNotificationService.setEmailNotificationsEnabled(enabled);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(enabled 
            ? 'E-mail meldingen ingeschakeld voor je gevolgde proeven'
            : 'E-mail meldingen uitgeschakeld'),
          backgroundColor: enabled ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  Future<void> _showOnboarding() async {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const HelpScreen()),
    );
  }

  Future<void> _shareApp() async {
    const String iosUrl = 'https://apps.apple.com/us/app/jachtproef-alert/id6744362363';
    const String androidUrl = 'https://play.google.com/store/apps/details?id=com.jachtproef.alert';
    final String message = 'Download JachtProef Alert:\n\n- iOS: $iosUrl\n- Android: $androidUrl';
    await Share.share(message);
  }

  Future<void> _emailSupport() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'floris@nordrobe.com',
      query: 'subject=Support%20JachtProef%20Alert',
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kan e-mail app niet openen.')),
      );
    }
  }

  Future<void> _whatsappSupport() async {
    final Uri whatsappUri = Uri.parse('https://wa.me/31612345678');
    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kan WhatsApp niet openen.')),
      );
    }
  }

  Future<void> _openFacebookGroup() async {
    final Uri facebookUri = Uri.parse('https://www.facebook.com/groups/698746552871835/');
    if (await canLaunchUrl(facebookUri)) {
      await launchUrl(facebookUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kan Facebook niet openen.')),
      );
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Account verwijderen',
          style: TextStyle(fontSize: ResponsiveHelper.getSubtitleFontSize(context))
        ),
        content: ConstrainedBox(
          constraints: ResponsiveHelper.getResponsiveConstraints(context),
          child: Text(
            'Weet u zeker dat u uw account wilt verwijderen? Dit kan niet ongedaan worden gemaakt.',
            style: TextStyle(fontSize: ResponsiveHelper.getBodyFontSize(context))
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: Text(
              'Annuleren',
              style: TextStyle(fontSize: ResponsiveHelper.getCaptionFontSize(context))
            )
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: ResponsiveHelper.getButtonPadding(context),
              backgroundColor: Colors.red,
              minimumSize: Size(0, ResponsiveHelper.getButtonHeight(context) * 0.8),
            ),
            onPressed: () => Navigator.pop(context, true), 
            child: Text(
              'Verwijderen',
              style: TextStyle(fontSize: ResponsiveHelper.getCaptionFontSize(context))
            )
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await context.read<AuthService>().deleteAccount();
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fout bij verwijderen: $e')),
        );
      }
    }
  }

  Future<void> _changePasswordDialog() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;
    String? errorMessage;
    String? successMessage;
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Wachtwoord wijzigen'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(errorMessage!, style: const TextStyle(color: Colors.red)),
                      ),
                    if (successMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(successMessage!, style: const TextStyle(color: Colors.green)),
                      ),
                    TextFormField(
                      controller: currentPasswordController,
                      decoration: const InputDecoration(labelText: 'Huidig wachtwoord'),
                      obscureText: true,
                      validator: (v) => v == null || v.isEmpty ? 'Vul uw huidige wachtwoord in' : null,
                    ),
                    TextFormField(
                      controller: newPasswordController,
                      decoration: const InputDecoration(labelText: 'Nieuw wachtwoord'),
                      obscureText: true,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Vul een nieuw wachtwoord in';
                        if (v.length < 6) return 'Minimaal 6 tekens';
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: confirmPasswordController,
                      decoration: const InputDecoration(labelText: 'Bevestig nieuw wachtwoord'),
                      obscureText: true,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Bevestig uw nieuwe wachtwoord';
                        if (v != newPasswordController.text) return 'Wachtwoorden komen niet overeen';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuleren'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setState(() {
                            isLoading = true;
                            errorMessage = null;
                            successMessage = null;
                          });
                          try {
                            await context.read<AuthService>().reauthenticate(currentPasswordController.text);
                            await context.read<AuthService>().changePassword(newPasswordController.text);
                            setState(() {
                              successMessage = 'Wachtwoord succesvol gewijzigd!';
                            });
                          } catch (e) {
                            setState(() {
                              errorMessage = e.toString();
                            });
                          } finally {
                            setState(() => isLoading = false);
                          }
                        },
                  child: isLoading ? const CircularProgressIndicator() : const Text('Wijzigen'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _loadNotificationTimingPreferences() async {
    try {
      final user = context.read<AuthService>().currentUser;
      if (user == null) return;
      
      // Try to load from Firestore first
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;
        
        // Load notification timing preferences
        final timings = data['notificationTimes'] as List<dynamic>?;
        if (timings != null && timings.length >= 5) {
          setState(() {
            notificationTimes = timings.cast<bool>();
          });
          print('✅ Notification timing preferences loaded from Firebase: $notificationTimes');
        }
        
        // Load general notification settings
        final preferences = data['preferences'] as Map<String, dynamic>?;
        if (preferences != null) {
          setState(() {
            notificationsEnabled = preferences['notifications'] ?? true;
            pushNotifications = preferences['pushNotifications'] ?? true;
          });
          print('✅ General notification settings loaded from Firebase: notifications=$notificationsEnabled, push=$pushNotifications');
        }
        
        return;
      }
      
      // Fallback to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userKey = user.uid;
      
      // Load notification timing preferences
      final savedTimes = prefs.getString('notification_times_$userKey');
      if (savedTimes != null) {
        final indices = savedTimes.split(',').map((e) => int.tryParse(e)).where((e) => e != null).cast<int>().toList();
        final times = List<bool>.filled(5, false);
        for (int i = 0; i < 5; i++) {
          times[i] = indices.contains(i);
        }
        setState(() {
          notificationTimes = times;
        });
        print('✅ Notification timing preferences loaded from SharedPreferences: $notificationTimes');
      }
      
      // Load general notification settings
      final notificationsEnabledPref = prefs.getBool('notifications_enabled_$userKey');
      final pushNotificationsPref = prefs.getBool('push_notifications_$userKey');
      
      if (notificationsEnabledPref != null) {
        setState(() {
          notificationsEnabled = notificationsEnabledPref;
        });
        print('✅ General notification settings loaded from SharedPreferences: notifications=$notificationsEnabled');
      }
      
      if (pushNotificationsPref != null) {
        setState(() {
          pushNotifications = pushNotificationsPref;
        });
        print('✅ Push notification setting loaded from SharedPreferences: push=$pushNotifications');
      }
      
      if (savedTimes == null && notificationsEnabledPref == null && pushNotificationsPref == null) {
        print('ℹ️ No saved notification preferences found, using defaults');
      }
    } catch (e) {
      print('❌ Error loading notification preferences: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 375;
    final isLargeScreen = screenWidth > 414;
    
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Instellingen', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: CupertinoColors.systemGrey6,
        border: null,
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
          children: [
            // DEBUG: Confirm ListView is rendering
            const Text('Hello', style: TextStyle(fontSize: 24, color: Colors.red)),
            // Profile section
            _SettingsSection(
              title: 'PROFIEL',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: isSmallScreen ? 24 : 28,
                        backgroundColor: kMainColor,
                        child: Icon(
                            CupertinoIcons.person_solid,
                          color: Colors.white, 
                            size: isSmallScreen ? 28 : 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName, 
                            style: TextStyle(
                              fontWeight: FontWeight.bold, 
                                fontSize: isSmallScreen ? 18 : (isLargeScreen ? 22 : 20),
                                overflow: TextOverflow.ellipsis,
                            ),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            userEmail, 
                            style: TextStyle(
                                color: CupertinoColors.systemGrey,
                              fontSize: isSmallScreen ? 15 : 16,
                              fontWeight: FontWeight.w500,
                                overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _editProfileDialog,
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.pencil, color: kMainColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Profiel Bewerken',
                            style: mainActionStyle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            softWrap: true,
                          ),
                        ),
                        const Spacer(),
                        Icon(CupertinoIcons.right_chevron, color: CupertinoColors.systemGrey, size: 18),
                      ],
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _logout,
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.square_arrow_right, color: CupertinoColors.destructiveRed),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Uitloggen',
                            style: mainActionStyle.copyWith(color: CupertinoColors.destructiveRed),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            softWrap: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Debug section (for testing authentication flow)
            if (kShowDebug)
            _SettingsSection(
              title: 'DEBUG (TESTING)',
              child: Column(
                children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const DebugSettingsScreen()),
                      );
                    },
                      child: Row(
                        children: [
                            Icon(CupertinoIcons.exclamationmark_triangle, color: Colors.orange, size: 22),
                          const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Debug Instellingen',
                              style: mainActionStyle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          const Spacer(),
                          const Text('Geavanceerde debug opties', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 12)),
                            Icon(CupertinoIcons.right_chevron, color: CupertinoColors.systemGrey, size: 18),
                        ],
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () async {
                      try {
                        await context.read<AuthService>().signOut();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Uitgelogd! Je kunt nu de volledige inlog flow testen.'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          // Navigate back to main app to trigger AuthWrapper
                          Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Fout bij uitloggen: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                      child: Row(
                        children: [
                            Icon(CupertinoIcons.square_arrow_right, color: CupertinoColors.destructiveRed, size: 22),
                          const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Force Sign Out (Test Auth)',
                                style: TextStyle(color: CupertinoColors.destructiveRed, fontWeight: FontWeight.bold, overflow: TextOverflow.ellipsis),
                              ),
                            ),
                          const Spacer(),
                          const Text('Test de volledige inlog flow', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 12)),
                        ],
                      ),
                  ),
                ],
              ),
            ),

            // Community section
            _SettingsSection(
              title: 'COMMUNITY',
              child: Column(
                children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _openFacebookGroup,
                      child: Row(
                        children: [
                          Semantics(
                            label: 'Facebook Groep',
                            child: Icon(CupertinoIcons.person_3, color: kMainColor, size: 22),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Facebook Groep',
                              style: mainActionStyle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              softWrap: true,
                            ),
                          ),
                          Icon(CupertinoIcons.arrow_up_right_square, color: kMainColor, size: 18),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Divider(height: 32, thickness: 1, color: CupertinoColors.systemGrey4),

            // Preferences section
            _SettingsSection(
              title: 'VOORKEUREN',
             child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                   children: [ 
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _showPreferencesDialog,
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.heart, color: kMainColor, size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Favoriete Proef Types',
                            style: mainActionStyle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              selectedProefTypes.isEmpty 
                                ? 'Geen voorkeuren ingesteld'
                                : '${selectedProefTypes.length} type(s) geselecteerd',
                              style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 12),
                              textAlign: TextAlign.right,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(CupertinoIcons.right_chevron, color: CupertinoColors.systemGrey, size: 18),
                        ],
                      ),
                  ),
                  if (selectedProefTypes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 40, top: 8, bottom: 8),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ...selectedProefTypes.take(5).map((type) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTapDown: (details) => setState(() => _chipTapped = type),
                                onTapUp: (details) => setState(() => _chipTapped = null),
                                onTapCancel: () => setState(() => _chipTapped = null),
                                child: AnimatedScale(
                                  scale: _chipTapped == type ? 0.95 : 1.0,
                                  duration: const Duration(milliseconds: 120),
                                  curve: Curves.easeOut,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: kMainColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: kMainColor.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          CupertinoIcons.heart_fill,
                                          size: 12,
                                          color: kMainColor,
                                          semanticLabel: 'Favoriete type',
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          type,
                                          style: TextStyle(
                                            color: kMainColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            )),
                            if (selectedProefTypes.length > 5)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      CupertinoIcons.ellipsis,
                                      size: 12,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '+${selectedProefTypes.length - 5}',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ), 
                  if (selectedProefTypes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 40, bottom: 4, top: 4),
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () async {
                          final shouldClear = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Weet je het zeker?'),
                              content: const Text('Wil je echt al je favoriete proef types wissen?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: const Text('Annuleren'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: const Text('Wissen', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                          if (shouldClear == true) {
                            await _saveUserPreferences([]);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Voorkeuren gewist - alle proeven worden nu getoond'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.trash,
                              size: 12,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Alle voorkeuren wissen',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Divider(height: 32, thickness: 1, color: CupertinoColors.systemGrey4),

            // Notification toggles
            _SettingsSection(
              title: 'MELDINGEN',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    _CupertinoSwitchTile(
                      icon: CupertinoIcons.bell,
                    iconColor: kMainColor,
                    title: 'Meldingen Inschakelen',
                    value: notificationsEnabled,
                    onChanged: (val) {
                      setState(() => notificationsEnabled = val);
                      _updatePreferences();
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 40, bottom: 8),
                    child: Text(
                      'Schakel meldingen in om herinneringen te ontvangen voor je favoriete proeven.',
                      style: AppTextStyles.rowSubtitle,
                    ),
                  ),
                  Divider(height: 1, color: CupertinoColors.systemGrey4),
                    _CupertinoSwitchTile(
                      icon: CupertinoIcons.mail,
                    iconColor: kMainColor,
                    title: 'E-mail Meldingen',
                    value: emailNotifications,
                    enabled: true,
                    onChanged: (val) async {
                      setState(() => emailNotifications = val);
                      await _updatePreferences();
                      await _updateEmailNotificationSetting(val);
                    },
                  ),
                    _CupertinoSwitchTile(
                      icon: CupertinoIcons.device_phone_portrait,
                    iconColor: kMainColor,
                    title: 'Push Meldingen',
                    value: pushNotifications,
                    onChanged: (val) {
                      setState(() => pushNotifications = val);
                      _updatePreferences();
                    },
                  ),
                ],
              ),
            ),
            Divider(height: 32, thickness: 1, color: CupertinoColors.systemGrey4),

            // Notification times
            _SettingsSection(
              title: 'MELDINGSTIJDEN',
              child: Column(
                children: [
                    _CupertinoNotificationTimeRow(
                      icon: CupertinoIcons.calendar,
                    iconColor: kMainColor,
                    label: '7 dagen van tevoren',
                    value: notificationTimes[0],
                    onChanged: (val) {
                      setState(() => notificationTimes[0] = val);
                      _updatePreferences();
                    },
                  ),
                    _CupertinoNotificationTimeRow(
                      icon: CupertinoIcons.clock,
                    iconColor: Colors.green,
                    label: '1 dag van tevoren',
                    value: notificationTimes[1],
                    onChanged: (val) {
                      setState(() => notificationTimes[1] = val);
                      _updatePreferences();
                    },
                  ),
                    _CupertinoNotificationTimeRow(
                      icon: CupertinoIcons.alarm,
                    iconColor: kMainColor,
                    label: '1 uur van tevoren',
                    value: notificationTimes[2],
                    onChanged: (val) {
                      setState(() => notificationTimes[2] = val);
                      _updatePreferences();
                    },
                  ),
                    _CupertinoNotificationTimeRow(
                      icon: CupertinoIcons.timer,
                    iconColor: kMainColor,
                    label: '10 minuten van tevoren',
                    value: notificationTimes[3],
                    onChanged: (val) {
                      setState(() => notificationTimes[3] = val);
                      _updatePreferences();
                    },
                  ),
                    _CupertinoNotificationTimeRow(
                      icon: CupertinoIcons.bell,
                    iconColor: Colors.blue,
                    label: '15 minuten na inschrijving opent',
                    value: notificationTimes[4],
                    onChanged: (val) {
                      setState(() => notificationTimes[4] = val);
                      _updatePreferences();
                    },
                  ),
                ],
              ),
            ),
            Divider(height: 32, thickness: 1, color: CupertinoColors.systemGrey4),

            // Subscription section
            FutureBuilder<Map<String, dynamic>>(
              future: _getSubscriptionStatus(),
              builder: (context, snapshot) {
                final data = snapshot.data ?? {};
                final hasSubscription = data['hasSubscription'] ?? false;
                final isInTrial = data['isInTrial'] ?? false;
                final trialDaysRemaining = data['trialDaysRemaining'] ?? 0;
                
                String title;
                String subtitle;
                IconData icon;
                Color iconColor;
                
                if (hasSubscription) {
                  title = 'Premium Actief';
                  subtitle = 'Je hebt toegang tot alle premium functies';
                    icon = CupertinoIcons.checkmark_seal_fill;
                  iconColor = Colors.green;
                } else if (isInTrial) {
                  title = 'Gratis Proefperiode';
                  subtitle = 'Nog $trialDaysRemaining dagen gratis toegang';
                    icon = CupertinoIcons.timer;
                  iconColor = Colors.blue;
                } else {
                  title = 'Start Gratis Proefperiode';
                  subtitle = '14 dagen gratis, dan €3.99/maand of €29,99/jaar';
                    icon = CupertinoIcons.star_fill;
                  iconColor = Colors.blue;
                }
                
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PlanSelectionScreen(),
                            ),
                          );
                        },
                          child: Row(
                            children: [
                              Icon(icon, color: iconColor, size: 22),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                    style: mainActionStyle,
                                    ),
                                    Text(
                                      subtitle,
                                      style: AppTextStyles.rowSubtitle,
                                    ),
                                  ],
                                ),
                              ),
                              hasSubscription 
                                ? Icon(CupertinoIcons.checkmark_circle_fill, color: Colors.green)
                                : Icon(CupertinoIcons.right_chevron, color: kMainColor, size: 18),
                            ],
                          ),
                      ),
                    ),
                  ),
                );
              },
            ),
            Divider(height: 32, thickness: 1, color: CupertinoColors.systemGrey4),

            // App section
            _SettingsSection(
              title: 'APP',
              child: Column(
                children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => HelpSystem.showSimpleTour(context),
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.arrow_up_right_square, color: kMainColor, size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Interactieve Rondleiding',
                            style: mainActionStyle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            softWrap: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _showOnboarding,
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.book, color: kMainColor, size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Bekijk App Uitleg',
                            style: mainActionStyle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            softWrap: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _shareApp,
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.square_arrow_up, color: kMainColor, size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'App delen',
                            style: mainActionStyle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            softWrap: true,
                            ),
                          ),
                        ],
                      ),
                  ),
                    Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(CupertinoIcons.settings, color: kMainColor, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Versie', style: mainActionStyle),
                            Text('10.3.0', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 13, fontWeight: FontWeight.normal)),
                          ],
                        ),
                      ),
                      ],
                  ),
                    _CupertinoSwitchTile(
                      icon: CupertinoIcons.chart_bar,
                    iconColor: kMainColor,
                    title: 'App Analytics',
                    value: _analyticsEnabled,
                    onChanged: _toggleAnalytics,
                  ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DebugSettingsScreen(),
                        ),
                      );
                    },
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.exclamationmark_triangle, color: kMainColor, size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Debug Instellingen',
                            style: mainActionStyle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Spacer(),
                          Icon(CupertinoIcons.right_chevron, color: kMainColor, size: 18),
                        ],
                      ),
                  ),
                ],
              ),
            ),
            Divider(height: 32, thickness: 1, color: CupertinoColors.systemGrey4),

            // Support section
            _SettingsSection(
              title: 'SUPPORT',
              child: Column(
                children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _emailSupport,
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.mail, color: kMainColor, size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'E-mail Support',
                            style: mainActionStyle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            softWrap: true,
                            ),
                          ),
                          const Spacer(),
                          Icon(CupertinoIcons.arrow_up_right_square, color: kMainColor, size: 18),
                        ],
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _whatsappSupport,
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.chat_bubble, color: kMainColor, size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'WhatsApp Support',
                            style: mainActionStyle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            softWrap: true,
                            ),
                          ),
                          const Spacer(),
                          Icon(CupertinoIcons.arrow_up_right_square, color: kMainColor, size: 18),
                ],
              ),
            ),
            Divider(height: 32, thickness: 1, color: CupertinoColors.systemGrey4),

            // Account section
            _SettingsSection(
              title: 'ACCOUNT',
              child: Column(
                children: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _changePasswordDialog,
          child: Row(
            children: [
              Icon(CupertinoIcons.lock, color: kMainColor, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Wachtwoord wijzigen',
                            style: mainActionStyle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
                ],
              ),
            ),
            Divider(height: 32, thickness: 1, color: CupertinoColors.systemGrey4),

            // Delete account section
        Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            child: CupertinoButton(
              color: CupertinoColors.destructiveRed,
            onPressed: _deleteAccount,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                Icon(CupertinoIcons.delete, color: Colors.white, size: 22),
                  const SizedBox(width: 8),
                    Text(
                      'Account verwijderen',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                  ),
                      textAlign: TextAlign.center,
                ),
                ],
              ),
          ),
        ),
      ],
        ),
    ),
  );
}
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final Widget child;
  const _SettingsSection({required this.title, required this.child, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 4),
            child: Text(title, style: sectionHeaderStyle.copyWith(letterSpacing: 2, fontSize: 13)),
          ),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _CupertinoNotificationTimeRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _CupertinoNotificationTimeRow({required this.icon, required this.iconColor, required this.label, required this.value, required this.onChanged, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 16),
          Expanded(child: Text(label, style: AppTextStyles.rowTitle)),
          CupertinoSwitch(
            value: value, 
            onChanged: onChanged,
            activeTrackColor: kMainColor,
            inactiveTrackColor: CupertinoColors.systemGrey4,
          ),
        ],
      ),
    );
  }
}

class _CupertinoSwitchTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  const _CupertinoSwitchTile({
    required this.icon, 
    required this.iconColor, 
    required this.title, 
    required this.value, 
    required this.onChanged,
    this.subtitle,
    this.enabled = true,
    Key? key
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: enabled ? iconColor : Colors.grey),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.rowTitle),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        style: AppTextStyles.rowSubtitle,
                      ),
                    ),
                ],
              ),
            ),
            CupertinoSwitch(
              value: value, 
              onChanged: enabled ? onChanged : null,
              activeTrackColor: kMainColor,
              inactiveTrackColor: CupertinoColors.systemGrey4,
            ),
          ],
        ),
      ),
    );
  }
}
