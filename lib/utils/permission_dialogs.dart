import 'package:flutter/material.dart';
import 'responsive_dialogs.dart';

const Color kMainColor = Color(0xFF535B22);

class PermissionDialogs {
  static Future<bool> showNotificationPermissionDialog(BuildContext context) async {
    return await ResponsiveDialogs.showPermissionDialog(
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
  }

  static Future<bool> showCalendarPermissionDialog(BuildContext context) async {
    return await ResponsiveDialogs.showPermissionDialog(
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
  }

  static void showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ $message'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }

  static void showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ $message'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }
} 