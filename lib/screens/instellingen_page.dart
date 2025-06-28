import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'plan_selection_screen.dart';
import '../services/auth_service.dart';
import '../services/payment_service.dart';
import '../services/notification_service.dart';
import '../services/analytics_service.dart';
import '../services/email_notification_service.dart';
import '../utils/constants.dart';
import '../utils/help_system.dart';
import '../utils/responsive_helper.dart';
import '../utils/responsive_dialogs.dart';
import 'quick_setup_screen.dart';
import 'help_screen.dart';
import 'welcome_trial_screen.dart';
import 'account_check_screen.dart';
import 'proeven_main_page.dart';
import 'debug_settings_screen.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

// Define the color constants at the top
const kMainColor = Color(0xFF2E7D32);

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
      final user = context.read<AuthService>().currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'notificationTimes': notificationTimes,
        }, SetOptions(merge: true));
        
        print('✅ Notification timing preferences saved to Firestore');
      }
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 375;
    final isLargeScreen = screenWidth > 414;
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Instellingen', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: kMainColor),
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(
          vertical: 8, 
          horizontal: isSmallScreen ? 8 : 0
        ),
        children: [
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
                        Icons.person, 
                        color: Colors.white, 
                        size: isSmallScreen ? 28 : 32
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
                            fontSize: isSmallScreen ? 18 : (isLargeScreen ? 22 : 20)
                          )
                        ),
                        SizedBox(height: 4),
                        Text(
                          userEmail, 
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: isSmallScreen ? 15 : 16,
                            fontWeight: FontWeight.w500,
                          )
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.edit, color: kMainColor),
                  title: const Text('Profiel Bewerken', style: TextStyle(fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _editProfileDialog,
                  contentPadding: EdgeInsets.zero,
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Uitloggen', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  onTap: _logout,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),

          // Debug section (for testing authentication flow)
          _SettingsSection(
            title: 'DEBUG (TESTING)',
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.bug_report, color: Colors.orange),
                  title: const Text('Debug Instellingen', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Geavanceerde debug opties'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const DebugSettingsScreen()),
                    );
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Force Sign Out (Test Auth)', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Test de volledige inlog flow'),
                  onTap: () async {
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
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),

          // Community section
          _SettingsSection(
            title: 'COMMUNITY',
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.group, color: Colors.blue),
                  title: const Text('Facebook Groep', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Sluit je aan bij onze community'),
                  trailing: const Icon(Icons.open_in_new, color: kMainColor),
                  onTap: _openFacebookGroup,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          // Preferences section
          _SettingsSection(
            title: 'VOORKEUREN',
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.favorite, color: kMainColor),
                  title: const Text('Favoriete Proef Types', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: selectedProefTypes.isEmpty 
                    ? const Text('Geen voorkeuren ingesteld - alle proeven worden getoond')
                    : Text('${selectedProefTypes.length} type(s) geselecteerd: ${selectedProefTypes.map((type) => proefTypeTranslations[type] ?? type).join(', ')}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showPreferencesDialog,
                  contentPadding: EdgeInsets.zero,
                ),
                if (selectedProefTypes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 40, top: 4, bottom: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () async {
                          await _saveUserPreferences([]);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Voorkeuren gewist - alle proeven worden nu getoond'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        },
                        child: const Text(
                          'Alle voorkeuren wissen',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Notification toggles
          _SettingsSection(
            title: 'MELDINGEN',
            child: Column(
              children: [
                _CustomSwitchTile(
                  icon: Icons.notifications,
                  iconColor: kMainColor,
                  title: 'Meldingen Inschakelen',
                  value: notificationsEnabled,
                  onChanged: (val) {
                    setState(() => notificationsEnabled = val);
                    _updatePreferences();
                  },
                ),
                _CustomSwitchTile(
                  icon: Icons.email,
                  iconColor: kMainColor,
                  title: 'E-mail Meldingen',
                  subtitle: 'Ontvang emails voor jouw specifieke proeven',
                  value: emailNotifications,
                  enabled: true,
                  onChanged: (val) async {
                    setState(() => emailNotifications = val);
                    await _updatePreferences();
                    await _updateEmailNotificationSetting(val);
                  },
                ),
                _CustomSwitchTile(
                  icon: Icons.phone_android,
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
          // Notification times
          _SettingsSection(
            title: 'MELDINGSTIJDEN',
            child: Column(
              children: [
                _NotificationTimeRow(
                  icon: Icons.calendar_today,
                  iconColor: kMainColor,
                  label: '7 dagen van tevoren',
                  value: notificationTimes[0],
                  onChanged: (val) {
                    setState(() => notificationTimes[0] = val);
                    _updatePreferences();
                  },
                ),
                _NotificationTimeRow(
                  icon: Icons.access_time_filled,
                  iconColor: Colors.green,
                  label: '1 dag van tevoren',
                  value: notificationTimes[1],
                  onChanged: (val) {
                    setState(() => notificationTimes[1] = val);
                    _updatePreferences();
                  },
                ),
                _NotificationTimeRow(
                  icon: Icons.alarm,
                  iconColor: kMainColor,
                  label: '1 uur van tevoren',
                  value: notificationTimes[2],
                  onChanged: (val) {
                    setState(() => notificationTimes[2] = val);
                    _updatePreferences();
                  },
                ),
                _NotificationTimeRow(
                  icon: Icons.timer,
                  iconColor: kMainColor,
                  label: '10 minuten van tevoren',
                  value: notificationTimes[3],
                  onChanged: (val) {
                    setState(() => notificationTimes[3] = val);
                    _updatePreferences();
                  },
                ),
                _NotificationTimeRow(
                  icon: Icons.notification_add,
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
                icon = Icons.verified;
                iconColor = Colors.green;
              } else if (isInTrial) {
                title = 'Gratis Proefperiode';
                subtitle = 'Nog $trialDaysRemaining dagen gratis toegang';
                icon = Icons.timer;
                iconColor = Colors.blue;
              } else {
                title = 'Start Gratis Proefperiode';
                subtitle = '14 dagen gratis, dan €3.99/maand of €29,99/jaar';
                icon = Icons.star;
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
                    child: ListTile(
                      leading: Icon(icon, color: iconColor),
                      title: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(subtitle),
                      trailing: hasSubscription 
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const Icon(Icons.arrow_forward_ios, color: kMainColor),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PlanSelectionScreen(),
                          ),
                        );
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              );
            },
          ),
          // App section
          _SettingsSection(
            title: 'APP',
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.tour, color: kMainColor),
                  title: const Text('Interactieve Rondleiding', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Leer de app gebruiken met een stap-voor-stap tour'),
                  onTap: () => HelpSystem.showSimpleTour(context),
                  contentPadding: EdgeInsets.zero,
                ),
                ListTile(
                  leading: const Icon(Icons.menu_book, color: kMainColor),
                  title: const Text('Bekijk App Uitleg', style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: _showOnboarding,
                  contentPadding: EdgeInsets.zero,
                ),
                ListTile(
                  leading: const Icon(Icons.share, color: kMainColor),
                  title: const Text('App delen', style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: _shareApp,
                  contentPadding: EdgeInsets.zero,
                ),
                ListTile(
                  leading: const Icon(Icons.settings, color: kMainColor),
                  title: const Text('Versie', style: TextStyle(fontWeight: FontWeight.bold)),
                  trailing: const Text('10.3.0', style: TextStyle(color: kMainColor, fontWeight: FontWeight.bold)),
                  contentPadding: EdgeInsets.zero,
                ),
                _CustomSwitchTile(
                  icon: Icons.analytics_outlined,
                  iconColor: kMainColor,
                  title: 'App Analytics',
                  subtitle: 'Help ons de app te verbeteren door anonieme gebruiksgegevens te verzamelen',
                  value: _analyticsEnabled,
                  onChanged: _toggleAnalytics,
                ),
                ListTile(
                  leading: const Icon(Icons.bug_report, color: kMainColor),
                  title: const Text('Debug Instellingen', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Bekijk logs en debug informatie voor TestFlight'),
                  trailing: const Icon(Icons.arrow_forward_ios, color: kMainColor),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DebugSettingsScreen(),
                      ),
                    );
                  },
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          // Support section
          _SettingsSection(
            title: 'SUPPORT',
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.email, color: kMainColor),
                  title: const Text('E-mail Support', style: TextStyle(fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.open_in_new, color: kMainColor),
                  onTap: _emailSupport,
                  contentPadding: EdgeInsets.zero,
                ),
                ListTile(
                  leading: const Icon(Icons.chat, color: kMainColor),
                  title: const Text('WhatsApp Support', style: TextStyle(fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.open_in_new, color: kMainColor),
                  onTap: _whatsappSupport,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.lock, color: kMainColor),
            title: const Text('Wachtwoord wijzigen'),
            onTap: _changePasswordDialog,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.delete, color: Colors.white),
              label: const Text('Account Verwijderen', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: _deleteAccount,
            ),
          ),
        ],
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
            child: Text(title, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
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

class _NotificationTimeRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _NotificationTimeRow({required this.icon, required this.iconColor, required this.label, required this.value, required this.onChanged, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 16),
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
          Switch(
            value: value, 
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: Colors.green,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey[300],
          ),
        ],
      ),
    );
  }
}

class _CustomSwitchTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  const _CustomSwitchTile({
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
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Switch(
              value: value, 
              onChanged: enabled ? onChanged : null,
              activeColor: Colors.white,
              activeTrackColor: Colors.green,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: Colors.grey[300],
            ),
          ],
        ),
      ),
    );
  }
}
