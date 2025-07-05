import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

import '../services/permission_service.dart';
import '../services/analytics_service.dart';
import '../utils/responsive_dialogs.dart';

class CalendarService {
  static const int _maxRetries = 3;
  static const Duration _timeout = Duration(seconds: 15);
  static const Duration _retryDelay = Duration(seconds: 2);
  
  static final Map<String, bool> _eventCache = {};
  
  /// Initialize timezone data
  static void initialize() {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Amsterdam'));
  }
  
  /// Add match events to calendar with comprehensive error handling and retry logic
  static Future<CalendarResult> addMatchToCalendar({
    required BuildContext context,
    required Map<String, dynamic> match,
    required Function(bool) onStateUpdate,
  }) async {
    try {
      print('📅 [CALENDAR] Starting calendar addition for match: ${match['title'] ?? match['organizer']}');
      
      // Check permissions first
      final hasPermission = await PermissionService.requestCalendarPermission(context);
      if (!hasPermission) {
        print('❌ [CALENDAR] Calendar permission denied');
        return CalendarResult(
          success: false,
          eventsAdded: 0,
          error: 'Agenda toegang geweigerd',
          errorType: CalendarErrorType.permission,
        );
      }
      
      // Optimistic UI update
      onStateUpdate(true);
      
      // Extract match data
      final matchData = _extractMatchData(match);
      if (matchData == null) {
        print('❌ [CALENDAR] Invalid match data');
        return CalendarResult(
          success: false,
          eventsAdded: 0,
          error: 'Ongeldige proef gegevens',
          errorType: CalendarErrorType.invalidData,
        );
      }
      
      print('📅 [CALENDAR] Match data extracted: ${matchData.title} on ${matchData.matchDate}');
      
      // Add events with retry logic
      final result = await _addEventsWithRetry(matchData);
      
      // Log analytics
      if (result.success) {
        AnalyticsService.logCalendarAdd(matchData.title);
        AnalyticsService.logUserAction('calendar_add_success', parameters: {
          'match_title': matchData.title,
          'events_added': result.eventsAdded.toString(),
        });
      } else {
        AnalyticsService.logUserAction('calendar_add_failed', parameters: {
          'match_title': matchData.title,
          'error_type': result.errorType.toString(),
          'error_message': result.error ?? 'Unknown error',
        });
      }
      
      return result;
      
    } catch (e, stackTrace) {
      print('❌ [CALENDAR] Unexpected error: $e');
      print('❌ [CALENDAR] Stack trace: $stackTrace');
      
      return CalendarResult(
        success: false,
        eventsAdded: 0,
        error: 'Onverwachte fout: $e',
        errorType: CalendarErrorType.unknown,
      );
    }
  }
  
  /// Add events with retry mechanism
  static Future<CalendarResult> _addEventsWithRetry(MatchCalendarData matchData) async {
    int eventsAdded = 0;
    List<String> errors = [];
    
    // Try to add match day event
    if (matchData.matchDate != null) {
      final matchResult = await _addEventWithRetry(
        event: _createMatchEvent(matchData),
        eventType: 'match day',
        maxRetries: _maxRetries,
      );
      
      if (matchResult.success) {
        eventsAdded++;
        print('✅ [CALENDAR] Match day event added successfully');
      } else {
        errors.add('Match day: ${matchResult.error}');
        print('⚠️ [CALENDAR] Failed to add match day event: ${matchResult.error}');
      }
    }
    
    // Try to add enrollment event
    if (matchData.enrollmentDate != null && matchData.enrollmentDate!.isAfter(DateTime.now())) {
      final enrollmentResult = await _addEventWithRetry(
        event: _createEnrollmentEvent(matchData),
        eventType: 'enrollment',
        maxRetries: _maxRetries,
      );
      
      if (enrollmentResult.success) {
        eventsAdded++;
        print('✅ [CALENDAR] Enrollment event added successfully');
      } else {
        errors.add('Enrollment: ${enrollmentResult.error}');
        print('⚠️ [CALENDAR] Failed to add enrollment event: ${enrollmentResult.error}');
      }
    }
    
    // Determine overall result
    final success = eventsAdded > 0;
    final errorType = _determineErrorType(errors);
    final errorMessage = errors.isEmpty ? null : errors.join('; ');
    
    return CalendarResult(
      success: success,
      eventsAdded: eventsAdded,
      error: errorMessage,
      errorType: errorType,
    );
  }
  
