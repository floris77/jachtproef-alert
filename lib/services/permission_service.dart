import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
      final shouldRequest = await showCupertinoDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
            title: const Text(
              'Meldingen Toestaan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            content: const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Om je op de hoogte te houden van belangrijke proef updates, heeft JachtProef Alert toegang nodig tot meldingen.',
                    style: TextStyle(fontSize: 14),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Voordelen:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 6),
                  Text('• Ontvang meldingen wanneer inschrijvingen openen', style: TextStyle(fontSize: 12)),
                  Text('• Krijg herinneringen voor aankomende proeven', style: TextStyle(fontSize: 12)),
                  Text('• Mis nooit meer een belangrijke deadline', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            actions: [
              CupertinoDialogAction(
                child: const Text('Niet Nu'),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              CupertinoDialogAction(
                child: const Text('Toestaan'),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          );
        },
      ) ?? false;
      
      if (!shouldRequest) return false;
      
      // Request permission
      status = await Permission.notification.request();
      return status.isGranted;
    }
    
    if (status.isPermanentlyDenied) {
      // Show settings dialog
      await showCupertinoDialog(
        context: context,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
            title: const Text(
              'Meldingen Geblokkeerd',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            content: const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Meldingen zijn uitgeschakeld voor JachtProef Alert. Ga naar Instellingen om deze in te schakelen.',
                    style: TextStyle(fontSize: 14),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Stappen:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 6),
                  Text('1. Tap "Ga naar Instellingen"', style: TextStyle(fontSize: 12)),
                  Text('2. Zoek "JachtProef Alert"', style: TextStyle(fontSize: 12)),
                  Text('3. Schakel meldingen in', style: TextStyle(fontSize: 12)),
                  Text('4. Kom terug naar de app', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            actions: [
              CupertinoDialogAction(
                child: const Text('Annuleren'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              CupertinoDialogAction(
                child: const Text('Ga naar Instellingen'),
                onPressed: () {
                  Navigator.of(context).pop();
                  openAppSettings();
                },
              ),
            ],
          );
        },
      );
      return false;
    }
    
    return false;
  }
  
  static Future<bool> checkCalendarPermission() async {
    // Check if calendar permission is available
    // Note: add_2_calendar handles the actual permission request,
    // but we can check if the device supports calendar access
    try {
      // For iOS, we can check if calendar access is available
      if (Platform.isIOS) {
        // iOS calendar access is typically available by default
        // The actual permission request happens when adding events
        return true;
      } else if (Platform.isAndroid) {
        // Android calendar access is typically available by default
        // The actual permission request happens when adding events
        return true;
      }
      return true;
    } catch (e) {
      print('❌ Error checking calendar permission: $e');
      return false;
    }
  }
  
  static Future<bool> requestCalendarPermission(BuildContext context) async {
    // First check if calendar access is available
    final hasCalendarAccess = await checkCalendarPermission();
    if (!hasCalendarAccess) {
      await showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text(
            'Agenda Niet Beschikbaar',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          content: const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: Text(
              'Je apparaat ondersteunt geen agenda toegang of de agenda app is niet beschikbaar.',
              style: TextStyle(fontSize: 14),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
      return false;
    }

    // Show explanation dialog about calendar functionality
    final shouldProceed = await showCupertinoDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text(
            'Agenda Toegang',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          content: const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'JachtProef Alert wil proef datums toevoegen aan je agenda zodat je ze nooit vergeet.',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 12),
                Text(
                  'Voordelen:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 6),
                Text('• Automatisch proef datums in je agenda', style: TextStyle(fontSize: 12)),
                Text('• Inschrijf deadlines worden toegevoegd', style: TextStyle(fontSize: 12)),
                Text('• Synchroniseert met je standaard agenda app', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('Niet Nu'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            CupertinoDialogAction(
              child: const Text('Toestaan'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    ) ?? false;
    
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