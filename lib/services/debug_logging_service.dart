import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Comprehensive debug logging service for TestFlight testing
/// Provides real-time logs visible in Xcode Console when iPhone is connected to MacBook
class DebugLoggingService {
  static final DebugLoggingService _instance = DebugLoggingService._internal();
  factory DebugLoggingService() => _instance;
  DebugLoggingService._internal();

  bool _isEnabled = false;
  bool _isVerbose = false;
  List<String> _logBuffer = [];
  static const int _maxBufferSize = 1000;

  /// Initialize debug logging service
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool('debug_logging_enabled') ?? kDebugMode;
      _isVerbose = prefs.getBool('debug_logging_verbose') ?? false;
      
      log('🔧 DebugLoggingService initialized', level: 'INFO');
      log('📱 Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}', level: 'INFO');
      log('🔍 Debug mode: $kDebugMode', level: 'INFO');
      log('📊 Verbose logging: $_isVerbose', level: 'INFO');
      
      // Log device info for debugging
      _logDeviceInfo();
      
    } catch (e) {
      print('❌ Error initializing DebugLoggingService: $e');
    }
  }

  /// Log device information
  void _logDeviceInfo() {
    log('📱 Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}', level: 'INFO');
  }

  /// Main logging method
  void log(String message, {
    String level = 'INFO',
    String? tag,
    Map<String, dynamic>? data,
    StackTrace? stackTrace,
  }) {
    if (!_isEnabled) return;

    final timestamp = DateTime.now().toIso8601String();
    final logTag = tag ?? 'JachtProef';
    final logMessage = '[$timestamp] [$level] [$logTag] $message';
    
    // Add to buffer
    _addToBuffer(logMessage);
    
    // Print to console (visible in Xcode Console)
    print(logMessage);
    
    // Log to Firebase Crashlytics for errors
    if (level == 'ERROR' || level == 'FATAL') {
      _logToCrashlytics(message, stackTrace, data);
    }
    
    // Log to Firebase Analytics for important events
    if (level == 'EVENT' && data != null) {
      _logToAnalytics(message, data);
    }
    
    // Developer log for detailed debugging
    if (_isVerbose) {
      developer.log(
        message,
        name: logTag,
        level: _getLogLevel(level),
        error: level == 'ERROR' ? message : null,
        stackTrace: stackTrace,
      );
    }
  }

  /// Add message to circular buffer
  void _addToBuffer(String message) {
    _logBuffer.add(message);
    if (_logBuffer.length > _maxBufferSize) {
      _logBuffer.removeAt(0);
    }
  }

  /// Log to Firebase Crashlytics
  void _logToCrashlytics(String message, StackTrace? stackTrace, Map<String, dynamic>? data) {
    try {
      FirebaseCrashlytics.instance.log(message);
      if (data != null) {
        data.forEach((key, value) {
          FirebaseCrashlytics.instance.setCustomKey(key, value.toString());
        });
      }
      if (stackTrace != null) {
        FirebaseCrashlytics.instance.recordError(message, stackTrace);
      }
    } catch (e) {
      print('❌ Error logging to Crashlytics: $e');
    }
  }

  /// Log to Firebase Analytics
  void _logToAnalytics(String eventName, Map<String, dynamic> parameters) {
    try {
      FirebaseAnalytics.instance.logEvent(
        name: eventName,
        parameters: parameters.cast<String, Object>(),
      );
    } catch (e) {
      print('❌ Error logging to Analytics: $e');
    }
  }

  /// Get log level for developer.log
  int _getLogLevel(String level) {
    switch (level.toUpperCase()) {
      case 'FATAL': return 0;
      case 'ERROR': return 1000;
      case 'WARN': return 2000;
      case 'INFO': return 3000;
      case 'DEBUG': return 4000;
      case 'VERBOSE': return 5000;
      default: return 3000;
    }
  }

  /// Enable/disable debug logging
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('debug_logging_enabled', enabled);
    log('🔧 Debug logging ${enabled ? 'enabled' : 'disabled'}', level: 'INFO');
  }

  /// Enable/disable verbose logging
  Future<void> setVerbose(bool verbose) async {
    _isVerbose = verbose;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('debug_logging_verbose', verbose);
    log('🔧 Verbose logging ${verbose ? 'enabled' : 'disabled'}', level: 'INFO');
  }

  /// Get recent logs
  List<String> getRecentLogs({int count = 50}) {
    final startIndex = _logBuffer.length > count ? _logBuffer.length - count : 0;
    return _logBuffer.sublist(startIndex);
  }

  /// Clear log buffer
  void clearLogs() {
    _logBuffer.clear();
    log('🧹 Log buffer cleared', level: 'INFO');
  }

  /// Export logs to string
  String exportLogs() {
    return _logBuffer.join('\n');
  }

  // Convenience methods for different log levels
  void debug(String message, {String? tag, Map<String, dynamic>? data}) {
    log(message, level: 'DEBUG', tag: tag, data: data);
  }

  void info(String message, {String? tag, Map<String, dynamic>? data}) {
    log(message, level: 'INFO', tag: tag, data: data);
  }

  void warn(String message, {String? tag, Map<String, dynamic>? data}) {
    log(message, level: 'WARN', tag: tag, data: data);
  }

  void error(String message, {String? tag, Map<String, dynamic>? data, StackTrace? stackTrace}) {
    log(message, level: 'ERROR', tag: tag, data: data, stackTrace: stackTrace);
  }

  void fatal(String message, {String? tag, Map<String, dynamic>? data, StackTrace? stackTrace}) {
    log(message, level: 'FATAL', tag: tag, data: data, stackTrace: stackTrace);
  }

  void event(String eventName, {Map<String, dynamic>? data}) {
    log(eventName, level: 'EVENT', tag: 'ANALYTICS', data: data);
  }

  // Performance tracking methods
  void startTrace(String traceName) {
    log('⏱️ Starting trace: $traceName', level: 'INFO', tag: 'PERFORMANCE');
  }

  void endTrace(String traceName, {Duration? duration}) {
    final durationStr = duration != null ? ' (${duration.inMilliseconds}ms)' : '';
    log('⏱️ Ended trace: $traceName$durationStr', level: 'INFO', tag: 'PERFORMANCE');
  }

  // Network request logging
  void logNetworkRequest(String method, String url, {Map<String, dynamic>? headers, dynamic body}) {
    log('🌐 $method $url', level: 'INFO', tag: 'NETWORK');
    if (_isVerbose) {
      if (headers != null) {
        log('📋 Headers: $headers', level: 'DEBUG', tag: 'NETWORK');
      }
      if (body != null) {
        log('📦 Body: $body', level: 'DEBUG', tag: 'NETWORK');
      }
    }
  }

  void logNetworkResponse(String method, String url, int statusCode, {dynamic response, Duration? duration}) {
    final durationStr = duration != null ? ' (${duration.inMilliseconds}ms)' : '';
    final statusIcon = statusCode >= 200 && statusCode < 300 ? '✅' : '❌';
    log('$statusIcon $method $url - $statusCode$durationStr', level: 'INFO', tag: 'NETWORK');
    if (_isVerbose && response != null) {
      log('📥 Response: $response', level: 'DEBUG', tag: 'NETWORK');
    }
  }

  // User interaction logging
  void logUserAction(String action, {Map<String, dynamic>? data}) {
    log('👤 User action: $action', level: 'INFO', tag: 'USER', data: data);
  }

  void logScreenView(String screenName) {
    log('📱 Screen view: $screenName', level: 'INFO', tag: 'NAVIGATION');
  }

  // Payment logging
  void logPaymentEvent(String event, {Map<String, dynamic>? data}) {
    log('💳 Payment: $event', level: 'INFO', tag: 'PAYMENT', data: data);
  }

  // Notification logging
  void logNotificationEvent(String event, {Map<String, dynamic>? data}) {
    log('🔔 Notification: $event', level: 'INFO', tag: 'NOTIFICATION', data: data);
  }

  // Firebase logging
  void logFirebaseEvent(String event, {Map<String, dynamic>? data}) {
    log('🔥 Firebase: $event', level: 'INFO', tag: 'FIREBASE', data: data);
  }

  // TestFlight specific logging
  void logTestFlightEvent(String event, {Map<String, dynamic>? data}) {
    log('✈️ TestFlight: $event', level: 'INFO', tag: 'TESTFLIGHT', data: data);
  }
} 