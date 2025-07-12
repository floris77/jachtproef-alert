import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'analytics_service.dart';
import 'plan_abandonment_service.dart';
import 'email_notification_service.dart';
import 'debug_logging_service.dart';
import 'package:flutter/foundation.dart';
import '../utils/constants.dart';

const bool kShowDebug = false; // Set to true for debug/test users

/// Development mode flag - set to true to force Apple payment dialog in development
const bool kForcePaymentDialogInDevelopment = true;

/// Payment Service that handles 14-day free trial and subscription management
/// 
/// =================================================================================
/// CRITICAL INITIALIZATION FIX - READ BEFORE MODIFYING
/// =================================================================================
/// 
/// ISSUE RESOLVED: Apple payment dialog not appearing on iOS
/// 
/// ROOT CAUSE: PaymentService was being reset after successful initialization
/// 
/// The problem was in main.dart:
/// 1. PaymentService initializes successfully (_isAvailable = true, products loaded)
/// 2. _clearDeviceStateOnStartup() calls cleanupOldDormantPayments()
/// 3. cleanupOldDormantPayments() resets PaymentService state:
///    - _isAvailable = false
///    - _products.clear()
///    - _inAppPurchase = null
/// 4. Payment flow fails with "payment_not_available" error
/// 
/// SOLUTION:
/// - Removed _clearDeviceStateOnStartup() call from main() startup
/// - Added comprehensive warnings to cleanupOldDormantPayments()
/// - Use ChangeNotifierProvider.value() to ensure same instance is used
/// 
/// CRITICAL RULES:
/// - NEVER call cleanupOldDormantPayments() during normal app startup
/// - ONLY call it for debugging/testing via debug settings
/// - PaymentService uses singleton pattern - ensure same instance is used
/// - If PaymentService needs refresh, use forceRefreshPaymentService() instead
/// 
/// =================================================================================
/// PLATFORM SEPARATION:
/// - iOS: Uses separate product IDs (jachtproef_monthly_399, jachtproef_yearly_2999)
/// - Android: Uses single subscription ID with base plans (jachtproef_premium)
/// - TestFlight: Has auto-approval behavior that needs special handling
/// - App Store: Shows payment dialogs and requires user confirmation
class PaymentService extends ChangeNotifier {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  InAppPurchase? _inAppPurchase;
  FirebaseFirestore? _firestore;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  
  // Map to track pending purchase completers
  final Map<String, Completer<bool>> _pendingPurchaseCompleters = {};

  // CHROMEBOOK DEBUG: Add device detection
  static bool? _isChromebook;
  static String? _deviceInfo;

  // Flag to prevent multiple simultaneous initializations
  static bool _isInitializing = false;

  /// Detect if running on Chromebook
  static Future<bool> isChromebook() async {
    if (_isChromebook != null) return _isChromebook!;
    
    try {
      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      _deviceInfo = '${deviceInfo.brand} ${deviceInfo.model}';
      _isChromebook = deviceInfo.brand.toLowerCase().contains('chromebook') ||
                     deviceInfo.model.toLowerCase().contains('chromebook');
      } catch (e) {
        _isChromebook = false;
      }
      return _isChromebook!;
  }

  // =================================================================================
  // PLATFORM-SPECIFIC PRODUCT ID CONFIGURATION
  // Do not modify without understanding the platform differences.
  //
  // Apple (iOS): Uses unique product IDs for each subscription plan.
  //   - 'jachtproef_monthly_399'
  //   - 'jachtproef_yearly_2999'
  //
  // Google (Android): Uses a SINGLE main subscription ID ('jachtproef_premium')
  // and differentiates plans using 'base plans' ('monthly', 'yearly') which are
  // passed via the 'planType' parameter in the purchase flow.
  // =================================================================================
  
  /// Get the monthly subscription product ID for the current platform
  static String get monthlySubscriptionId {
    if (Platform.isIOS) {
      return 'jachtproef_monthly_399';  // Apple App Store Connect format
    } else if (Platform.isAndroid) {
      return 'jachtproef_premium';  // Google Play Console format - main subscription ID
    }
    throw UnsupportedError('Platform not supported for subscriptions');
  }

  /// Get the yearly subscription product ID for the current platform
  static String get yearlySubscriptionId {
    if (Platform.isIOS) {
      return 'jachtproef_yearly_2999';  // Apple App Store Connect format
    } else if (Platform.isAndroid) {
      return 'jachtproef_premium';  // Google Play Console format - same subscription ID, different base plan
    }
    throw UnsupportedError('Platform not supported for subscriptions');
  }

  /// Get the specific base plan ID for Android monthly subscriptions
  static String getMonthlyBasePlanId() {
    if (Platform.isAndroid) {
      return 'monthly';  // Base plan ID for monthly subscription
    }
    return '';
  }

  /// Get the specific base plan ID for Android yearly subscriptions
  static String getYearlyBasePlanId() {
    if (Platform.isAndroid) {
      return 'yearly';  // Base plan ID for yearly subscription
    }
    return '';
  }

  /// Get all product IDs that should be loaded for the current platform
  static Set<String> get _productIds => {
    monthlySubscriptionId,
    yearlySubscriptionId,
  };

  // Trial period in days
  static const int trialPeriodDays = 14;

  bool _isAvailable = false;
  List<ProductDetails> _products = [];

  /// Initialize the payment service
  Future<void> initialize() async {
    print('🔍 Initialize: Starting payment service initialization');
    
    if (_isAvailable && _inAppPurchase != null) {
      print('🔍 Initialize: Already available and properly initialized, skipping');
      return;
    }
      
    if (_isInitializing) {
      print('🔍 Initialize: Initialization already in progress, waiting...');
      // Wait for the current initialization to complete
      while (_isInitializing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      print('🔍 Initialize: Initialization completed by another call');
      return;
    }
    
    _isInitializing = true;
    
    try {
      // Ensure Firebase is initialized
      _firestore = FirebaseFirestore.instance;
      
      // Initialize InAppPurchase instance
      _inAppPurchase = InAppPurchase.instance;
      
      // Enhanced availability check with retry logic for real devices
      bool isAvailable = false;
      int retryCount = 0;
      const maxRetries = 3;
      
      while (!isAvailable && retryCount < maxRetries) {
        try {
          isAvailable = await InAppPurchase.instance.isAvailable();
          print('🔍 Initialize: InAppPurchase available (attempt ${retryCount + 1}): $isAvailable');
          
          if (!isAvailable && retryCount < maxRetries - 1) {
            print('🔍 Initialize: IAP not available, retrying in 2 seconds...');
            await Future.delayed(const Duration(seconds: 2));
          }
        } catch (e) {
          print('⚠️ Initialize: Error checking IAP availability (attempt ${retryCount + 1}): $e');
          if (retryCount < maxRetries - 1) {
            await Future.delayed(const Duration(seconds: 2));
          }
        }
        retryCount++;
      }
      
      // Platform-specific availability handling
      if (Platform.isIOS) {
        final isSimulator = await _isRunningOnSimulator();
        final isTestFlightMac = await _isRunningOnTestFlightMac();
        
        if (isSimulator) {
          print('🔍 Initialize: iOS Simulator detected, forcing IAP available');
          _isAvailable = true;
        } else if (isTestFlightMac) {
          print('🧪 Initialize: TestFlight on Mac detected, forcing IAP available');
          _isAvailable = true;
        } else if (!isAvailable) {
          // Real iOS device but IAP not available - this could be due to:
          // 1. Device restrictions (Screen Time, parental controls)
          // 2. App Store account issues
          // 3. Network connectivity issues
          // 4. App not properly installed via TestFlight/App Store
          print('⚠️ Initialize: Real iOS device detected but IAP not available');
          print('🔍 Initialize: This could be due to device restrictions, App Store issues, or network problems');
          print('🔍 Initialize: Attempting to proceed anyway for better user experience...');
          
          // Try to proceed anyway and let the purchase flow handle errors gracefully
          _isAvailable = true;
        } else {
      _isAvailable = isAvailable;
        }
      } else {
        _isAvailable = isAvailable;
      }
      
      // CRITICAL: Set up purchase stream listener only if not already set up
      if (_isAvailable && _subscription == null) {
        print('🔍 Initialize: Setting up purchase stream listener');
        _subscription = InAppPurchase.instance.purchaseStream.listen(
          (List<PurchaseDetails> purchaseDetailsList) {
            print('🔍 Purchase Stream: Received ${purchaseDetailsList.length} purchase updates');
            for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
              print('🔍 Purchase Stream: Processing purchase for ${purchaseDetails.productID} - Status: ${purchaseDetails.status}');
              _handlePurchaseUpdate(purchaseDetails);
            }
          },
          onDone: () {
            print('🔍 Purchase Stream: Stream completed');
          },
          onError: (error) {
            print('❌ Purchase Stream: Error in purchase stream: $error');
          },
        );
        print('✅ Initialize: Purchase stream listener set up successfully');
      }
      
      // Load products after successful initialization
      if (_isAvailable) {
        print('🔍 Initialize: Loading products...');
        await _loadProducts();
        print('🔍 Initialize: Products loaded: ${_products.length}');
      }
      
      print('🔍 Initialize: Initialization complete - Available: $_isAvailable, Products: ${_products.length}');
      
      // Verify initialization was successful
      if (_isAvailable && _inAppPurchase != null) {
        print('✅ Initialize: Payment service successfully initialized and ready');
      } else {
        print('⚠️ Initialize: Payment service initialization may have issues - Available: $_isAvailable, IAP: ${_inAppPurchase != null}');
      }
      
    } catch (e) {
      print('❌ Initialize: Error during initialization: $e');
      _isAvailable = false;
      _inAppPurchase = null;
    } finally {
      _isInitializing = false;
    }
  }

