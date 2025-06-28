import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/email_notification_service.dart';
import '../utils/help_system.dart';
import 'proeven_main_page.dart';
import '../utils/responsive_helper.dart';
import '../utils/responsive_dialogs.dart';

const Color kMainColor = Color(0xFF535B22);

class QuickSetupScreen extends StatefulWidget {
  const QuickSetupScreen({super.key});

  @override
  State<QuickSetupScreen> createState() => _QuickSetupScreenState();
}

class _QuickSetupScreenState extends State<QuickSetupScreen> {
  int currentStep = 0;
  
  // User preferences
  Set<String> selectedProefTypes = {};
  bool notificationsEnabled = true;
  bool emailNotifications = false;
  bool wantsInteractiveTour = true;
  List<int> notificationTimes = [0, 1, 2, 3, 4]; // Default: All 5 notification options enabled
  
  // Permission tracking
  PermissionStatus notificationPermission = PermissionStatus.denied;
  bool permissionRequested = false;
  
  final List<ProefType> proefTypes = [
    ProefType('SJP', 'Standaard Jachthonden Proef', Icons.pets),
    ProefType('MAP', 'Meervoudige Apporteer Proef', Icons.water_drop),
    ProefType('OWT', 'Orweja Working Test', Icons.forest),
    ProefType('SWT', 'Spaniel Working Test', Icons.grass),
    ProefType('TAP', 'Team Apporteer Proef', Icons.group),
    ProefType('KAP', 'Koppel Apporteer Proef', Icons.favorite),
    ProefType('PJP', 'Provinciale Jachthondenproef', Icons.location_on),
    ProefType('Veldwedstrijd', 'Apporteerwedstrijden', Icons.emoji_events),
  ];

  @override
  void initState() {
    super.initState();
    _initializePermissions();
  }

  Future<void> _initializePermissions() async {
    final status = await Permission.notification.status;
    setState(() {
      notificationPermission = status;
    });

    // If we're starting at step 0 and haven't requested permissions yet,
    // and the permission is still at the default denied state, auto-request
    if (currentStep == 0 && !permissionRequested && 
        (status == PermissionStatus.denied || status == PermissionStatus.restricted)) {
      // Small delay to let the UI render first
      await Future.delayed(const Duration(milliseconds: 500));
      _requestNotificationPermission();
    }
  }
  
  // Auto-request permission when user navigates to notification step
  Future<void> _handleNotificationStepEntry() async {
    final currentStatus = await Permission.notification.status;
    
    // If permission was never asked before, automatically request it
    // On iOS, the initial state is denied, on Android it could be denied or restricted
    if ((currentStatus == PermissionStatus.denied || currentStatus == PermissionStatus.restricted) && !permissionRequested) {
      // Small delay to let the UI render first
      await Future.delayed(const Duration(milliseconds: 300));
      _requestNotificationPermission();
    }
  }



  Future<void> _requestNotificationPermission() async {
    final status = await Permission.notification.request();
    setState(() {
      notificationPermission = status;
      permissionRequested = true;
      
      // If permission denied, disable notifications
      if (!status.isGranted) {
        notificationsEnabled = false;
      }
    });
  }

  Future<void> _retryNotificationPermission() async {
    // First, check current status
    final currentStatus = await Permission.notification.status;
    
    if (currentStatus.isPermanentlyDenied) {
      // If permanently denied, show a message and open settings
      _showPermissionDialog();
    } else {
      // Try requesting again
      final status = await Permission.notification.request();
      setState(() {
        notificationPermission = status;
        permissionRequested = true;
        
        if (status.isGranted) {
          notificationsEnabled = true;
        } else {
          notificationsEnabled = false;
        }
      });
    }
  }

