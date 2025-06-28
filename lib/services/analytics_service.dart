import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static final FirebasePerformance _performance = FirebasePerformance.instance;
  static final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  // User Behavior Tracking
  static Future<void> logAppOpen() async {
    await _analytics.logAppOpen();
  }

  static Future<void> logScreenView(String screenName) async {
    await _analytics.logScreenView(screenName: screenName);
  }

  static Future<void> logUserAction(String action, {Map<String, Object>? parameters}) async {
    await _analytics.logEvent(name: action, parameters: parameters);
  }

  // Feature Usage Tracking
  static Future<void> logFeatureUsed(String featureName) async {
    await _analytics.logEvent(
      name: 'feature_used',
      parameters: {'feature_name': featureName},
    );
  }

  static Future<void> logNotificationClick(String notificationType) async {
    await _analytics.logEvent(
      name: 'notification_click',
      parameters: {'notification_type': notificationType},
    );
  }

  static Future<void> logExamView(String examId, String examType) async {
    await _analytics.logEvent(
      name: 'exam_viewed',
      parameters: {
        'exam_id': examId,
        'exam_type': examType,
      },
    );
  }

  static Future<void> logCalendarAdd(String examId) async {
    await _analytics.logEvent(
      name: 'calendar_add',
      parameters: {'exam_id': examId},
    );
  }

  // Performance Tracking
  static HttpMetric createHttpMetric(String url, String httpMethod) {
    return _performance.newHttpMetric(url, HttpMethod.values.firstWhere(
      (method) => method.toString().split('.').last.toUpperCase() == httpMethod.toUpperCase(),
      orElse: () => HttpMethod.Get,
    ));
  }

  static Trace createTrace(String traceName) {
    return _performance.newTrace(traceName);
  }

  // App Launch Time Tracking
  static Future<void> trackAppLaunchTime() async {
    final trace = _performance.newTrace('app_launch');
    await trace.start();
    // This should be called when app is fully loaded
    await trace.stop();
  }

  // Session Duration Tracking
  static Trace? _sessionTrace;
  
  static Future<void> startSession() async {
    _sessionTrace = _performance.newTrace('user_session');
    await _sessionTrace?.start();
  }

  static Future<void> endSession() async {
    await _sessionTrace?.stop();
    _sessionTrace = null;
  }

  // Error and Crash Reporting
  static Future<void> recordError(
    dynamic exception,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  }) async {
    await _crashlytics.recordError(
      exception,
      stackTrace,
      reason: reason,
      fatal: fatal,
    );
  }

  static Future<void> setUserId(String userId) async {
    await _analytics.setUserId(id: userId);
    await _crashlytics.setUserIdentifier(userId);
  }

  static Future<void> setUserProperty(String name, String value) async {
    await _analytics.setUserProperty(name: name, value: value);
  }

  // Custom App-Specific Events
  static Future<void> logHuntingExamSearch({
    String? region,
    String? examType,
    String? dateFilter,
  }) async {
    await _analytics.logEvent(
      name: 'hunting_exam_search',
      parameters: {
        if (region != null) 'region': region,
        if (examType != null) 'exam_type': examType,
        if (dateFilter != null) 'date_filter': dateFilter,
      },
    );
  }

  static Future<void> logRegistrationAttempt(String examId, bool success) async {
    await _analytics.logEvent(
      name: 'registration_attempt',
      parameters: {
        'exam_id': examId,
        'success': success,
      },
    );
  }

  static Future<void> logFilterUsed(String filterType, String filterValue) async {
    await _analytics.logEvent(
      name: 'filter_used',
      parameters: {
        'filter_type': filterType,
        'filter_value': filterValue,
      },
    );
  }

  // Get Analytics Instance for Advanced Usage
  static FirebaseAnalytics get instance => _analytics;
} 