  /// Ensure purchase stream listener is set up
  Future<void> _ensurePurchaseStreamListener() async {
    if (_subscription == null && _isAvailable && _inAppPurchase != null) {
      print('🔍 Ensure Purchase Stream: Setting up missing purchase stream listener');
      _subscription = InAppPurchase.instance.purchaseStream.listen(
        (List<PurchaseDetails> purchaseDetailsList) {
          print('🔍 Purchase Stream: Received ${purchaseDetailsList.length} purchase updates');
          for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
            print('🔍 Purchase Stream: Processing purchase for ${purchaseDetails.productID} - Status: ${purchaseDetails.status}');
            _handlePurchaseUpdate(purchaseDetails);
          }
        },
        onDone: () {
          print('🔍 Purchase Stream: Stream completed');
        },
        onError: (error) {
          print('❌ Purchase Stream: Error in purchase stream: $error');
        },
      );
      print('✅ Ensure Purchase Stream: Purchase stream listener set up successfully');
    }
  }

  /// Load available products from the store with platform-specific handling
  Future<void> _loadProducts() async {
    try {
      print('🔍 Load Products: Starting product load');
      
      if (_inAppPurchase == null) {
        print('❌ Load Products: InAppPurchase is null');
        return;
      }
      
      print('🔍 Load Products: Querying products for IDs: $_productIds');
      
      // Add retry logic for product loading
      int attempts = 0;
      const maxAttempts = 3;
      ProductDetailsResponse? response;
      
      while (attempts < maxAttempts) {
        attempts++;
        try {
          response = await _inAppPurchase!.queryProductDetails(_productIds);
          print('🔍 Load Products: Response received (attempt $attempts) - Found: ${response.productDetails.length}, Not Found: ${response.notFoundIDs}');
          
          if (response.error == null && response.productDetails.isNotEmpty) {
            break; // Success, exit retry loop
          }
          
          if (attempts < maxAttempts) {
            print('⚠️ Load Products: Attempt $attempts failed, retrying in 2 seconds...');
            await Future.delayed(const Duration(seconds: 2));
          }
        } catch (e) {
          print('❌ Load Products: Error on attempt $attempts: $e');
          if (attempts < maxAttempts) {
            await Future.delayed(const Duration(seconds: 2));
          }
        }
      }
      
      if (response == null) {
        print('❌ Load Products: All attempts failed');
        return;
      }
      
      if (response.notFoundIDs.isNotEmpty) {
        print('⚠️ Load Products: Some products not found: ${response.notFoundIDs}');
        }
        
      if (response.error != null) {
        print('❌ Load Products: Response error: ${response.error}');
      }
      
      _products = response.productDetails;
      print('🔍 Load Products: Loaded ${_products.length} products');
      
      for (final product in _products) {
        print('🔍 Load Products: Product - ID: ${product.id}, Title: ${product.title}, Price: ${product.price}');
      }
      
    } catch (e) {
      print('❌ Load Products: Error loading products: $e');
    }
  }



  /// Get available subscription products
  List<ProductDetails> get availableProducts => _products;

  /// Check if in-app purchases are available
  bool get isAvailable => _isAvailable && _inAppPurchase != null;

  /// Ensure payment service is properly initialized
  Future<bool> ensureInitialized() async {
    if (_isAvailable && _inAppPurchase != null) {
      return true;
    }
    
    print('🔍 Ensure Initialized: Payment service not properly initialized, reinitializing...');
    try {
      await initialize();
      return _isAvailable && _inAppPurchase != null;
    } catch (e) {
      print('❌ Ensure Initialized: Failed to reinitialize payment service: $e');
      return false;
    }
  }

  /// Diagnostic method to check payment service status
  Future<Map<String, dynamic>> getDiagnosticInfo() async {
    try {
      final diagnostic = <String, dynamic>{
        'isAvailable': _isAvailable,
        'inAppPurchaseInitialized': _inAppPurchase != null,
        'productsLoaded': _products.length,
        'platform': Platform.operatingSystem,
        'productIds': _productIds.toList(),
        'availableProducts': _products.map((p) => {
          'id': p.id,
          'title': p.title,
          'price': p.price,
        }).toList(),
      };
      
      // Enhanced iOS-specific diagnostics
      if (Platform.isIOS) {
        final isSimulator = await _isRunningOnSimulator();
        final isTestFlightMac = await _isRunningOnTestFlightMac();
        
        diagnostic['iosEnvironment'] = {
          'isSimulator': isSimulator,
          'isTestFlightMac': isTestFlightMac,
          'isRealDevice': !isSimulator && !isTestFlightMac,
        };
      }
      
      // Test InAppPurchase availability with detailed error info
      try {
        final iapAvailable = await InAppPurchase.instance.isAvailable();
        diagnostic['iapAvailable'] = iapAvailable;
        diagnostic['iapAvailableTest'] = 'success';
      } catch (e) {
        diagnostic['iapAvailable'] = false;
        diagnostic['iapError'] = e.toString();
        diagnostic['iapAvailableTest'] = 'failed';
      }
      
      // Test product loading if not already loaded
      if (_products.isEmpty && _inAppPurchase != null) {
        try {
          final response = await _inAppPurchase!.queryProductDetails(_productIds);
          diagnostic['productLoadResponse'] = {
            'error': response.error?.toString(),
            'notFoundIDs': response.notFoundIDs,
            'productDetailsCount': response.productDetails.length,
            'testResult': response.error == null ? 'success' : 'failed',
          };
        } catch (e) {
          diagnostic['productLoadError'] = e.toString();
          diagnostic['productLoadTest'] = 'failed';
        }
      }
      
      // Add network connectivity check
      try {
        final hasNetwork = await _checkNetworkConnectivity();
        diagnostic['networkConnectivity'] = hasNetwork;
      } catch (e) {
        diagnostic['networkConnectivity'] = false;
        diagnostic['networkError'] = e.toString();
      }
      
      return diagnostic;
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Purchase a subscription with platform-specific handling
  Future<bool> purchaseSubscription(String productId, {String? planType}) async {
    // Ensure payment service is properly initialized before attempting purchase
    if (!await ensureInitialized()) {
      final error = 'In-app purchases not available on ${Platform.operatingSystem}';
      throw Exception('In-app purchases not available');
    }
    
    // Platform-specific purchase handling
    if (Platform.isIOS) {
      return await _purchaseSubscriptionIOS(productId, planType: planType);
    } else if (Platform.isAndroid) {
      return await _purchaseSubscriptionAndroid(productId, planType: planType);
    } else {
      throw UnsupportedError('Platform not supported for purchases');
    }
  }

  /// iOS-specific subscription purchase
  Future<bool> _purchaseSubscriptionIOS(String productId, {String? planType}) async {
    print('🔍 iOS Purchase: Starting purchase for product: $productId');
    print('🔍 iOS Purchase: Available products: ${_products.map((p) => p.id).toList()}');
    
    // Ensure products are loaded
    if (_products.isEmpty) {
      print('🔍 iOS Purchase: No products loaded, attempting to load...');
      await _loadProducts();
      print('🔍 iOS Purchase: Products loaded: ${_products.length}');
    }
    
    ProductDetails? product;
    try {
      product = _products.firstWhere((p) => p.id == productId);
      print('🔍 iOS Purchase: Found product: ${product.id} - ${product.title}');
    } catch (e) {
      print('❌ iOS Purchase: Product not found: $productId');
      print('❌ iOS Purchase: Available products: ${_products.map((p) => p.id).toList()}');
      throw Exception('Product niet gevonden: $productId');
    }
    
    // Create a completer to wait for purchase completion
    final completer = Completer<bool>();
    _pendingPurchaseCompleters[productId] = completer;
    
    try {
      print('🔍 iOS Purchase: Creating purchase param for product: ${product.id}');
      final purchaseParam = PurchaseParam(productDetails: product!);
      print('🔍 iOS Purchase: Calling buyNonConsumable...');
      final bool success = await _inAppPurchase!.buyNonConsumable(purchaseParam: purchaseParam);
      print('🔍 iOS Purchase: buyNonConsumable returned: $success');
      
      if (!success) {
        _pendingPurchaseCompleters.remove(productId);
        return false;
      }
      
      // iOS-specific: Wait for purchase completion with timeout
      try {
        final result = await completer.future.timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            _pendingPurchaseCompleters.remove(productId);
            throw Exception('Apple payment dialog did not appear. Please try again or contact support.');
          },
        );
        return result;
      } catch (e) {
        _pendingPurchaseCompleters.remove(productId);
        rethrow;
      }
    } catch (e) {
      _pendingPurchaseCompleters.remove(productId);
      throw Exception('Aankoop mislukt: $e');
    }
  }

  /// Android-specific subscription purchase
  Future<bool> _purchaseSubscriptionAndroid(String productId, {String? planType}) async {
    ProductDetails? product;
    try {
      product = _products.firstWhere((p) => p.id == productId);
    } catch (e) {
      throw Exception('Product niet gevonden: $productId');
    }
    
    // Create a completer to wait for purchase completion
    final completer = Completer<bool>();
    _pendingPurchaseCompleters[productId] = completer;
    
    try {
      final purchaseParam = PurchaseParam(productDetails: product!);
      final bool success = await _inAppPurchase!.buyNonConsumable(purchaseParam: purchaseParam);
      
      if (!success) {
        _pendingPurchaseCompleters.remove(productId);
        return false;
      }
      
      // Android-specific: Wait for purchase completion with timeout
      try {
        final result = await completer.future.timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            _pendingPurchaseCompleters.remove(productId);
            throw Exception('Google Play payment dialog did not appear. Please try again or contact support.');
          },
        );
        return result;
    } catch (e) {
        _pendingPurchaseCompleters.remove(productId);
        rethrow;
      }
    } catch (e) {
      _pendingPurchaseCompleters.remove(productId);
      throw Exception('Aankoop mislukt: $e');
    }
  }

  /// Handle purchase updates with platform-specific logic
  void _handlePurchaseUpdate(PurchaseDetails purchaseDetails) async {
    // Platform-specific purchase handling
    if (Platform.isIOS) {
      _handlePurchaseUpdateIOS(purchaseDetails);
    } else if (Platform.isAndroid) {
      _handlePurchaseUpdateAndroid(purchaseDetails);
    } else {
    }
  }

  /// iOS-specific purchase update handling
  void _handlePurchaseUpdateIOS(PurchaseDetails purchaseDetails) async {
    print('🔍 iOS Purchase Update: Processing ${purchaseDetails.productID} - Status: ${purchaseDetails.status}');
    print('🔍 iOS Purchase Update: Pending complete: ${purchaseDetails.pendingCompletePurchase}');
    print('🔍 iOS Purchase Update: Error: ${purchaseDetails.error}');
    print('🔍 iOS Purchase Update: Transaction date: ${purchaseDetails.transactionDate}');
    
    if (purchaseDetails.status == PurchaseStatus.purchased ||
        purchaseDetails.status == PurchaseStatus.restored) {
      print('🔍 iOS Purchase Update: Handling purchased/restored purchase');
      
      // Check if running on simulator
      final isSimulator = await _isRunningOnSimulator();
      if (isSimulator) {
        print('🔍 iOS Purchase Update: Simulator detected, not granting premium access');
      } else {
        // Always grant premium access for valid purchases, even on TestFlight
        print('🔍 iOS Purchase Update: Granting premium access and updating Firestore');
          _handleSuccessfulPurchase(purchaseDetails);
      }
      
      // Complete pending purchase with success
      final completer = _pendingPurchaseCompleters.remove(purchaseDetails.productID);
      if (completer != null && !completer.isCompleted) {
        completer.complete(true);
      }
    } else if (purchaseDetails.status == PurchaseStatus.error) {
      print('🔍 iOS Purchase Update: Error status detected');
      _handlePurchaseErrorIOS(purchaseDetails);
    } else if (purchaseDetails.status == PurchaseStatus.canceled) {
      print('🔍 iOS Purchase Update: Canceled status detected');
      _handlePurchaseCancellationIOS(purchaseDetails);
    }

    // Complete the purchase if needed
    if (purchaseDetails.pendingCompletePurchase) {
      _completePurchaseIOS(purchaseDetails);
    }
  }

  /// Android-specific purchase update handling
  void _handlePurchaseUpdateAndroid(PurchaseDetails purchaseDetails) {
    if (purchaseDetails.status == PurchaseStatus.purchased ||
        purchaseDetails.status == PurchaseStatus.restored) {
      
      // Handle successful purchase
      _handleSuccessfulPurchase(purchaseDetails);
      
      // Complete pending purchase with success
      final completer = _pendingPurchaseCompleters.remove(purchaseDetails.productID);
      if (completer != null && !completer.isCompleted) {
        completer.complete(true);
      }
    } else if (purchaseDetails.status == PurchaseStatus.error) {
      _handlePurchaseErrorAndroid(purchaseDetails);
    } else if (purchaseDetails.status == PurchaseStatus.canceled) {
      _handlePurchaseCancellationAndroid(purchaseDetails);
    }

    // Complete the purchase if needed
    if (purchaseDetails.pendingCompletePurchase) {
      _completePurchaseAndroid(purchaseDetails);
    }
  }

  /// Handle iOS-specific purchase errors
  void _handlePurchaseErrorIOS(PurchaseDetails purchaseDetails) {
        final errorCode = purchaseDetails.error?.code;
        final errorMessage = purchaseDetails.error?.message;
        
    if (Platform.isIOS) {
    print('❌ iOS: Purchase error: $errorCode - $errorMessage');
    }
    
    // Complete pending purchase with error
    final completer = _pendingPurchaseCompleters.remove(purchaseDetails.productID);
    if (completer != null && !completer.isCompleted) {
      completer.complete(false);
    }
  }

  /// Handle Android-specific purchase errors
  void _handlePurchaseErrorAndroid(PurchaseDetails purchaseDetails) {
    final errorCode = purchaseDetails.error?.code;
    final errorMessage = purchaseDetails.error?.message;
    
    if (Platform.isAndroid) {
    print('❌ Android: Purchase error: $errorCode - $errorMessage');
        }
        
        // Complete pending purchase with error
        final completer = _pendingPurchaseCompleters.remove(purchaseDetails.productID);
        if (completer != null && !completer.isCompleted) {
          completer.complete(false);
        }
  }

  /// Handle iOS-specific purchase cancellations
  void _handlePurchaseCancellationIOS(PurchaseDetails purchaseDetails) {
    if (Platform.isIOS) {
    print('🚫 iOS: Purchase canceled by user: ${purchaseDetails.productID}');
    }
        
    // Complete pending purchase with cancellation
        final completer = _pendingPurchaseCompleters.remove(purchaseDetails.productID);
        if (completer != null && !completer.isCompleted) {
      completer.complete(false);
        }
  }

  /// Handle Android-specific purchase cancellations
  void _handlePurchaseCancellationAndroid(PurchaseDetails purchaseDetails) {
    if (Platform.isAndroid) {
    print('🚫 Android: Purchase canceled by user: ${purchaseDetails.productID}');
        }
        
        // Complete pending purchase with cancellation
        final completer = _pendingPurchaseCompleters.remove(purchaseDetails.productID);
        if (completer != null && !completer.isCompleted) {
          completer.complete(false);
        }
      }

  /// Complete iOS purchase
  void _completePurchaseIOS(PurchaseDetails purchaseDetails) {
        try {
      InAppPurchase.instance.completePurchase(purchaseDetails);
        } catch (e) {
      if (Platform.isIOS) {
      print('❌ iOS: Error completing purchase: $e');
          }
        }
      }

  /// Complete Android purchase
  void _completePurchaseAndroid(PurchaseDetails purchaseDetails) {
    try {
      InAppPurchase.instance.completePurchase(purchaseDetails);
    } catch (e) {
      if (Platform.isAndroid) {
      print('❌ Android: Error completing purchase: $e');
      }
    }
  }

  /// Handle successful purchase with platform-specific logic
  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchaseDetails) async {
    print('🔍 [DEBUG] Handle Successful Purchase: Starting for ${purchaseDetails.productID}');
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null || _firestore == null) {
        print('❌ [DEBUG] Handle Successful Purchase: User or Firestore is null');
        return;
      }
      print('🔍 [DEBUG] Handle Successful Purchase: User found: ${user.uid}, platform: ${Platform.operatingSystem}');
      // Platform-specific successful purchase handling
      if (Platform.isIOS) {
        print('🔍 [DEBUG] Handle Successful Purchase: Processing iOS purchase');
        await _handleSuccessfulPurchaseIOS(purchaseDetails, user);
      } else if (Platform.isAndroid) {
        print('🔍 [DEBUG] Handle Successful Purchase: Processing Android purchase');
        await _handleSuccessfulPurchaseAndroid(purchaseDetails, user);
      } else {
        print('🔍 [DEBUG] Handle Successful Purchase: Unsupported platform');
      }
      await PlanAbandonmentService.trackPurchaseCompletion();
      print('🔍 [DEBUG] Handle Successful Purchase: Completed successfully');
    } catch (e) {
      print('❌ [DEBUG] Handle Successful Purchase: Error: $e');
    }
  }

  Future<void> _handleSuccessfulPurchaseIOS(PurchaseDetails purchaseDetails, User user) async {
    final bool isTrialPurchase = purchaseDetails.productID == 'jachtproef_monthly_399' || 
                                 purchaseDetails.productID == 'jachtproef_yearly_2999';
    print('🔍 [DEBUG] _handleSuccessfulPurchaseIOS: user=${user.uid}, product=${purchaseDetails.productID}, isTrial=$isTrialPurchase');
    if (isTrialPurchase) {
      final String planType = purchaseDetails.productID == 'jachtproef_monthly_399' ? 'monthly' : 'yearly';
      print('🔍 [DEBUG] _handleSuccessfulPurchaseIOS: Writing trial data to Firestore...');
      await _setupTrialDataIOS(user.uid, planType, purchaseDetails.productID, 'ios');
      print('🔍 [DEBUG] _handleSuccessfulPurchaseIOS: Firestore update complete for user=${user.uid}');
      // Check if quick setup is already completed
      final doc = await _firestore!.collection('users').doc(user.uid).get();
      final quickSetupCompleted = doc.data()?['quickSetupCompleted'] == true;
      print('🔍 [DEBUG] _handleSuccessfulPurchaseIOS: quickSetupCompleted=$quickSetupCompleted');
      if (!quickSetupCompleted) {
      _navigateToQuickSetup();
      } else {
        print('🔍 [DEBUG] _handleSuccessfulPurchaseIOS: Skipping Quick Setup, already completed.');
      }
    }
  }

  Future<void> _handleSuccessfulPurchaseAndroid(PurchaseDetails purchaseDetails, User user) async {
    final bool isTrialPurchase = purchaseDetails.productID == 'jachtproef_premium';
    print('🔍 [DEBUG] _handleSuccessfulPurchaseAndroid: user=${user.uid}, product=${purchaseDetails.productID}, isTrial=$isTrialPurchase');
    if (isTrialPurchase) {
      final String planType = 'monthly'; // Default fallback
      print('🔍 [DEBUG] _handleSuccessfulPurchaseAndroid: Writing trial data to Firestore...');
      await _setupTrialDataAndroid(user.uid, planType, purchaseDetails.productID, 'android');
      print('🔍 [DEBUG] _handleSuccessfulPurchaseAndroid: Firestore update complete for user=${user.uid}');
      // Check if quick setup is already completed
      final doc = await _firestore!.collection('users').doc(user.uid).get();
      final quickSetupCompleted = doc.data()?['quickSetupCompleted'] == true;
      print('🔍 [DEBUG] _handleSuccessfulPurchaseAndroid: quickSetupCompleted=$quickSetupCompleted');
      if (!quickSetupCompleted) {
      _navigateToQuickSetup();
      } else {
        print('🔍 [DEBUG] _handleSuccessfulPurchaseAndroid: Skipping Quick Setup, already completed.');
      }
    }
  }

  Future<void> _setupTrialDataIOS(String userId, String planType, String productId, String platform) async {
    final data = {
          'createdAt': FieldValue.serverTimestamp(),
          'trialStartDate': FieldValue.serverTimestamp(),
          'selectedPlan': planType,
          'subscriptionStatus': 'trial',
          'trialEndDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 14))),
          'trialEnded': false,
      'isPremium': true,
      'paymentSetupCompleted': true,
          'subscription': {
        'productId': productId,
            'status': 'trial',
        'platform': platform,
            'trialStartDate': FieldValue.serverTimestamp(),
            'trialEndDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 14))),
        'willAutoRenew': true,
        'autoRenewDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 14))),
          },
    };
    print('🔍 [DEBUG] _setupTrialDataIOS: Writing to Firestore for user=$userId, data=$data');
    try {
      await _firestore!.collection('users').doc(userId).set(data, SetOptions(merge: true));
      print('✅ [DEBUG] _setupTrialDataIOS: Firestore write success for user=$userId');
    } catch (e) {
      print('❌ [DEBUG] _setupTrialDataIOS: Firestore write error for user=$userId: $e');
    }
  }

  Future<void> _setupTrialDataAndroid(String userId, String planType, String productId, String platform) async {
    final data = {
      'createdAt': FieldValue.serverTimestamp(),
      'trialStartDate': FieldValue.serverTimestamp(),
      'selectedPlan': planType,
      'subscriptionStatus': 'trial',
      'trialEndDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 14))),
      'trialEnded': false,
      'isPremium': true,
      'paymentSetupCompleted': true,
      'subscription': {
        'productId': productId,
        'status': 'trial',
        'platform': platform,
        'trialStartDate': FieldValue.serverTimestamp(),
        'trialEndDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 14))),
        'willAutoRenew': true,
        'autoRenewDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 14))),
      },
    };
    print('🔍 [DEBUG] _setupTrialDataAndroid: Writing to Firestore for user=$userId, data=$data');
    try {
      await _firestore!.collection('users').doc(userId).set(data, SetOptions(merge: true));
      print('✅ [DEBUG] _setupTrialDataAndroid: Firestore write success for user=$userId');
    } catch (e) {
      print('❌ [DEBUG] _setupTrialDataAndroid: Firestore write error for user=$userId: $e');
    }
  }

  /// Legacy method for backward compatibility - now delegates to platform-specific methods
  Future<void> _setupTrialData(String userId, String planType, String productId) async {
    if (Platform.isIOS) {
      await _setupTrialDataIOS(userId, planType, productId, 'ios');
    } else if (Platform.isAndroid) {
      await _setupTrialDataAndroid(userId, planType, productId, 'android');
    } else {
      throw UnsupportedError('Platform not supported for trial setup');
    }
  }
  
  /// Navigate to Quick Setup screen
  void _navigateToQuickSetup() {
    print('🔍 Navigate to Quick Setup: Method called');
    
    if (_shouldNavigateToQuickSetup) {
      print('🔍 Navigate to Quick Setup: Already set, returning');
      return;
    }
    
    print('🔍 Navigate to Quick Setup: Setting navigation flag for Quick Setup...');
    _shouldNavigateToQuickSetup = true;
    notifyListeners();
    
    print('🔍 Navigate to Quick Setup: Navigation flag set, notifying listeners');
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('🔍 Navigate to Quick Setup: Post frame callback executed');
    });
  }
  
  // Flag to indicate navigation should happen
  bool _shouldNavigateToQuickSetup = false;
  
  /// Check if navigation to Quick Setup is needed
  bool get shouldNavigateToQuickSetup => _shouldNavigateToQuickSetup;
  
  /// Clear the navigation flag
  void clearNavigationFlag() {
    _shouldNavigateToQuickSetup = false;
  }

  /// Check if running on simulator
  Future<bool> _isRunningOnSimulator() async {
    try {
      if (Platform.isIOS) {
        // Check for simulator environment variables
        final isSimulator = Platform.environment.containsKey('SIMULATOR_DEVICE_NAME') ||
                           Platform.environment.containsKey('SIMULATOR_HOST_HOME') ||
                           Platform.environment.containsKey('SIMULATOR_DEVICE_FAMILY');
        
        return isSimulator;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Check if running on TestFlight on Mac
  Future<bool> _isRunningOnTestFlightMac() async {
    try {
      print('🔍 TestFlight Mac Detection: Platform.isIOS = ${Platform.isIOS}, Platform.operatingSystem = ${Platform.operatingSystem}');
      
      if (Platform.isIOS && Platform.operatingSystem == 'macos') {
        // Additional checks to confirm this is TestFlight on Mac
        final hasTestFlight = Platform.environment.containsKey('TESTFLIGHT');
        final hasSandbox = Platform.environment.containsKey('SANDBOX');
        final hasXcodePreview = Platform.environment.containsKey('XCODE_RUNNING_FOR_PREVIEWS');
        
        print('🔍 TestFlight Mac Detection: TESTFLIGHT = $hasTestFlight, SANDBOX = $hasSandbox, XCODE_RUNNING_FOR_PREVIEWS = $hasXcodePreview');
        
        final isTestFlight = hasTestFlight || hasSandbox || !hasXcodePreview;
        
        print('🔍 TestFlight Mac Detection: Final result = $isTestFlight');
        return isTestFlight;
      }
      
      print('🔍 TestFlight Mac Detection: Not iOS or not macOS, returning false');
      return false;
    } catch (e) {
      print('🔍 TestFlight Mac Detection: Error = $e');
      return false;
    }
  }

  /// Check if running from Xcode development build
  Future<bool> _isRunningFromXcode() async {
    try {
      if (Platform.isIOS) {
        // Check for Xcode development environment indicators
        final isXcodeBuild = Platform.environment.containsKey('XCODE_RUNNING_FOR_PREVIEWS') ||
                            Platform.environment.containsKey('XCODE_VERSION_ACTUAL') ||
                            Platform.environment.containsKey('CONFIGURATION') && 
                            Platform.environment['CONFIGURATION'] == 'Debug';
        
        return isXcodeBuild;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Restore purchases with comprehensive error handling and retry logic
  Future<Map<String, dynamic>> restorePurchases() async {
    print('🔍 Restore Purchases: Starting comprehensive restore process');
    
    final result = <String, dynamic>{
      'success': false,
      'restoredPurchases': false,
      'navigatedToQuickSetup': false,
      'error': null,
      'details': <String, dynamic>{},
    };

    try {
      // Step 1: Validate prerequisites
      if (!_isAvailable || _inAppPurchase == null) {
        final error = 'In-app purchases not available on ${Platform.operatingSystem}';
        print('❌ Restore Purchases: $error');
        result['error'] = error;
        return result;
      }

      // Step 2: Ensure user is authenticated
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        final error = 'User not authenticated';
        print('❌ Restore Purchases: $error');
        result['error'] = error;
        return result;
      }

      result['details']['userId'] = user.uid;
      result['details']['platform'] = Platform.operatingSystem;

      // Step 3: Initialize payment service if needed
      if (!_isAvailable) {
        print('🔍 Restore Purchases: Initializing payment service');
        await initialize();
        if (!_isAvailable) {
          final error = 'Failed to initialize payment service';
          print('❌ Restore Purchases: $error');
          result['error'] = error;
          return result;
        }
      }

      // Step 4: Ensure purchase stream listener is set up
      print('🔍 Restore Purchases: Ensuring purchase stream listener is set up');
      await _ensurePurchaseStreamListener();
      
      if (_subscription == null) {
        final error = 'Failed to set up purchase stream listener';
        print('❌ Restore Purchases: $error');
        result['error'] = error;
        return result;
      }

      // Step 5: Check current user state before restore
      final currentState = await _getCurrentUserPaymentState(user.uid);
      result['details']['currentState'] = currentState;
      
      if (currentState['hasPaymentSetup']) {
        print('🔍 Restore Purchases: User already has payment setup, navigating to Quick Setup');
        _navigateToQuickSetup();
        result['success'] = true;
        result['navigatedToQuickSetup'] = true;
        result['details']['reason'] = 'existing_payment_setup';
        return result;
      }

      // Step 6: Perform restore with timeout and retry logic
      print('🔍 Restore Purchases: Calling InAppPurchase restore method');
      bool restoreCompleted = false;
      int retryCount = 0;
      const maxRetries = 2;
      const timeoutDuration = Duration(seconds: 10);

      while (!restoreCompleted && retryCount <= maxRetries) {
        try {
          if (retryCount > 0) {
            print('🔍 Restore Purchases: Retry attempt $retryCount of $maxRetries');
            await Future.delayed(Duration(seconds: retryCount * 2)); // Exponential backoff
          }

          // Call restore with timeout
          await _inAppPurchase!.restorePurchases().timeout(
            timeoutDuration,
            onTimeout: () {
              throw TimeoutException('Restore operation timed out after ${timeoutDuration.inSeconds} seconds');
            },
          );

          restoreCompleted = true;
          print('🔍 Restore Purchases: Restore method completed successfully');
          
        } catch (e) {
          retryCount++;
          print('⚠️ Restore Purchases: Attempt $retryCount failed: $e');
          
          if (retryCount > maxRetries) {
            print('❌ Restore Purchases: All retry attempts failed');
            result['error'] = 'Restore failed after $maxRetries attempts: $e';
            return result;
          }
        }
      }

      // Step 7: Wait for purchase stream updates and check for restored purchases
      print('🔍 Restore Purchases: Waiting for purchase stream updates');
      final restoreResult = await _waitForRestoreCompletion(user.uid, currentState);
      result['details']['restoreResult'] = restoreResult;

      if (restoreResult['restoredPurchases']) {
        print('🔍 Restore Purchases: Purchases were restored successfully');
        result['success'] = true;
        result['restoredPurchases'] = true;
        result['navigatedToQuickSetup'] = true;
        _navigateToQuickSetup();
        return result;
      }

      // Step 8: Fallback check - verify if user has any valid subscription
      print('🔍 Restore Purchases: Performing fallback subscription check');
      final fallbackCheck = await _performFallbackSubscriptionCheck(user.uid);
      result['details']['fallbackCheck'] = fallbackCheck;

      if (fallbackCheck['hasValidSubscription']) {
        print('🔍 Restore Purchases: Valid subscription found in fallback check');
        result['success'] = true;
        result['restoredPurchases'] = true;
        result['navigatedToQuickSetup'] = true;
        _navigateToQuickSetup();
        return result;
      }

      // Step 9: Final state check
      final finalState = await _getCurrentUserPaymentState(user.uid);
      result['details']['finalState'] = finalState;

      if (finalState['hasPaymentSetup']) {
        print('🔍 Restore Purchases: Payment setup found in final check');
        result['success'] = true;
        result['navigatedToQuickSetup'] = true;
        _navigateToQuickSetup();
        return result;
      }

      // No purchases found to restore
      print('🔍 Restore Purchases: No purchases found to restore');
      result['success'] = true; // This is still a successful operation
      result['details']['reason'] = 'no_purchases_found';
      return result;

    } catch (e) {
      print('❌ Restore Purchases: Unexpected error: $e');
      result['error'] = 'Unexpected error: $e';
      return result;
    }
  }

  /// Get current user payment state
  Future<Map<String, dynamic>> _getCurrentUserPaymentState(String userId) async {
    try {
      if (_firestore == null) return {'hasPaymentSetup': false, 'error': 'Firestore not initialized'};

      final DocumentSnapshot doc = await _firestore!.collection('users').doc(userId).get();
      if (!doc.exists) return {'hasPaymentSetup': false, 'reason': 'user_document_not_found'};

      final data = doc.data() as Map<String, dynamic>?;
      final bool paymentSetupCompleted = data?['paymentSetupCompleted'] ?? false;
      final bool isPremium = data?['isPremium'] ?? false;
      final subscription = data?['subscription'] as Map<String, dynamic>?;

      return {
        'hasPaymentSetup': paymentSetupCompleted,
        'isPremium': isPremium,
        'subscription': subscription,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {'hasPaymentSetup': false, 'error': e.toString()};
    }
  }

  /// Wait for restore completion with timeout
  Future<Map<String, dynamic>> _waitForRestoreCompletion(String userId, Map<String, dynamic> initialState) async {
    const maxWaitTime = Duration(seconds: 8);
    const checkInterval = Duration(milliseconds: 500);
    final startTime = DateTime.now();
    
    print('🔍 Wait for Restore: Starting wait with timeout of ${maxWaitTime.inSeconds} seconds');

    while (DateTime.now().difference(startTime) < maxWaitTime) {
      await Future.delayed(checkInterval);
      
      final currentState = await _getCurrentUserPaymentState(userId);
      
      // Check if payment setup was completed during the wait
      if (currentState['hasPaymentSetup'] && !initialState['hasPaymentSetup']) {
        print('🔍 Wait for Restore: Payment setup completed during wait');
        return {
          'restoredPurchases': true,
          'reason': 'payment_setup_completed',
          'waitTime': DateTime.now().difference(startTime).inMilliseconds,
        };
      }

      // Check if premium status changed
      if (currentState['isPremium'] && !initialState['isPremium']) {
        print('🔍 Wait for Restore: Premium status activated during wait');
        return {
          'restoredPurchases': true,
          'reason': 'premium_activated',
          'waitTime': DateTime.now().difference(startTime).inMilliseconds,
        };
      }
    }

    print('🔍 Wait for Restore: Timeout reached, no changes detected');
    return {
      'restoredPurchases': false,
      'reason': 'timeout_no_changes',
      'waitTime': maxWaitTime.inMilliseconds,
    };
  }

  /// Perform fallback subscription check
  Future<Map<String, dynamic>> _performFallbackSubscriptionCheck(String userId) async {
    try {
      print('🔍 Fallback Check: Performing comprehensive subscription check');
      
      // Check if user has any subscription data
      final currentState = await _getCurrentUserPaymentState(userId);
      
      if (currentState['subscription'] != null) {
        final subscription = currentState['subscription'] as Map<String, dynamic>;
        final status = subscription['status'] as String?;
        final platform = subscription['platform'] as String?;
        
        print('🔍 Fallback Check: Found subscription - Status: $status, Platform: $platform');
        
        // Consider any subscription as valid for navigation
        if (status != null && (status == 'active' || status == 'trial')) {
          return {
            'hasValidSubscription': true,
            'subscriptionStatus': status,
            'platform': platform,
            'reason': 'existing_subscription_found',
          };
        }
      }

      // Check if user has premium access
      if (currentState['isPremium'] == true) {
        print('🔍 Fallback Check: User has premium access');
        return {
          'hasValidSubscription': true,
          'reason': 'premium_access_found',
        };
      }

      return {
        'hasValidSubscription': false,
        'reason': 'no_valid_subscription_found',
      };
      
    } catch (e) {
      print('❌ Fallback Check: Error during fallback check: $e');
      return {
        'hasValidSubscription': false,
        'error': e.toString(),
      };
    }
  }

  /// Check network connectivity for restore operations
  Future<bool> _checkNetworkConnectivity() async {
    try {
      // Try multiple endpoints in case one is blocked
      final endpoints = [
        'https://www.apple.com',
        'https://www.google.com',
        'https://httpbin.org/get',
      ];
      
      for (final endpoint in endpoints) {
        try {
          final response = await http.get(Uri.parse(endpoint)).timeout(
            const Duration(seconds: 3),
        onTimeout: () {
          throw TimeoutException('Network connectivity check timed out');
        },
      );
          if (response.statusCode == 200) {
            print('✅ Network connectivity check passed using: $endpoint');
            return true;
          }
    } catch (e) {
          print('⚠️ Network check failed for $endpoint: $e');
          continue;
        }
      }
      
      print('❌ Network connectivity check failed for all endpoints');
      return false;
    } catch (e) {
      print('❌ Network connectivity check failed: $e');
      return false;
    }
  }

  /// Enhanced restore purchases with network connectivity check
  Future<Map<String, dynamic>> restorePurchasesWithConnectivityCheck() async {
    print('🔍 Restore with Connectivity: Starting enhanced restore process');
    
    // Check network connectivity first
    final hasConnectivity = await _checkNetworkConnectivity();
    if (!hasConnectivity) {
      print('❌ Restore with Connectivity: No network connectivity detected');
      return {
        'success': false,
        'error': 'Geen internetverbinding. Controleer je netwerk en probeer het opnieuw.',
        'details': {'reason': 'no_network_connectivity'},
      };
    }

    // Proceed with normal restore process
    return await restorePurchases();
  }

  /// Get detailed restore diagnostics for debugging
  Future<Map<String, dynamic>> getRestoreDiagnostics() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {'error': 'User not authenticated'};
      }

      final diagnostics = <String, dynamic>{
        'timestamp': DateTime.now().toIso8601String(),
        'userId': user.uid,
        'platform': Platform.operatingSystem,
        'paymentServiceAvailable': _isAvailable,
        'inAppPurchaseInitialized': _inAppPurchase != null,
        'purchaseStreamActive': _subscription != null,
        'productsLoaded': _products.length,
        'networkConnectivity': await _checkNetworkConnectivity(),
      };

      // Get current user state
      final userState = await _getCurrentUserPaymentState(user.uid);
      diagnostics['userState'] = userState;

      // Get subscription info
      final subscriptionInfo = await getSubscriptionInfo();
      diagnostics['subscriptionInfo'] = subscriptionInfo;

      return diagnostics;
    } catch (e) {
      return {'error': 'Failed to get diagnostics: $e'};
    }
  }



  /// Get subscription info
  Future<Map<String, dynamic>?> getSubscriptionInfo() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null || _firestore == null) return null;

      final DocumentSnapshot doc = await _firestore!.collection('users').doc(user.uid).get();
      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>?;
      return data?['subscription'] as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  /// Send subscription confirmation email
  Future<void> sendSubscriptionEmail({
    required String userEmail,
    required String subscriptionType,
    required String amount,
  }) async {
    try {
      // Get Firebase Auth token
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return;
      }
      
      final idToken = await user.getIdToken();
      
      // Cloud function URL
      const functionUrl = 'https://us-central1-jachtproefalert.cloudfunctions.net/send-subscription-email';
      
      // Prepare request
      final response = await http.post(
        Uri.parse(functionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: json.encode({
          'email': userEmail,
          'subscription_type': subscriptionType,
          'amount': amount,
        }),
      );
      
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
      } else {
      }
    } catch (e) {
    }
  }

  /// Get pricing info for display
  Map<String, Map<String, dynamic>> getPricingInfo() {
    return {
      'monthly': {
        'price': '€3.99',
        'description': 'Per month',
        'features': [
          'Unlimited exam alerts',
          'Priority notifications',
          'Advanced filtering',
          'Calendar integration',
        ],
      },
      'yearly': {
        'price': '€29.99',
                  'description': 'Per year (Save 37%)',
        'features': [
          'All monthly features',
          'Best value',
          '2 months free',
          'Priority support',
        ],
      },
    };
  }

  /// Dispose resources
  void dispose() {
    _subscription?.cancel();
  }

  /// DEBUG: Force bypass trial for any platform (for testing only)
  Future<void> forceBypassTrialWithPlan(String planType) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null || _firestore == null) {
      throw Exception('User moet ingelogd zijn om proefperiode te starten');
    }
    await _firestore!.collection('users').doc(user.uid).set({
      'createdAt': FieldValue.serverTimestamp(),
      'trialStartDate': FieldValue.serverTimestamp(),
      'selectedPlan': planType,
      'subscriptionStatus': 'trial',
      'trialEndDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 14))),
      'trialEnded': false,
      'isPremium': true,
      'paymentSetupCompleted': true,
      'subscription': {
        'productId': planType,
        'status': 'trial',
        'platform': 'debug-bypass',
        'trialStartDate': FieldValue.serverTimestamp(),
        'trialEndDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 14))),
        'willAutoRenew': false,
      },
    }, SetOptions(merge: true));
    
    // Check if quick setup is already completed
    final doc = await _firestore!.collection('users').doc(user.uid).get();
    final quickSetupCompleted = doc.data()?['quickSetupCompleted'] == true;
    print('🔍 [DEBUG] forceBypassTrialWithPlan: quickSetupCompleted=$quickSetupCompleted');
    if (!quickSetupCompleted) {
      // Navigate to Quick Setup after successful trial setup (debug bypass)
      _navigateToQuickSetup();
    } else {
      print('🔍 [DEBUG] forceBypassTrialWithPlan: Skipping Quick Setup, already completed.');
    }
  }

  Future<bool> isInAppPurchaseAvailable() async {
    try {
      return await InAppPurchase.instance.isAvailable();
    } catch (e) {
      return false;
    }
  }

  /// Check if user is in trial period
  Future<bool> isInTrialPeriod() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null || _firestore == null) return false;

      final DocumentSnapshot doc = await _firestore!.collection('users').doc(user.uid).get();
      if (!doc.exists) return true; // New users get trial

      final data = doc.data() as Map<String, dynamic>?;
      
      // Check if trial has been used
      final bool trialEnded = data?['trialEnded'] ?? false;
      if (trialEnded) return false;

      // Check trial start date
      final Timestamp? createdAt = data?['createdAt'] as Timestamp?;
      if (createdAt == null) return true; // No creation date, assume new user

      final DateTime trialEndDate = createdAt.toDate().add(Duration(days: trialPeriodDays));
      return DateTime.now().isBefore(trialEndDate);
    } catch (e) {
      return false;
    }
  }

  /// Check for and handle stuck purchase completers
  Future<void> checkForStuckPurchaseCompleters() async {
    try {
      print('🔍 Checking for stuck purchase completers...');
      
      int stuckCount = 0;
      for (final entry in _pendingPurchaseCompleters.entries) {
        final productId = entry.key;
        final completer = entry.value;
        
        if (!completer.isCompleted) {
          print('🔍 Found stuck completer for product: $productId');
          stuckCount++;
          
          // Complete it with false to unstick it
          completer.complete(false);
        }
      }
      
      if (stuckCount > 0) {
        print('🧹 Cleaned up $stuckCount stuck purchase completers');
        _pendingPurchaseCompleters.clear();
      } else {
        print('✅ No stuck purchase completers found');
      }
      
    } catch (e) {
      print('❌ Error checking for stuck purchase completers: $e');
    }
  }

  /// Get days remaining in trial
  Future<int> getTrialDaysRemaining() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null || _firestore == null) return 0;

      final DocumentSnapshot doc = await _firestore!.collection('users').doc(user.uid).get();
      if (!doc.exists) return trialPeriodDays;

      final data = doc.data() as Map<String, dynamic>?;
      final Timestamp? createdAt = data?['createdAt'] as Timestamp?;
      if (createdAt == null) return trialPeriodDays;

      final DateTime trialEndDate = createdAt.toDate().add(Duration(days: trialPeriodDays));
      final int daysRemaining = trialEndDate.difference(DateTime.now()).inDays;
      
      return daysRemaining > 0 ? daysRemaining : 0;
    } catch (e) {
      return 0;
    }
  }

  /// Check if user has active subscription
  Future<bool> hasActiveSubscription() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null || _firestore == null) return false;

      final DocumentSnapshot doc = await _firestore!.collection('users').doc(user.uid).get();
      if (!doc.exists) return false;

      final data = doc.data() as Map<String, dynamic>?;
      final subscription = data?['subscription'] as Map<String, dynamic>?;
      
      if (subscription == null) return false;
      
      // Check if subscription is active and not expired
      final bool isActive = subscription['status'] == 'active';
      final Timestamp? expiryDate = subscription['expiryDate'] as Timestamp?;
      
      if (!isActive) return false;
      if (expiryDate == null) return isActive; // Fallback for old data
      
      return DateTime.now().isBefore(expiryDate.toDate());
    } catch (e) {
      return false;
    }
  }

  /// Check if user has premium access (trial or subscription)
  Future<bool> hasPremiumAccess() async {
    try {
      // --- TEMPORARY BYPASS FOR SIMULATOR TESTING ---
      bool isSimulator = false;
      try {
        isSimulator = Platform.isIOS && Platform.environment.containsKey('SIMULATOR_DEVICE_NAME');
      } catch (_) {}
      if (isSimulator) {
        print('[DEBUG] Simulator detected: bypassing payment and granting premium access');
        return true;
      }
      // --- END TEMPORARY BYPASS ---
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null || _firestore == null) return false;
      final DocumentSnapshot doc = await _firestore!.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        print('🔍 [DEBUG] hasPremiumAccess: No Firestore doc for user=${user.uid}');
        return false;
      }
      final data = doc.data() as Map<String, dynamic>?;
      final subscription = data?['subscription'] as Map<String, dynamic>?;
      final isPremium = data?['isPremium'] == true;
      final selectedPlan = data?['selectedPlan'];
      final paymentSetupCompleted = data?['paymentSetupCompleted'] == true;
      print('🔍 [DEBUG] hasPremiumAccess: user=${user.uid}, isPremium=$isPremium, selectedPlan=$selectedPlan, paymentSetupCompleted=$paymentSetupCompleted, subscription=$subscription');
      final bool hasPremium = isPremium || (selectedPlan != null && selectedPlan.toString().isNotEmpty) || paymentSetupCompleted;
      print('🔍 [DEBUG] hasPremiumAccess: Computed hasPremium=$hasPremium');
      return hasPremium;
    } catch (e) {
      print('❌ [DEBUG] hasPremiumAccess: Error: $e');
      return false;
    }
  }

  /// Check if user has completed payment setup (not just trial access)
  Future<bool> hasCompletedPaymentSetup() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null || _firestore == null) return false;

      final DocumentSnapshot doc = await _firestore!.collection('users').doc(user.uid).get();
      if (!doc.exists) return false;

      final data = doc.data() as Map<String, dynamic>?;
      
      // Check if payment setup was completed (this is set in _setupTrialData)
      final bool paymentSetupCompleted = data?['paymentSetupCompleted'] ?? false;
      
      return paymentSetupCompleted;
    } catch (e) {
      return false;
    }
  }

  /// Start trial for new user
  Future<void> startTrial() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null || _firestore == null) return;

      await _firestore!.collection('users').doc(user.uid).set({
        'createdAt': FieldValue.serverTimestamp(),
        'trialEnded': false,
        'isPremium': true, // Trial users get premium features
      }, SetOptions(merge: true));

    } catch (e) {
    }
  }

  /// Start trial with selected plan - Platform-specific handling
  Future<void> startTrialWithPlan(String planType) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null || _firestore == null) {
        throw Exception('User moet ingelogd zijn om proefperiode te starten');
      }

      // Platform-specific trial handling
      if (Platform.isIOS) {
        await _startTrialWithPlanIOS(planType, user);
      } else if (Platform.isAndroid) {
        await _startTrialWithPlanAndroid(planType, user);
      } else {
        throw UnsupportedError('Platform not supported for trial setup');
      }
    } catch (e) {
    }
  }

  /// iOS-specific trial setup
  Future<void> _startTrialWithPlanIOS(String planType, User user) async {
    print('🔍 iOS Trial Setup: Starting for plan $planType');
    
    // iOS Simulator bypass
    bool isSimulator = false;
    try {
      isSimulator = Platform.environment.containsKey('SIMULATOR_DEVICE_NAME');
    } catch (_) {}
    
    if (Platform.isIOS && isSimulator) {
      print('🔍 iOS Trial Setup: Detected simulator, bypassing payment');
      await _setupTrialDataIOS(user.uid, planType, planType, 'ios-simulator');
      // Navigate to Quick Setup after successful trial setup (new trial only)
      _navigateToQuickSetup();
      return;
    }

    // Get the correct product ID for iOS
    String productId;
    if (planType == 'monthly') {
      productId = monthlySubscriptionId; // 'jachtproef_monthly_399'
    } else if (planType == 'yearly') {
      productId = yearlySubscriptionId; // 'jachtproef_yearly_2999'
    } else {
      throw Exception('Invalid plan type: $planType');
    }
    
    print('🔍 iOS Trial Setup: Using product ID $productId');

    // Initialize the in-app purchase if not already done
    if (!_isAvailable) {
      print('🔍 iOS Trial Setup: Initializing in-app purchase');
      await initialize();
    }

    // Enhanced product loading with fallback for real devices
    if (_products.isEmpty) {
      print('🔍 iOS Trial Setup: Loading products');
      await _loadProducts();
      
      // If products still empty, try one more time with delay
      if (_products.isEmpty) {
        print('🔍 iOS Trial Setup: Products still empty, retrying...');
        await Future.delayed(const Duration(seconds: 2));
        await _loadProducts();
      }
      
      if (_products.isEmpty) {
        // On real devices, if products can't be loaded but IAP is available,
        // we should still try to proceed and let the purchase flow handle errors
        final isRealDevice = !(await _isRunningOnSimulator()) && !(await _isRunningOnTestFlightMac());
        if (isRealDevice && _isAvailable) {
          print('⚠️ iOS Trial Setup: Products not loaded but proceeding anyway for real device');
          // Continue without products - the purchase flow will handle the error gracefully
        } else {
        throw Exception('Producten konden niet worden geladen. Controleer je internetverbinding en probeer het opnieuw.');
        }
      }
    }
    
    print('🔍 iOS Trial Setup: Found ${_products.length} products');

    // Verify the specific product is available (with fallback for real devices)
    final hasRequestedProduct = _products.any((p) => p.id == productId);
    if (!hasRequestedProduct) {
      print('🔍 iOS Trial Setup: Product $productId not found, reloading products');
      await _loadProducts();
      final hasProductAfterReload = _products.any((p) => p.id == productId);
      
      if (!hasProductAfterReload) {
        // On real devices, if product is not found but IAP is available,
        // we should still try to proceed and let the purchase flow handle errors
        final isRealDevice = !(await _isRunningOnSimulator()) && !(await _isRunningOnTestFlightMac());
        if (isRealDevice && _isAvailable) {
          print('⚠️ iOS Trial Setup: Product $productId not found but proceeding anyway for real device');
          // Continue without product verification - the purchase flow will handle the error gracefully
        } else {
        throw Exception('Het geselecteerde abonnement is momenteel niet beschikbaar. Probeer het later opnieuw.');
        }
      }
    }

    print('🔍 iOS Trial Setup: Product $productId is available or proceeding anyway');

    // Check if running on simulator or TestFlight on Mac
    final isSimulatorRuntime = await _isRunningOnSimulator();
    final isTestFlightMac = await _isRunningOnTestFlightMac();
    
    print('🔍 iOS Trial Setup: Environment check - Simulator: $isSimulatorRuntime, TestFlight Mac: $isTestFlightMac');
    
    if (isSimulatorRuntime) {
      print('🔍 iOS Trial Setup: Using simulator bypass');
      await _setupTrialDataIOS(user.uid, planType, productId, 'ios-simulator');
      // Navigate to Quick Setup after successful trial setup (new trial only)
      _navigateToQuickSetup();
      return;
    } else if (isTestFlightMac) {
      // TestFlight on Mac: Show payment dialog for real purchase
      print('🔍 iOS Trial Setup: TestFlight on Mac detected, showing payment dialog');
      await _forceApplePaymentDialog(productId, planType);
      return;
    } else {
      // Actual iOS device: Purchase the subscription with trial
      print('🔍 iOS Trial Setup: Regular iOS device, showing payment dialog');
      await _forceApplePaymentDialog(productId, planType);
      return;
    }
  }

  /// Force Apple payment dialog to appear (for development builds and TestFlight on Mac)
  Future<void> _forceApplePaymentDialog(String productId, String planType) async {
    try {
      print('🔍 Payment Dialog: Starting for product $productId');
      
      // CRITICAL: Ensure purchase stream listener is set up before attempting purchase
      await _ensurePurchaseStreamListener();
      
      ProductDetails? product;
      try {
        product = _products.firstWhere((p) => p.id == productId);
      } catch (e) {
        print('❌ Payment Dialog: Product not found in loaded products: $productId');
        
        // On real devices, if product is not found but IAP is available,
        // try to load products one more time
        final isRealDevice = !(await _isRunningOnSimulator()) && !(await _isRunningOnTestFlightMac());
        if (isRealDevice && _isAvailable) {
          print('🔍 Payment Dialog: Attempting to reload products for real device');
          await _loadProducts();
          try {
            product = _products.firstWhere((p) => p.id == productId);
          } catch (e2) {
            print('❌ Payment Dialog: Product still not found after reload: $productId');
            throw Exception('Product niet beschikbaar. Controleer uw internetverbinding en probeer het opnieuw.');
          }
        } else {
        throw Exception('Product not found: $productId');
        }
      }
      
      print('🔍 Payment Dialog: Found product: ${product.title} - ${product.price}');
      
      final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
      
      // Check if we're on TestFlight on Mac and log for debugging
      final isTestFlightMac = await _isRunningOnTestFlightMac();
      if (isTestFlightMac) {
        print('🧪 TestFlight on Mac: Attempting to show payment dialog for $productId');
      } else {
        print('🔍 Payment Dialog: Not TestFlight on Mac, attempting to show payment dialog for $productId');
      }
      
      print('🔍 Payment Dialog: Calling InAppPurchase.instance.buyNonConsumable...');
      final bool success = await InAppPurchase.instance.buyNonConsumable(purchaseParam: purchaseParam);
      
      print('🔍 Payment Dialog: buyNonConsumable returned: $success');
      
      if (success) {
        if (isTestFlightMac) {
          print('✅ TestFlight on Mac: Payment dialog initiated successfully');
        } else {
          print('✅ Payment Dialog: Payment dialog initiated successfully');
        }
        print('🔍 Trial purchase flow initiated - waiting for user confirmation...');
        return;
      } else {
        if (isTestFlightMac) {
          print('❌ TestFlight on Mac: Failed to initiate payment dialog');
        } else {
          print('❌ Payment Dialog: Failed to initiate payment dialog');
        }
        throw Exception('Kon geen aankoop starten. Probeer het opnieuw.');
      }
    } catch (e) {
      print('❌ Payment Dialog: Error occurred: $e');
      if (await _isRunningOnTestFlightMac()) {
        print('❌ TestFlight on Mac: Error in payment dialog: $e');
      }
      rethrow;
    }
  }

  /// Android-specific trial setup
  Future<void> _startTrialWithPlanAndroid(String planType, User user) async {
    // Get the correct product ID for Android (always 'jachtproef_premium')
    String productId = 'jachtproef_premium';

    // Initialize the in-app purchase if not already done
    if (!_isAvailable) {
      await initialize();
    }

    // Ensure products are loaded
    if (_products.isEmpty) {
      await _loadProducts();
      if (_products.isEmpty) {
        throw Exception('Producten konden niet worden geladen. Controleer je internetverbinding en probeer het opnieuw.');
      }
    }

    // Verify the specific product is available
    final hasRequestedProduct = _products.any((p) => p.id == productId);
    if (!hasRequestedProduct) {
      await _loadProducts();
      final hasProductAfterReload = _products.any((p) => p.id == productId);
      if (!hasProductAfterReload) {
        throw Exception('Het geselecteerde abonnement is momenteel niet beschikbaar. Probeer het later opnieuw.');
      }
    }

    // Android device: Purchase the subscription with trial
    await purchaseSubscription(productId, planType: planType);
  }

  /// Handle TestFlight auto-approval without granting premium access
  Future<void> _handleTestFlightAutoApproval(PurchaseDetails purchaseDetails) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null || _firestore == null) return;

      await _firestore!.collection('users').doc(user.uid).set({
        'testFlightAutoApproval': {
          'productId': purchaseDetails.productID,
          'timestamp': FieldValue.serverTimestamp(),
          'note': 'TestFlight auto-approval - no premium access granted for testing'
        }
      }, SetOptions(merge: true));
      
    } catch (e) {
    }
  }

  /// Clear device payment state and reset service (for logout)
  Future<void> clearDevicePaymentState() async {
    try {
      // Clear pending purchase completers
      for (final completer in _pendingPurchaseCompleters.values) {
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      }
      _pendingPurchaseCompleters.clear();
      
      // Cancel subscription listener
      await _subscription?.cancel();
      _subscription = null;
      
      // Reset service state
      _isAvailable = false;
      _products.clear();
      _inAppPurchase = null;
      
      // Reset initialization flag
      _isInitializing = false;
      
      // Clear navigation flag
      clearNavigationFlag();
      
    } catch (e) {
    }
  }

  /// Clear unfinished transactions (for TestFlight testing)
  Future<void> clearUnfinishedTransactions() async {
    try {
      print('🧹 Clearing unfinished transactions...');
      
      if (_inAppPurchase != null) {
        // Force refresh InAppPurchase to clear any cached state
        await _inAppPurchase!.isAvailable();
        
        // Try to restore purchases to trigger transaction completion
        await _inAppPurchase!.restorePurchases();
        
        print('✅ Unfinished transactions cleared');
      }
    } catch (e) {
      print('⚠️ Could not clear unfinished transactions: $e');
    }
  }

  /// Enhanced cleanup for old/dormant payments and TestFlight issues
  /// 
  /// ⚠️ WARNING: This method COMPLETELY RESETS the PaymentService state!
  /// It should ONLY be called for debugging/testing, NEVER during normal app startup.
  /// 
  /// This method resets:
  /// - _isAvailable = false
  /// - _products.clear()
  /// - _inAppPurchase = null
  /// - _isInitializing = false
  /// 
  /// If called after initialization, it will break the payment flow.
  /// Use forceRefreshPaymentService() instead if you need to refresh the service.
  Future<void> cleanupOldDormantPayments() async {
    try {
      print('🧹 Starting comprehensive cleanup of old/dormant payments...');
      print('⚠️ WARNING: This will completely reset PaymentService state!');
      
      // Step 1: Check for and handle stuck purchase completers
      await checkForStuckPurchaseCompleters();
      
      // Step 2: Clear any remaining pending purchase completers
      for (final completer in _pendingPurchaseCompleters.values) {
        if (!completer.isCompleted) {
          print('🧹 Completing stuck purchase completer');
          completer.complete(false);
        }
      }
      _pendingPurchaseCompleters.clear();
      
      // Step 2: Cancel any existing purchase stream listener
      if (_subscription != null) {
        print('🧹 Canceling existing purchase stream listener');
        await _subscription!.cancel();
        _subscription = null;
      }
      
      // Step 3: Clear unfinished transactions (especially important for TestFlight)
      if (_inAppPurchase != null) {
        print('🧹 Clearing unfinished transactions via InAppPurchase');
        try {
          // Force refresh InAppPurchase to clear any cached state
          await _inAppPurchase!.isAvailable();
          
          // Try to restore purchases to trigger transaction completion
          await _inAppPurchase!.restorePurchases();
        } catch (e) {
          print('⚠️ Error during InAppPurchase cleanup: $e');
        }
      }
      
      // Step 4: Reset service state to force fresh initialization
      // ⚠️ CRITICAL: This completely breaks the PaymentService if called after initialization
      print('🧹 Resetting payment service state');
      print('⚠️ CRITICAL: Setting _isAvailable = false, _inAppPurchase = null');
      _isAvailable = false;
      _products.clear();
      _inAppPurchase = null;
      _isInitializing = false;
      
      // Step 5: Clear navigation flag
      clearNavigationFlag();
      
      // Step 6: Platform-specific cleanup
      if (Platform.isIOS) {
        print('🧹 Performing iOS-specific cleanup');
        await _cleanupIOSDormantPayments();
      } else if (Platform.isAndroid) {
        print('🧹 Performing Android-specific cleanup');
        await _cleanupAndroidDormantPayments();
      }
      
      print('✅ Comprehensive cleanup of old/dormant payments completed');
      
    } catch (e) {
      print('❌ Error during comprehensive cleanup: $e');
    }
  }

  /// iOS-specific cleanup for dormant payments
  Future<void> _cleanupIOSDormantPayments() async {
    try {
      // Check if running on TestFlight on Mac
      final isTestFlightMac = await _isRunningOnTestFlightMac();
      if (isTestFlightMac) {
        print('🧹 iOS: TestFlight on Mac detected, performing special cleanup');
        
        // For TestFlight on Mac, we need to be extra careful with transaction cleanup
        if (_inAppPurchase != null) {
          try {
            // Force multiple restore attempts to clear any stuck transactions
            for (int i = 0; i < 3; i++) {
              print('🧹 iOS: TestFlight cleanup attempt ${i + 1}/3');
              await _inAppPurchase!.restorePurchases();
              await Future.delayed(const Duration(milliseconds: 500));
            }
          } catch (e) {
            print('⚠️ iOS: TestFlight cleanup error: $e');
          }
        }
      }
      
      // Clear any cached product information
      _products.clear();
      
    } catch (e) {
      print('❌ iOS: Error during iOS-specific cleanup: $e');
    }
  }

  /// Android-specific cleanup for dormant payments
  Future<void> _cleanupAndroidDormantPayments() async {
    try {
      // Clear any cached product information
      _products.clear();
      
      // For Android, we rely on the standard InAppPurchase cleanup
      // which should handle most dormant payment issues
      
    } catch (e) {
      print('❌ Android: Error during Android-specific cleanup: $e');
    }
  }

  /// Force refresh payment service state
  Future<void> forceRefreshPaymentService() async {
    try {
      print('🔍 Force Refresh: Starting payment service refresh');
      
      // Clear current state
      await clearDevicePaymentState();
      
      // Re-initialize
      await initialize();
      
      // Reload products
      await _loadProducts();
      
      print('🔍 Force Refresh: Payment service refreshed successfully');
    } catch (e) {
      print('❌ Force Refresh: Error refreshing payment service: $e');
    }
  }

  /// Enhanced purchase subscription with better error handling
  Future<Map<String, dynamic>> purchaseSubscriptionWithErrorHandling(String productId, {String? planType}) async {
    final result = <String, dynamic>{
      'success': false,
      'error': null,
      'userMessage': null,
      'canRetry': false,
      'details': <String, dynamic>{},
    };

    try {
      print('🔍 Purchase Error Handling: Starting purchase for $productId');
      
      // Check network connectivity first
      print('🔍 Purchase Error Handling: Checking network connectivity...');
      if (!await _checkNetworkConnectivity()) {
        print('❌ Purchase Error Handling: Network connectivity check failed');
        result['error'] = 'no_network';
        result['userMessage'] = 'Geen internetverbinding. Controleer uw netwerk en probeer het opnieuw.';
        result['canRetry'] = true;
        return result;
      }
      print('✅ Purchase Error Handling: Network connectivity check passed');

      // Check if payment service is available and ensure it's initialized
      print('🔍 Purchase Error Handling: Checking payment service availability...');
      print('🔍 Purchase Error Handling: _isAvailable: $_isAvailable, _inAppPurchase: ${_inAppPurchase != null}');
      
      if (!await ensureInitialized()) {
        print('❌ Purchase Error Handling: Payment service not available after initialization attempt');
        result['error'] = 'payment_not_available';
        result['userMessage'] = 'Betalingen zijn momenteel niet beschikbaar. Probeer het later opnieuw.';
        result['canRetry'] = true;
        return result;
      }
      print('✅ Purchase Error Handling: Payment service is available and properly initialized');

      // Ensure products are loaded
      print('🔍 Purchase Error Handling: Checking if products are loaded...');
      print('🔍 Purchase Error Handling: Current products count: ${_products.length}');
      if (_products.isEmpty) {
        print('🔍 Purchase Error Handling: No products loaded, attempting to load...');
        try {
          await _loadProducts();
          print('🔍 Purchase Error Handling: Products loaded, count: ${_products.length}');
          if (_products.isEmpty) {
            print('❌ Purchase Error Handling: Products still empty after loading');
            result['error'] = 'products_not_loaded';
            result['userMessage'] = 'Producten konden niet worden geladen. Controleer uw internetverbinding.';
            result['canRetry'] = true;
            return result;
          }
        } catch (e) {
          print('❌ Purchase Error Handling: Error loading products: $e');
          result['error'] = 'product_load_failed';
          result['userMessage'] = 'Producten konden niet worden geladen. Probeer het opnieuw.';
          result['canRetry'] = true;
          return result;
        }
      }
      print('✅ Purchase Error Handling: Products are loaded');

      // Attempt purchase with retry logic
      int attempts = 0;
      const maxAttempts = 2;
      
      while (attempts < maxAttempts) {
        attempts++;
        result['details']['attempt'] = attempts;
        
        try {
          final success = await purchaseSubscription(productId, planType: planType);
          if (success) {
            result['success'] = true;
            result['userMessage'] = 'Aankoop succesvol!';
            return result;
          } else {
            // Purchase was initiated but failed
            result['error'] = 'purchase_failed';
            result['userMessage'] = 'Aankoop mislukt. Probeer het opnieuw.';
            result['canRetry'] = true;
            return result;
          }
        } catch (e) {
          final errorStr = e.toString().toLowerCase();
          
          if (errorStr.contains('timeout') || errorStr.contains('payment dialog did not appear')) {
            if (attempts < maxAttempts) {
              await Future.delayed(Duration(seconds: attempts * 2));
              continue;
            }
            result['error'] = 'timeout';
            result['userMessage'] = 'Betaling dialoog verscheen niet. Probeer het opnieuw.';
            result['canRetry'] = true;
            return result;
          } else if (errorStr.contains('network') || errorStr.contains('connection')) {
            if (attempts < maxAttempts) {
              await Future.delayed(Duration(seconds: attempts * 2));
              continue;
            }
            result['error'] = 'network_error';
            result['userMessage'] = 'Netwerkfout tijdens aankoop. Controleer uw verbinding.';
            result['canRetry'] = true;
            return result;
          } else if (errorStr.contains('product not found')) {
            result['error'] = 'product_not_found';
            result['userMessage'] = 'Product niet beschikbaar. Probeer het later opnieuw.';
            result['canRetry'] = false;
            return result;
          } else if (errorStr.contains('cancelled') || errorStr.contains('user cancelled')) {
            result['error'] = 'user_cancelled';
            result['userMessage'] = 'Aankoop geannuleerd.';
            result['canRetry'] = true;
            return result;
          } else {
            result['error'] = 'unknown_error';
            result['userMessage'] = 'Er ging iets mis. Probeer het opnieuw.';
            result['canRetry'] = true;
            return result;
          }
        }
      }
      
      result['error'] = 'max_attempts_reached';
      result['userMessage'] = 'Aankoop mislukt na meerdere pogingen. Probeer het later opnieuw.';
      result['canRetry'] = true;
      return result;
      
    } catch (e) {
      result['error'] = 'unexpected_error';
      result['userMessage'] = 'Er ging iets onverwachts mis. Probeer het opnieuw.';
      result['canRetry'] = true;
      result['details']['exception'] = e.toString();
      return result;
    }
  }

  /// Get user-friendly error message for purchase errors
  String getUserFriendlyPurchaseErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'no_network':
        return 'Controleer uw wifi of mobiele data en probeer het opnieuw.';
      case 'payment_not_available':
        return 'Betalingen zijn momenteel niet beschikbaar. Probeer het later opnieuw.';
      case 'products_not_loaded':
      case 'product_load_failed':
        return 'Producten konden niet worden geladen. Controleer uw internetverbinding.';
      case 'purchase_failed':
        return 'Aankoop mislukt. Probeer het opnieuw.';
      case 'timeout':
        return 'Betaling dialoog verscheen niet. Probeer het opnieuw.';
      case 'network_error':
        return 'Netwerkfout tijdens aankoop. Controleer uw verbinding.';
      case 'product_not_found':
        return 'Product niet beschikbaar. Probeer het later opnieuw.';
      case 'user_cancelled':
        return 'Aankoop geannuleerd.';
      case 'max_attempts_reached':
        return 'Aankoop mislukt na meerdere pogingen. Probeer het later opnieuw.';
      case 'unknown_error':
      case 'unexpected_error':
      default:
        return 'Er ging iets mis. Probeer het opnieuw.';
    }
  }

  /// Get troubleshooting steps for iOS payment issues
  List<String> getIOSTroubleshootingSteps() {
    return [
      '1. Controleer of u bent ingelogd in de App Store met een geldig Apple ID',
      '2. Controleer of uw apparaat niet in "Vraag om te kopen" modus staat',
      '3. Controleer of Screen Time of ouderlijk toezicht in-app aankopen niet blokkeert',
      '4. Controleer uw internetverbinding (WiFi of mobiele data)',
      '5. Probeer de app opnieuw op te starten',
      '6. Als het probleem aanhoudt, probeer de app te verwijderen en opnieuw te installeren via TestFlight',
      '7. Controleer of uw Apple ID regio overeenkomt met de beschikbaarheid van de app',
    ];
  }
} 