  Future<void> _openAppSettings() async {
    await openAppSettings();
    
    // After user returns from settings, check permission status again
    Future.delayed(const Duration(milliseconds: 500), () async {
      final status = await Permission.notification.status;
      setState(() {
        notificationPermission = status;
        if (status.isGranted) {
          notificationsEnabled = true;
        }
      });
    });
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ResponsiveDialogs.createResponsiveAlertDialog(
          context: context,
          title: Text(
            'Meldingen Inschakelen',
            style: TextStyle(
              fontSize: ResponsiveHelper.getSubtitleFontSize(context),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Meldingen zijn permanent uitgeschakeld. Om meldingen in te schakelen, ga naar je apparaat instellingen en schakel meldingen in voor JachtProef Alert.',
            style: TextStyle(
              fontSize: ResponsiveHelper.getBodyFontSize(context),
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Annuleren',
                style: TextStyle(
                  fontSize: ResponsiveHelper.getCaptionFontSize(context),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _openAppSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kMainColor,
                foregroundColor: Colors.white,
                padding: ResponsiveHelper.getButtonPadding(context),
              ),
              child: Text(
                'Naar Instellingen',
                style: TextStyle(
                  fontSize: ResponsiveHelper.getCaptionFontSize(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 375;
    final isShortScreen = screenHeight < 700;
    final isVerySmallScreen = screenWidth < 350;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 16 : 24,
                vertical: isSmallScreen ? 12 : 16,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              kMainColor,
                              kMainColor.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.settings,
                          color: Colors.white,
                          size: isSmallScreen ? 18 : 20,
                        ),
                      ),
                      SizedBox(width: isSmallScreen ? 10 : 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Snel Instellen',
                              style: TextStyle(
                                fontSize: isVerySmallScreen ? 16 : (isSmallScreen ? 18 : 20),
                                fontWeight: FontWeight.bold,
                                color: kMainColor,
                              ),
                            ),
                            Text(
                              'Stap ${currentStep + 1} van 3',
                              style: TextStyle(
                                fontSize: isVerySmallScreen ? 11 : (isSmallScreen ? 12 : 14),
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  
                  // Progress indicator
                  LinearProgressIndicator(
                    value: (currentStep + 1) / 3,
                    backgroundColor: Colors.grey[300],
                    valueColor: const AlwaysStoppedAnimation<Color>(kMainColor),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 16 : 24,
                ),
                child: _buildCurrentStep(isSmallScreen, isShortScreen),
              ),
            ),

            // Navigation
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 16 : 24,
                vertical: isSmallScreen ? 12 : 16,
              ),
              child: Row(
                children: [
                  if (currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => currentStep--),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kMainColor,
                          side: const BorderSide(color: kMainColor),
                          padding: EdgeInsets.symmetric(
                            vertical: isSmallScreen ? 12 : 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Vorige',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isVerySmallScreen ? 13 : (isSmallScreen ? 14 : 16),
                          ),
                        ),
                      ),
                    ),
                  
                  if (currentStep > 0) SizedBox(width: isSmallScreen ? 10 : 14),
                  
                  Expanded(
                    flex: currentStep == 0 ? 1 : 2,
                    child: ElevatedButton(
                      onPressed: _handleNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kMainColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: isSmallScreen ? 12 : 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        currentStep == 2 ? 'Klaar!' : 'Volgende',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isVerySmallScreen ? 13 : (isSmallScreen ? 14 : 16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStep(bool isSmallScreen, bool isShortScreen) {
    switch (currentStep) {
      case 0:
        return _buildProefTypesStep(isSmallScreen, isShortScreen);
      case 1:
        return _buildNotificationsStep(isSmallScreen, isShortScreen);
      case 2:
        return _buildTourStep(isSmallScreen, isShortScreen);
      default:
        return Container();
    }
  }

  Widget _buildProefTypesStep(bool isSmallScreen, bool isShortScreen) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: isShortScreen ? 8 : 16),
          
          Text(
            'Welke proeftypes interesseren je?',
            style: TextStyle(
              fontSize: isSmallScreen ? 18 : 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          
          SizedBox(height: isSmallScreen ? 6 : 10),
          
          Text(
            'Selecteer de types jachtproeven die je het meest interesseren. We gebruiken dit om je betere aanbevelingen te geven.',
            style: TextStyle(
              fontSize: isSmallScreen ? 13 : 15,
              color: Colors.grey[600],
              height: 1.3,
            ),
          ),
          
          SizedBox(height: isShortScreen ? 12 : 20),
          
          // Proef types grid - Fixed layout
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, // Always 2 columns for consistency
              crossAxisSpacing: isSmallScreen ? 8 : 12,
              mainAxisSpacing: isSmallScreen ? 8 : 12,
              childAspectRatio: isSmallScreen ? 2.8 : 3.0, // Adjusted for better fit
            ),
            itemCount: proefTypes.length,
            itemBuilder: (context, index) {
              final proefType = proefTypes[index];
              final isSelected = selectedProefTypes.contains(proefType.code);
              
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      selectedProefTypes.remove(proefType.code);
                    } else {
                      selectedProefTypes.add(proefType.code);
                    }
                  });
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 6 : 8,
                    vertical: isSmallScreen ? 8 : 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? kMainColor.withOpacity(0.1) : Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? kMainColor : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        proefType.icon,
                        color: isSelected ? kMainColor : Colors.grey[600],
                        size: isSmallScreen ? 16 : 18,
                      ),
                      SizedBox(width: isSmallScreen ? 4 : 6),
                      Expanded(
                        child: Text(
                          proefType.code,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isSmallScreen ? 11 : 13,
                            color: isSelected ? kMainColor : Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          
          SizedBox(height: isShortScreen ? 8 : 12),
          
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 10 : 14),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700], size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Je kunt dit later altijd aanpassen in de instellingen.',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 11 : 13,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Add bottom padding to prevent overflow
          SizedBox(height: isShortScreen ? 16 : 24),
        ],
      ),
    );
  }

