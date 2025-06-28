import 'dart:async';
import 'package:flutter/material.dart';

class DeepLinkService {
  static StreamController<String>? _linkStreamController;
  static Stream<String>? _linkStream;

  /// Initialize deep link handling
  static Future<void> initialize() async {
    try {
      _linkStreamController = StreamController<String>.broadcast();
      _linkStream = _linkStreamController!.stream;
      
      print('🔗 Deep link service initialized');
    } catch (e) {
      print('❌ Error initializing deep link service: $e');
    }
  }

  /// Get the stream of incoming deep links
  static Stream<String>? get linkStream => _linkStream;

  /// Process a deep link and navigate accordingly
  static void handleDeepLink(BuildContext context, String link) {
    print('🔗 Processing deep link: $link');
    
    if (link.startsWith('jachtproefalert://')) {
      final uri = Uri.parse(link);
      final String path = uri.host + uri.path;
      
      switch (path) {
        case 'open':
          // General app open - go to home screen
          print('🏠 Deep link: Opening app home');
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
          break;
          
        case 'plan-selection':
          // Navigate to plan selection screen
          print('💳 Deep link: Opening plan selection');
          Navigator.of(context).pushNamedAndRemoveUntil('/plan-selection', (route) => false);
          break;
          
        case 'plans':
        case 'subscription':
          // Alternative plan selection paths
          print('💳 Deep link: Opening plan selection (alternative)');
          Navigator.of(context).pushNamedAndRemoveUntil('/plan-selection', (route) => false);
          break;
          
        case 'matches':
          // Navigate to matches screen
          print('🎯 Deep link: Opening matches');
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
          // Additional navigation to matches tab can be added here
          break;
          
        case 'profile':
          // Navigate to profile/settings
          print('👤 Deep link: Opening profile');
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
          // Additional navigation to profile can be added here
          break;
          
        default:
          print('🔗 Unknown deep link path: $path, opening app home');
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
          break;
      }
    } else {
      print('🔗 Non-jachtproefalert deep link, ignoring: $link');
    }
  }

  /// Test deep link functionality
  static Future<void> testDeepLink(String testLink) async {
    print('🧪 Testing deep link: $testLink');
    _linkStreamController?.add(testLink);
  }

  /// Dispose resources
  static void dispose() {
    _linkStreamController?.close();
    _linkStreamController = null;
    _linkStream = null;
  }
}

/// Widget to listen for deep links in your main app
class DeepLinkListener extends StatefulWidget {
  final Widget child;
  
  const DeepLinkListener({Key? key, required this.child}) : super(key: key);

  @override
  State<DeepLinkListener> createState() => _DeepLinkListenerState();
}

class _DeepLinkListenerState extends State<DeepLinkListener> {
  StreamSubscription<String>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initializeDeepLinks();
  }

  void _initializeDeepLinks() {
    DeepLinkService.linkStream?.listen((String link) {
      if (mounted) {
        DeepLinkService.handleDeepLink(context, link);
      }
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
} 