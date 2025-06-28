import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'debug_logging_service.dart';

/// Performance monitoring service for tracking app performance metrics
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  final DebugLoggingService _logger = DebugLoggingService();
  final Map<String, Stopwatch> _activeTraces = {};
  final Map<String, List<Duration>> _performanceHistory = {};
  
  // Memory monitoring
  Timer? _memoryTimer;
  bool _isMonitoring = false;

  /// Start performance monitoring
  void startMonitoring() {
    if (_isMonitoring) return;
    
    _isMonitoring = true;
    _logger.info('📊 Performance monitoring started', tag: 'PERFORMANCE');
    
    // Monitor memory usage every 30 seconds
    _memoryTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _logMemoryUsage();
    });
  }

  /// Stop performance monitoring
  void stopMonitoring() {
    if (!_isMonitoring) return;
    
    _isMonitoring = false;
    _memoryTimer?.cancel();
    _memoryTimer = null;
    _logger.info('📊 Performance monitoring stopped', tag: 'PERFORMANCE');
  }

  /// Start a performance trace
  void startTrace(String traceName) {
    if (_activeTraces.containsKey(traceName)) {
      _logger.warn('📊 Trace already active: $traceName', tag: 'PERFORMANCE');
      return;
    }
    
    final stopwatch = Stopwatch()..start();
    _activeTraces[traceName] = stopwatch;
    _logger.startTrace(traceName);
  }

  /// End a performance trace
  void endTrace(String traceName) {
    final stopwatch = _activeTraces.remove(traceName);
    if (stopwatch == null) {
      _logger.warn('📊 No active trace found: $traceName', tag: 'PERFORMANCE');
      return;
    }
    
    stopwatch.stop();
    final duration = stopwatch.elapsed;
    
    // Store in history
    _performanceHistory.putIfAbsent(traceName, () => []).add(duration);
    
    // Keep only last 10 measurements
    if (_performanceHistory[traceName]!.length > 10) {
      _performanceHistory[traceName]!.removeAt(0);
    }
    
    _logger.endTrace(traceName, duration: duration);
    
    // Log performance statistics
    _logPerformanceStats(traceName);
  }

  /// Log memory usage
  Future<void> _logMemoryUsage() async {
    try {
      // Get memory info from platform
      const platform = MethodChannel('performance_monitor');
      final result = await platform.invokeMethod('getMemoryInfo');
      
      if (result != null) {
        _logger.info('📊 Memory usage', tag: 'PERFORMANCE', data: {
          'used_memory_mb': result['usedMemoryMB'],
          'total_memory_mb': result['totalMemoryMB'],
          'free_memory_mb': result['freeMemoryMB'],
          'memory_pressure': result['memoryPressure'],
        });
      }
    } catch (e) {
      // Fallback to basic memory info
      _logger.debug('📊 Basic memory monitoring', tag: 'PERFORMANCE', data: {
        'note': 'Detailed memory info not available',
        'error': e.toString(),
      });
    }
  }

  /// Log performance statistics for a trace
  void _logPerformanceStats(String traceName) {
    final history = _performanceHistory[traceName];
    if (history == null || history.isEmpty) return;
    
    final avgDuration = history.fold(Duration.zero, (a, b) => a + b) ~/ history.length;
    final minDuration = history.reduce((a, b) => a < b ? a : b);
    final maxDuration = history.reduce((a, b) => a > b ? a : b);
    
    _logger.info('📊 Performance stats for $traceName', tag: 'PERFORMANCE', data: {
      'average_ms': avgDuration.inMilliseconds,
      'min_ms': minDuration.inMilliseconds,
      'max_ms': maxDuration.inMilliseconds,
      'samples': history.length,
    });
  }

  /// Get performance report
  Map<String, dynamic> getPerformanceReport() {
    final report = <String, dynamic>{};
    
    for (final entry in _performanceHistory.entries) {
      final traceName = entry.key;
      final history = entry.value;
      
      if (history.isNotEmpty) {
        final avgDuration = history.fold(Duration.zero, (a, b) => a + b) ~/ history.length;
        report[traceName] = {
          'average_ms': avgDuration.inMilliseconds,
          'samples': history.length,
          'last_ms': history.last.inMilliseconds,
        };
      }
    }
    
    return report;
  }

  /// Clear performance history
  void clearHistory() {
    _performanceHistory.clear();
    _logger.info('📊 Performance history cleared', tag: 'PERFORMANCE');
  }

  /// Log app startup performance
  void logAppStartup() {
    startTrace('app_startup');
    
    // End startup trace after a delay to capture full startup
    Timer(const Duration(seconds: 5), () {
      endTrace('app_startup');
    });
  }

  /// Log screen load performance
  void logScreenLoad(String screenName) {
    startTrace('screen_load_$screenName');
    
    // End screen load trace after a short delay
    Timer(const Duration(milliseconds: 500), () {
      endTrace('screen_load_$screenName');
    });
  }

  /// Log data loading performance
  void logDataLoad(String dataType) {
    startTrace('data_load_$dataType');
  }

  /// End data loading performance
  void endDataLoad(String dataType) {
    endTrace('data_load_$dataType');
  }
} 