  Widget _buildNotificationsStep(bool isSmallScreen, bool isShortScreen) {
    final notificationOptions = [
      {'title': '7 dagen van tevoren', 'subtitle': 'Vroege herinnering', 'index': 0},
      {'title': '1 dag van tevoren', 'subtitle': 'Laatste herinnering', 'index': 1},
      {'title': '1 uur van tevoren', 'subtitle': 'Net voor deadline', 'index': 2},
      {'title': '10 minuten van tevoren', 'subtitle': 'Laatste kans', 'index': 3},
      {'title': '15 minuten na inschrijving opent', 'subtitle': 'Herinnering om in te schrijven', 'index': 4},
    ];

    final hasPermission = notificationPermission.isGranted;
    final permissionDenied = notificationPermission.isDenied || notificationPermission.isPermanentlyDenied;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: isShortScreen ? 8 : 16),
          
          Text(
            'Meldingen instellen',
            style: TextStyle(
              fontSize: isSmallScreen ? 18 : 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          
          SizedBox(height: isSmallScreen ? 6 : 10),
          
          Text(
            'Mis nooit meer een inschrijfdeadline! We hebben toestemming nodig om je herinneringen te kunnen sturen.',
            style: TextStyle(
              fontSize: isSmallScreen ? 13 : 15,
              color: Colors.grey[600],
              height: 1.3,
            ),
          ),
          
          SizedBox(height: isShortScreen ? 12 : 20),
          
          // Permission request section
          if (!hasPermission) ...[
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
              decoration: BoxDecoration(
                color: permissionDenied ? Colors.orange[50] : Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: permissionDenied ? Colors.orange[200]! : Colors.blue[200]!,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        permissionDenied ? Icons.warning : Icons.notification_important,
                        color: permissionDenied ? Colors.orange[700] : Colors.blue[700],
                        size: isSmallScreen ? 20 : 24,
                      ),
                      SizedBox(width: isSmallScreen ? 10 : 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              permissionDenied ? 'Toestemming Geweigerd' : 'Toestemming Vereist',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 14 : 16,
                                fontWeight: FontWeight.bold,
                                color: permissionDenied ? Colors.orange[700] : Colors.blue[700],
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              permissionDenied 
                                ? 'Je hebt meldingen geweigerd. Je kunt dit later wijzigen in de apparaat instellingen.'
                                : 'We hebben toestemming nodig om je meldingen te kunnen sturen.',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 11 : 13,
                                color: permissionDenied ? Colors.orange[600] : Colors.blue[600],
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                    SizedBox(height: isSmallScreen ? 12 : 16),
                  Row(
                    children: [
                      if (!permissionDenied) ...[
                        Expanded(
                      child: ElevatedButton(
                        onPressed: _requestNotificationPermission,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            vertical: isSmallScreen ? 10 : 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications_active, size: isSmallScreen ? 16 : 18),
                            SizedBox(width: 8),
                            Text(
                              'Toestemming Verlenen',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: isSmallScreen ? 13 : 15,
                              ),
                            ),
                          ],
                        ),
                          ),
                        ),
                      ] else ...[
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _retryNotificationPermission,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange[600],
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                vertical: isSmallScreen ? 10 : 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.refresh, size: isSmallScreen ? 16 : 18),
                                SizedBox(width: 8),
                                Text(
                                  'Opnieuw Proberen',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: isSmallScreen ? 13 : 15,
                      ),
                    ),
                  ],
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _openAppSettings,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange[600],
                              side: BorderSide(color: Colors.orange[600]!),
                              padding: EdgeInsets.symmetric(
                                vertical: isSmallScreen ? 10 : 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.settings, size: isSmallScreen ? 16 : 18),
                                SizedBox(width: 6),
                                Text(
                                  'Instellingen',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: isSmallScreen ? 12 : 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            
            SizedBox(height: isShortScreen ? 12 : 18),
          ],
          