  /// Add single event with retry logic
  static Future<EventResult> _addEventWithRetry({
    required Event event,
    required String eventType,
    required int maxRetries,
  }) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('📅 [CALENDAR] Attempting to add $eventType event (attempt $attempt/$maxRetries)');
        
        await Add2Calendar.addEvent2Cal(event).timeout(
          _timeout,
          onTimeout: () {
            throw TimeoutException('Calendar addition timed out after ${_timeout.inSeconds} seconds');
          },
        );
        
        print('✅ [CALENDAR] $eventType event added successfully on attempt $attempt');
        return EventResult(success: true);
        
      } catch (e) {
        print('⚠️ [CALENDAR] Attempt $attempt failed for $eventType event: $e');
        
        if (attempt == maxRetries) {
          return EventResult(
            success: false,
            error: e.toString(),
          );
        }
        
        // Wait before retry
        await Future.delayed(_retryDelay * attempt); // Exponential backoff
      }
    }
    
    return EventResult(success: false, error: 'Max retries exceeded');
  }
  
  /// Create match day event
  static Event _createMatchEvent(MatchCalendarData matchData) {
    final matchDate = matchData.matchDate!;
    final isAllDay = matchDate.hour == 0 && matchDate.minute == 0 && matchDate.second == 0;
    
    DateTime startDate;
    DateTime endDate;
    bool allDayFlag = false;
    
    if (isAllDay) {
      final amsterdam = tz.getLocation('Europe/Amsterdam');
      final tzStart = tz.TZDateTime(amsterdam, matchDate.year, matchDate.month, matchDate.day, 0, 0, 0);
      final tzEnd = tzStart.add(const Duration(days: 1));
      startDate = tzStart.toLocal();
      endDate = tzEnd.toLocal();
      allDayFlag = true;
    } else {
      startDate = matchDate;
      endDate = DateTime(matchDate.year, matchDate.month, matchDate.day, 23, 59, 59);
    }
    
    return Event(
      title: matchData.title,
      description: matchData.description,
      location: matchData.location,
      startDate: startDate,
      endDate: endDate,
      allDay: allDayFlag,
    );
  }
  
  /// Create enrollment event
  static Event _createEnrollmentEvent(MatchCalendarData matchData) {
    final enrollmentDate = matchData.enrollmentDate!;
    final title = '${matchData.title} (Inschrijving opent)';
    final description = 'De inschrijving voor deze jachtproef opent op dit moment.';
    
    return Event(
      title: title,
      description: description,
      location: matchData.location,
      startDate: enrollmentDate,
      endDate: enrollmentDate.add(const Duration(hours: 1)),
      allDay: false,
    );
  }
  
  /// Extract and validate match data
  static MatchCalendarData? _extractMatchData(Map<String, dynamic> match) {
    try {
      final title = match['title'] ?? match['organizer'] ?? 'Jachtproef';
      final location = match['location'] ?? '';
      final description = match['remark'] ?? '';
      
      // Extract match date
      DateTime? matchDate;
      final dateStr = match['date'] ?? match['raw']?['date'];
      if (dateStr != null) {
        matchDate = _parseDate(dateStr);
      }
      
      // Extract enrollment date
      DateTime? enrollmentDate;
      final regText = (match['registration_text'] ?? match['raw']?['registration_text'] ?? '').toString().toLowerCase();
      if (regText.startsWith('vanaf ')) {
        enrollmentDate = _parseEnrollmentDate(regText);
      }
      
      return MatchCalendarData(
        title: title,
        location: location,
        description: description,
        matchDate: matchDate,
        enrollmentDate: enrollmentDate,
      );
      
    } catch (e) {
      print('❌ [CALENDAR] Error extracting match data: $e');
      return null;
    }
  }
  
  /// Parse date string to DateTime
  static DateTime? _parseDate(String dateStr) {
    try {
      // Handle various date formats
      if (dateStr.contains('-')) {
        final parts = dateStr.split('-');
        if (parts.length == 3) {
          return DateTime(
            int.parse(parts[2]), // year
            int.parse(parts[1]), // month
            int.parse(parts[0]), // day
          );
        }
      }
      
      // Try parsing as ISO string
      return DateTime.parse(dateStr);
    } catch (e) {
      print('❌ [CALENDAR] Error parsing date: $dateStr - $e');
      return null;
    }
  }
  
  /// Parse enrollment date from registration text
  static DateTime? _parseEnrollmentDate(String regText) {
    try {
      // Parse "vanaf DD-MM-YYYY HH:MM" format
      final dateTimeStr = regText.substring(6); // Remove "vanaf "
      final parts = dateTimeStr.split(' ');
      if (parts.length >= 2) {
        final datePart = parts[0]; // DD-MM-YYYY
        final timePart = parts[1]; // HH:MM
        
        final dateComponents = datePart.split('-');
        final timeComponents = timePart.split(':');
        
        if (dateComponents.length == 3 && timeComponents.length == 2) {
          return DateTime(
            int.parse(dateComponents[2]), // year
            int.parse(dateComponents[1]), // month
            int.parse(dateComponents[0]), // day
            int.parse(timeComponents[0]), // hour
            int.parse(timeComponents[1]), // minute
          );
        }
      }
      return null;
    } catch (e) {
      print('❌ [CALENDAR] Error parsing enrollment date: $regText - $e');
      return null;
    }
  }
  
  /// Determine error type from error messages
  static CalendarErrorType _determineErrorType(List<String> errors) {
    if (errors.isEmpty) return CalendarErrorType.none;
    
    final errorText = errors.join(' ').toLowerCase();
    
    if (errorText.contains('timeout')) return CalendarErrorType.timeout;
    if (errorText.contains('permission')) return CalendarErrorType.permission;
    if (errorText.contains('invalid')) return CalendarErrorType.invalidData;
    if (errorText.contains('network')) return CalendarErrorType.network;
    
    return CalendarErrorType.unknown;
  }
  
  /// Show appropriate user feedback based on calendar result
  static void showUserFeedback(BuildContext context, CalendarResult result) {
    if (result.success) {
      if (result.eventsAdded > 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${result.eventsAdded} agenda items toegevoegd!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Agenda bijgewerkt!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      // Show error dialog for better user experience
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text(
            'Agenda Toevoegen Mislukt',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          content: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              _getErrorMessage(result),
              style: const TextStyle(fontSize: 14),
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
    }
  }
  
  /// Get user-friendly error message
  static String _getErrorMessage(CalendarResult result) {
    switch (result.errorType) {
      case CalendarErrorType.permission:
        return 'Agenda toegang is geweigerd. Ga naar je apparaat instellingen en geef JachtProef Alert toegang tot je agenda.';
      case CalendarErrorType.timeout:
        return 'De agenda app reageerde niet op tijd. Probeer het opnieuw of controleer je agenda app handmatig.';
      case CalendarErrorType.network:
        return 'Netwerk probleem. Controleer je internetverbinding en probeer het opnieuw.';
      case CalendarErrorType.invalidData:
        return 'De proef gegevens zijn ongeldig. Probeer het later opnieuw.';
      case CalendarErrorType.unknown:
      default:
        return 'Er is een onverwachte fout opgetreden: ${result.error ?? 'Onbekende fout'}. Probeer het opnieuw.';
    }
  }
  
  /// Check if event is already in calendar (cache-based)
  static bool isEventInCalendar(String eventKey) {
    return _eventCache[eventKey] ?? false;
  }
  
  /// Mark event as added to calendar
  static void markEventAsAdded(String eventKey) {
    _eventCache[eventKey] = true;
  }
  
  /// Clear event cache
  static void clearCache() {
    _eventCache.clear();
  }
}

/// Data class for match calendar information
class MatchCalendarData {
  final String title;
  final String location;
  final String description;
  final DateTime? matchDate;
  final DateTime? enrollmentDate;
  
  MatchCalendarData({
    required this.title,
    required this.location,
    required this.description,
    this.matchDate,
    this.enrollmentDate,
  });
}

/// Result of calendar operation
class CalendarResult {
  final bool success;
  final int eventsAdded;
  final String? error;
  final CalendarErrorType errorType;
  
  CalendarResult({
    required this.success,
    required this.eventsAdded,
    this.error,
    required this.errorType,
  });
}

/// Result of single event operation
class EventResult {
  final bool success;
  final String? error;
  
  EventResult({
    required this.success,
    this.error,
  });
}

/// Types of calendar errors
enum CalendarErrorType {
  none,
  permission,
  timeout,
  network,
  invalidData,
  unknown,
} 