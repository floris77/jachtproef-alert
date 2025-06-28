import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/responsive_dialogs.dart';
import 'dart:io';

class PermissionService {
  static Future<bool> requestNotificationPermission(BuildContext context) async {
    // Check current permission status
    PermissionStatus status = await Permission.notification.status;
    
    if (status.isGranted) {
      return true;
    }
    
    if (status.isDenied) {
      // Show explanation dialog first
      final shouldRequest = await ResponsiveDialogs.showPermissionDialog(
        context: context,
        title: 'Meldingen Toestaan',
        message: 'Om je op de hoogte te houden van belangrijke proef updates, heeft JachtProef Alert toegang nodig tot meldingen.',
        icon: Icons.notifications,
        benefits: [
          'Ontvang meldingen wanneer inschrijvingen openen',
          'Krijg herinneringen voor aankomende proeven',
          'Mis nooit meer een belangrijke deadline',
        ],
      );
      
      if (!shouldRequest) return false;
      
      // Request permission
      status = await Permission.notification.request();
      return status.isGranted;
    }
    
    if (status.isPermanentlyDenied) {
      // Show settings dialog
      await ResponsiveDialogs.showSettingsDialog(
        context: context,
        title: 'Meldingen Geblokkeerd',
        message: 'Meldingen zijn uitgeschakeld voor JachtProef Alert. Ga naar Instellingen om deze in te schakelen.',
        steps: [
          'Tap "Ga naar Instellingen"',
          'Zoek "JachtProef Alert"',
          'Schakel meldingen in',
          'Kom terug naar de app',
        ],
        onSettingsPressed: () => openAppSettings(),
      );
      return false;
    }
    
    return false;
  }
  
  static Future<bool> requestCalendarPermission(BuildContext context) async {
    // For calendar, we mainly need to inform the user about the functionality
    // since add_2_calendar handles the actual permission request
    
    final shouldProceed = await ResponsiveDialogs.showPermissionDialog(
      context: context,
      title: 'Agenda Toegang',
      message: 'JachtProef Alert wil proef datums toevoegen aan je agenda zodat je ze nooit vergeet.',
      icon: Icons.calendar_today,
      benefits: [
        'Automatisch proef datums in je agenda',
        'Inschrijf deadlines worden toegevoegd',
        'Synchroniseert met je standaard agenda app',
      ],
    );
    
    return shouldProceed;
  }
  
  static Future<bool> checkNotificationPermission() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }
  
  static Future<void> showPermissionDeniedSnackBar(BuildContext context, String feature) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature vereist toestemming om te werken.'),
        action: SnackBarAction(
          label: 'Instellingen',
          onPressed: () => openAppSettings(),
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 4),
      ),
    );
  }
} 