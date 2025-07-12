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

  // === REAL USER TRACKING ENHANCEMENTS ===
  
  // User Journey Tracking
  static Future<void> logUserJourney(String journeyStep, {Map<String, Object>? context}) async {
    await _analytics.logEvent(
      name: 'user_journey',
      parameters: {
        'journey_step': journeyStep,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        ...?context,
      },
    );
  }

  // Subscription & Revenue Tracking
  static Future<void> logSubscriptionEvent(String event, {
    String? planType,
    double? revenue,
    String? currency = 'EUR',
  }) async {
    await _analytics.logEvent(
      name: 'subscription_$event',
      parameters: {
        if (planType != null) 'plan_type': planType,
        if (revenue != null) 'value': revenue,
        if (currency != null) 'currency': currency,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  // Engagement Quality Tracking
  static Future<void> logEngagementQuality({
    required int sessionsThisWeek,
    required int examsViewedThisWeek,
    required int calendarAddsThisWeek,
  }) async {
    await _analytics.logEvent(
      name: 'engagement_quality',
      parameters: {
        'sessions_weekly': sessionsThisWeek,
        'exams_viewed_weekly': examsViewedThisWeek,
        'calendar_adds_weekly': calendarAddsThisWeek,
        'engagement_score': (sessionsThisWeek * 2) + (examsViewedThisWeek * 3) + (calendarAddsThisWeek * 5),
      },
    );
  }

  // Feature Discovery Tracking
  static Future<void> logFeatureDiscovery(String featureName, String discoveryMethod) async {
    await _analytics.logEvent(
      name: 'feature_discovery',
      parameters: {
        'feature_name': featureName,
        'discovery_method': discoveryMethod, // 'tutorial', 'exploration', 'notification'
        'user_session_number': await _getUserSessionNumber(),
      },
    );
  }

  // User Satisfaction Tracking
  static Future<void> logUserSatisfactionSignal(String signal, {Map<String, Object>? context}) async {
    await _analytics.logEvent(
      name: 'satisfaction_signal',
      parameters: {
        'signal_type': signal, // 'app_background', 'quick_return', 'long_session'
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        ...?context,
      },
    );
  }

  // Quick Setup Flow Tracking
  static Future<void> logQuickSetupStep(String step, bool completed, {String? errorReason}) async {
    await _analytics.logEvent(
      name: 'quick_setup_step',
      parameters: {
        'step_name': step,
        'completed': completed,
        if (errorReason != null) 'error_reason': errorReason,
        'step_timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  // Real User Cohort Tracking
  static Future<void> logCohortMilestone(String milestone, int daysSinceInstall) async {
    await _analytics.logEvent(
      name: 'cohort_milestone',
      parameters: {
        'milestone': milestone, // 'first_exam_view', 'first_calendar_add', 'week_1_retention'
        'days_since_install': daysSinceInstall,
        'user_segment': await _getUserSegment(),
      },
    );
  }

  // Helper Methods
  static Future<int> _getUserSessionNumber() async {
    // Implement session counting logic
    return 1; // Placeholder
  }

  static Future<String> _getUserSegment() async {
    // Determine user segment: 'trial', 'premium', 'churned'
    return 'unknown'; // Placeholder - implement based on your user data
  }
} 