          // Main notifications toggle
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
            decoration: BoxDecoration(
              color: hasPermission ? kMainColor.withOpacity(0.05) : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hasPermission ? kMainColor.withOpacity(0.2) : Colors.grey[300]!,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.notifications,
                  color: hasPermission ? kMainColor : Colors.grey[400],
                  size: isSmallScreen ? 20 : 24,
                ),
                SizedBox(width: isSmallScreen ? 10 : 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Meldingen inschakelen',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14 : 16,
                          fontWeight: FontWeight.bold,
                          color: hasPermission ? Colors.black87 : Colors.grey[500],
                        ),
                      ),
                      Text(
                        hasPermission 
                          ? 'Ontvang automatische herinneringen'
                          : 'Eerst toestemming verlenen',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 11 : 13,
                          color: hasPermission ? Colors.grey[600] : Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: notificationsEnabled && hasPermission,
                  onChanged: hasPermission 
                    ? (value) => setState(() => notificationsEnabled = value)
                    : null,
                  activeColor: kMainColor,
                  inactiveThumbColor: Colors.grey[400],
                  inactiveTrackColor: Colors.grey[300],
                  activeTrackColor: kMainColor.withOpacity(0.3),
                ),
              ],
            ),
          ),
          
          // Email notifications toggle
          SizedBox(height: isShortScreen ? 12 : 18),
          
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.blue.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.email,
                  color: kMainColor,
                  size: isSmallScreen ? 20 : 24,
                ),
                SizedBox(width: isSmallScreen ? 10 : 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'E-mail meldingen',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14 : 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'Ontvang ook e-mails voor je specifieke proeven',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 11 : 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                                 Switch(
                   value: emailNotifications,
                   onChanged: (value) => setState(() => emailNotifications = value),
                   activeColor: kMainColor,
                   inactiveThumbColor: Colors.grey[400],
                   inactiveTrackColor: Colors.grey[300],
                   activeTrackColor: kMainColor.withOpacity(0.3),
                ),
              ],
            ),
          ),
          
          if (notificationsEnabled && hasPermission) ...[
            SizedBox(height: isShortScreen ? 12 : 18),
            
            Text(
              'Wanneer wil je herinneringen ontvangen?',
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            
            SizedBox(height: isSmallScreen ? 8 : 12),
            
            ...notificationOptions.map((option) {
              final index = option['index'] as int;
              final isSelected = notificationTimes.contains(index);
              
              return Container(
                margin: EdgeInsets.only(bottom: isSmallScreen ? 8 : 10),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        notificationTimes.remove(index);
                      } else {
                        notificationTimes.add(index);
                      }
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
                    decoration: BoxDecoration(
                      color: isSelected ? kMainColor.withOpacity(0.1) : Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? kMainColor : Colors.grey[300]!,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.check_circle : Icons.circle_outlined,
                          color: isSelected ? kMainColor : Colors.grey[400],
                          size: isSmallScreen ? 18 : 20,
                        ),
                        SizedBox(width: isSmallScreen ? 10 : 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                option['title'] as String,
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 13 : 15,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                option['subtitle'] as String,
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 11 : 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
          
          // Add bottom padding to prevent overflow
          SizedBox(height: isShortScreen ? 16 : 24),
        ],
      ),
    );
  }

  Widget _buildTourStep(bool isSmallScreen, bool isShortScreen) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: isShortScreen ? 8 : 16),
          
          Text(
            'Klaar om te beginnen!',
            style: TextStyle(
              fontSize: isSmallScreen ? 18 : 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          
          SizedBox(height: isSmallScreen ? 6 : 10),
          
          Text(
            'Je account is bijna klaar. Wil je een korte rondleiding door de app?',
            style: TextStyle(
              fontSize: isSmallScreen ? 13 : 15,
              color: Colors.grey[600],
              height: 1.3,
            ),
          ),
          
          SizedBox(height: isShortScreen ? 16 : 24),
          
          // Tour option
          GestureDetector(
            onTap: () => setState(() => wantsInteractiveTour = !wantsInteractiveTour),
            child: Container(
              padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
              decoration: BoxDecoration(
                color: wantsInteractiveTour ? kMainColor.withOpacity(0.1) : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: wantsInteractiveTour ? kMainColor : Colors.grey[300]!,
                  width: wantsInteractiveTour ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
                    decoration: BoxDecoration(
                      color: wantsInteractiveTour ? kMainColor : Colors.grey[400],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.tour,
                      color: Colors.white,
                      size: isSmallScreen ? 20 : 24,
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 12 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Interactieve Rondleiding',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 14 : 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Leer de app gebruiken door echte knoppen uit te proberen en alle functies te ontdekken.',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 11 : 13,
                            color: Colors.grey[600],
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    wantsInteractiveTour ? Icons.check_circle : Icons.circle_outlined,
                    color: wantsInteractiveTour ? kMainColor : Colors.grey[400],
                    size: isSmallScreen ? 20 : 24,
                  ),
                ],
              ),
            ),
          ),
          
          SizedBox(height: isShortScreen ? 16 : 24),
          
          // Summary
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[700], size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Je instellingen:',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 13 : 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isSmallScreen ? 6 : 10),
                if (selectedProefTypes.isNotEmpty)
                  Text(
                    '• ${selectedProefTypes.length} proeftype${selectedProefTypes.length == 1 ? '' : 's'} geselecteerd',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 11 : 13,
                      color: Colors.green[700],
                    ),
                  ),
                Text(
                  '• Meldingen: ${notificationsEnabled ? "ingeschakeld" : "uitgeschakeld"}',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 11 : 13,
                    color: Colors.green[700],
                  ),
                ),
                Text(
                  '• E-mail: ${emailNotifications ? "ingeschakeld" : "uitgeschakeld"}',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 11 : 13,
                    color: Colors.green[700],
                  ),
                ),
                if (notificationsEnabled) ...[
                  Text(
                    '• Toestemming: ${notificationPermission.isGranted ? "verleend" : "nog niet verleend"}',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 11 : 13,
                      color: notificationPermission.isGranted ? Colors.green[700] : Colors.orange[700],
                    ),
                  ),
                ],
                if (notificationsEnabled && notificationPermission.isGranted && notificationTimes.isNotEmpty)
                  Text(
                    '• ${notificationTimes.length} meldingtijd${notificationTimes.length == 1 ? '' : 'en'} gekozen',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 11 : 13,
                      color: Colors.green[700],
                    ),
                  ),
                Text(
                  '• Rondleiding: ${wantsInteractiveTour ? "ja, graag" : "overslaan"}',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 11 : 13,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
          ),
          
          // Add bottom padding to prevent overflow
          SizedBox(height: isShortScreen ? 16 : 24),
        ],
      ),
    );
  }

  void _handleNext() {
    if (currentStep < 2) {
      setState(() => currentStep++);
      
      // Auto-request notification permission when entering step 1 (notifications step)
      if (currentStep == 1) {
        _handleNotificationStepEntry();
      }
    } else {
      _completeSetup();
    }
  }

  Future<void> _completeSetup() async {
    // Save user preferences
    final prefs = await SharedPreferences.getInstance();
    final user = context.read<AuthService>().currentUser;
    final userId = user?.uid ?? 'anonymous';
    
    // Save completion status (user-specific)
    await prefs.setBool('quick_setup_completed_$userId', true);
    
    // Save user preferences (user-specific)
    await prefs.setStringList('selected_proef_types_$userId', selectedProefTypes.toList());
    await prefs.setBool('notifications_enabled_$userId', notificationsEnabled && notificationPermission.isGranted);
    await prefs.setString('notification_times_$userId', notificationTimes.join(','));
    await prefs.setString('notification_permission_status_$userId', notificationPermission.toString());
    
    // Update user profile in Firebase
    try {
      await context.read<AuthService>().updateUserProfile(
        preferences: {
          'selectedProefTypes': selectedProefTypes.toList(),
          'notificationsEnabled': notificationsEnabled && notificationPermission.isGranted,
          'emailNotifications': emailNotifications,
          'notificationTimes': notificationTimes,
          'notificationPermissionStatus': notificationPermission.toString(),
          'setupCompleted': true,
        },
      );
      
      // Save email notification preference using EmailNotificationService
      if (emailNotifications) {
        await EmailNotificationService.setEmailNotificationsEnabled(true);
      }
    } catch (e) {
      // Continue even if Firebase update fails
      print('Failed to save user preferences: $e');
    }

    if (mounted) {
      if (wantsInteractiveTour) {
        // Save tour preference and navigate to main app
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('should_show_tour_on_main_$userId', true);
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      } else {
        // Just navigate to main app through AuthWrapper
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    }
  }
}

class ProefType {
  final String code;
  final String name;
  final IconData icon;

  ProefType(this.code, this.name, this.icon);
} 