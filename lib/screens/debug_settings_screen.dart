import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../services/debug_logging_service.dart';
import '../utils/constants.dart';
import '../services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DebugSettingsScreen extends StatefulWidget {
  const DebugSettingsScreen({Key? key}) : super(key: key);

  @override
  State<DebugSettingsScreen> createState() => _DebugSettingsScreenState();
}

class _DebugSettingsScreenState extends State<DebugSettingsScreen> {
  bool _debugLoggingEnabled = false;
  bool _verboseLoggingEnabled = false;
  List<String> _recentLogs = [];
  final ScrollController _logScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadRecentLogs();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _debugLoggingEnabled = prefs.getBool('debug_logging_enabled') ?? false;
      _verboseLoggingEnabled = prefs.getBool('debug_logging_verbose') ?? false;
    });
  }

  void _loadRecentLogs() {
    setState(() {
      _recentLogs = DebugLoggingService().getRecentLogs(count: 100);
    });
  }

  Future<void> _toggleDebugLogging(bool value) async {
    await DebugLoggingService().setEnabled(value);
    setState(() {
      _debugLoggingEnabled = value;
    });
    _loadRecentLogs();
  }

  Future<void> _toggleVerboseLogging(bool value) async {
    await DebugLoggingService().setVerbose(value);
    setState(() {
      _verboseLoggingEnabled = value;
    });
    _loadRecentLogs();
  }

  void _clearLogs() {
    DebugLoggingService().clearLogs();
    _loadRecentLogs();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logs cleared')),
    );
  }

  void _exportLogs() {
    final logs = DebugLoggingService().exportLogs();
    Clipboard.setData(ClipboardData(text: logs));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logs copied to clipboard')),
    );
  }

  void _refreshLogs() {
    _loadRecentLogs();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logs refreshed')),
    );
  }

  void _testLogging() {
    DebugLoggingService().info('🧪 Test info log from debug settings', tag: 'TEST');
    DebugLoggingService().debug('🧪 Test debug log from debug settings', tag: 'TEST');
    DebugLoggingService().warn('🧪 Test warning log from debug settings', tag: 'TEST');
    DebugLoggingService().error('🧪 Test error log from debug settings', tag: 'TEST');
    DebugLoggingService().event('test_event', data: {'source': 'debug_settings'});
    DebugLoggingService().logUserAction('test_action', data: {'button': 'test_logging'});
    DebugLoggingService().logScreenView('debug_settings_screen');
    DebugLoggingService().logPaymentEvent('test_payment', data: {'amount': 9.99});
    DebugLoggingService().logNotificationEvent('test_notification', data: {'type': 'test'});
    DebugLoggingService().logFirebaseEvent('test_firebase', data: {'collection': 'test'});
    DebugLoggingService().logTestFlightEvent('test_testflight', data: {'build': '10415'});
    
    _loadRecentLogs();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Test logs generated')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Instellingen'),
        backgroundColor: kMainColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshLogs,
            tooltip: 'Refresh logs',
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _exportLogs,
            tooltip: 'Export logs',
          ),
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: _clearLogs,
            tooltip: 'Clear logs',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Settings Section
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Debug Logging Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Debug Logging Toggle
                    SwitchListTile(
                      title: const Text('Enable Debug Logging'),
                      subtitle: const Text('Show detailed logs in Xcode Console'),
                      value: _debugLoggingEnabled,
                      onChanged: _toggleDebugLogging,
                      secondary: const Icon(Icons.bug_report, color: kMainColor),
                    ),
                    
                    // Verbose Logging Toggle
                    SwitchListTile(
                      title: const Text('Verbose Logging'),
                      subtitle: const Text('Show extra detailed logs (may be noisy)'),
                      value: _verboseLoggingEnabled,
                      onChanged: _debugLoggingEnabled ? _toggleVerboseLogging : null,
                      secondary: const Icon(Icons.article, color: kMainColor),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Test Logging Button
                    ElevatedButton.icon(
                      onPressed: _debugLoggingEnabled ? _testLogging : null,
                      icon: const Icon(Icons.science),
                      label: const Text('Generate Test Logs'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kMainColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Instructions
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '📱 How to View Logs:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          Text('1. Connect iPhone to MacBook'),
                          Text('2. Open Xcode → Window → Devices and Simulators'),
                          Text('3. Select your iPhone → View Device Logs'),
                          Text('4. Filter by "JachtProef" to see app logs'),
                          Text('5. Or use Console.app and filter by your app'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Force Sign Out Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.logout, color: Colors.red[700], size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Authentication Debug',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Current User: ${context.read<AuthService>().currentUser?.email ?? 'None'}',
                      style: const TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          await context.read<AuthService>().signOut();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Successfully signed out! You can now test the full authentication flow.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            // Navigate back to main app to trigger AuthWrapper
                            Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error signing out: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.logout, color: Colors.white),
                      label: const Text('Force Sign Out'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[600],
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // New Reset Button
                    ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          final user = context.read<AuthService>().currentUser;
                          if (user != null) {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid)
                                .update({'paymentSetupCompleted': false});
                            
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Payment state reset! Please restart the app.'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            }
                          }
                        } catch (e) {
                           if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error resetting state: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                        }
                      },
                      icon: const Icon(Icons.payment, color: Colors.white),
                      label: const Text('Reset Payment State'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[700],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              
              const Divider(),
              
              // Logs Section
              Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent Logs (${_recentLogs.length})',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Tap to copy',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(
                      height: 300, // Give logs a fixed height
                      child: _recentLogs.isEmpty
                          ? const Center(
                              child: Text(
                                'No logs available\nEnable debug logging to see logs here',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              controller: _logScrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _recentLogs.length,
                              itemBuilder: (context, index) {
                                final log = _recentLogs[index];
                                final isError = log.contains('[ERROR]') || log.contains('[FATAL]');
                                final isWarning = log.contains('[WARN]');
                                final isInfo = log.contains('[INFO]');
                                final isDebug = log.contains('[DEBUG]');
                                
                                Color textColor = Colors.black87;
                                if (isError) textColor = Colors.red.shade700;
                                else if (isWarning) textColor = Colors.orange.shade700;
                                else if (isInfo) textColor = Colors.blue.shade700;
                                else if (isDebug) textColor = Colors.grey.shade600;
                                
                                return GestureDetector(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: log));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Log copied: ${log.substring(0, log.length > 50 ? 50 : log.length)}...'),
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 4),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isError 
                                          ? Colors.red.shade50 
                                          : isWarning 
                                              ? Colors.orange.shade50 
                                              : Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: isError 
                                            ? Colors.red.shade200 
                                            : isWarning 
                                                ? Colors.orange.shade200 
                                                : Colors.grey.shade200,
                                      ),
                                    ),
                                    child: Text(
                                      log,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontFamily: 'monospace',
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
} 