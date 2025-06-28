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

/// Payment Service that handles 14-day free trial and subscription management
/// 
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

  /// Detect if running on Chromebook
  static Future<bool> isChromebook() async {
    if (_isChromebook != null) return _isChromebook!;
    
    try {
      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      _deviceInfo = '${deviceInfo.brand} ${deviceInfo.model}';
      _isChromebook = deviceInfo.brand.toLowerCase().contains('chromebook') ||
                     deviceInfo.model.toLowerCase().contains('chromebook');
      print('🔍 CHROMEBOOK DETECTION: $_deviceInfo -> isChromebook: $_isChromebook');
      } catch (e) {
        _isChromebook = false;
      print('🔍 CHROMEBOOK DETECTION: Error detecting Chromebook: $e');
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
    print('🚀 PAYMENT INIT: Starting payment service initialization...');
    print('🚀 PAYMENT INIT: Platform: ${Platform.operatingSystem}');
    print('🚀 PAYMENT INIT: Product IDs: ${_productIds.toList()}');
    
    if (_isAvailable) {
      print('🚀 PAYMENT INIT: Already initialized, skipping...');
      return;
    }
      
    try {
      print('🚀 PAYMENT INIT: Setting up Firebase...');
      // Ensure Firebase is initialized
      _firestore = FirebaseFirestore.instance;
      
      print('🚀 PAYMENT INIT: Setting up InAppPurchase instance...');
      // Initialize InAppPurchase instance
      _inAppPurchase = InAppPurchase.instance;
      
      print('🚀 PAYMENT INIT: Checking if InAppPurchase is available...');
      _isAvailable = await InAppPurchase.instance.isAvailable();
      if (!_isAvailable) {
        print('❌ PAYMENT INIT: In-app purchases not available on this device');
        return;
      }

      print('✅ PAYMENT INIT: In-app purchases available');
        
      print('🚀 PAYMENT INIT: Loading products...');
      // Load products
          await _loadProducts();
      
      print('🚀 PAYMENT INIT: Setting up purchase listener...');
      // Set up purchase listener
      _subscription = InAppPurchase.instance.purchaseStream.listen((purchaseDetailsList) {
        // Check if user is authenticated before processing any purchases
        final User? currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          print('🔒 Purchase event received but user is not authenticated - ignoring');
          return;
        }
        
        print('🔍 Processing ${purchaseDetailsList.length} purchase(s) for authenticated user: ${currentUser.uid}');
        
        for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
          _handlePurchaseUpdate(purchaseDetails);
        }
      });

      print('✅ PAYMENT INIT: Payment service initialized successfully');
    } catch (e) {
      print('❌ PAYMENT INIT: Error initializing payment service: $e');
      print('❌ PAYMENT INIT: Error type: ${e.runtimeType}');
      if (e is PlatformException) {
        print('❌ PAYMENT INIT: PlatformException details: code=${e.code}, message=${e.message}, details=${e.details}');
      }
      _isAvailable = false;
    }
  }

  /// Load available products from the store with platform-specific handling
  Future<void> _loadProducts() async {
    try {
      if (_inAppPurchase == null) return;
      
      print('🔍 PAYMENT DEBUG: Starting product load...');
      print('🔍 PAYMENT DEBUG: Platform: ${Platform.operatingSystem}');
      print('🔍 PAYMENT DEBUG: Product IDs to request:');
      for (String id in _productIds) {
        print('   - $id');
      }
      
      print('🔍 PAYMENT DEBUG: Product IDs requested: ${_productIds}');
      final ProductDetailsResponse response = await _inAppPurchase!.queryProductDetails(_productIds);
      print('🔍 PAYMENT DEBUG: Full ProductDetailsResponse: error=${response.error}, notFoundIDs=${response.notFoundIDs}, productDetails=${response.productDetails}');
      
      if (response.notFoundIDs.isNotEmpty) {
        print('❌ PAYMENT ERROR: Products not found in store:');
        for (String id in response.notFoundIDs) {
          print('   - $id');
        }
        
        // Platform-specific troubleshooting
        _logPlatformSpecificTroubleshooting();
      }
      
      _products = response.productDetails;
      print('✅ PAYMENT DEBUG: Successfully loaded ${_products.length} products');
      
      // Platform-specific product verification
      _verifyPlatformSpecificProducts();
      
    } catch (e) {
      print('❌ PAYMENT ERROR: Failed to load products: $e');
      print('🔍 PAYMENT ERROR: Error type: ${e.runtimeType}');
      if (e is PlatformException) {
        print('🔍 PAYMENT ERROR: PlatformException details: code=${e.code}, message=${e.message}, details=${e.details}');
      }
    }
  }

  /// Log platform-specific troubleshooting information
  void _logPlatformSpecificTroubleshooting() {
        if (Platform.isIOS) {
          print('💡 iOS TROUBLESHOOTING:');
          print('   1. Check if products are approved in App Store Connect');
          print('   2. Verify products are in "Ready to Submit" or "Approved" status');
          print('   3. Check if products have 14-day trial offers configured');
          print('   4. Verify app version matches TestFlight/App Store version');
          print('   5. Check if products are available in your region');
          print('   6. Ensure you\'re testing with a real device (not simulator)');
          print('   7. Verify your Apple ID has access to the products');
        } else if (Platform.isAndroid) {
          print('💡 ANDROID TROUBLESHOOTING:');
          print('   1. Check if products are published in Play Console');
          print('   2. Verify app signing key matches Play Console');
          print('   3. Check if products are active and available in your region');
          print('   4. Verify app version matches uploaded APK/AAB');
          print('   5. Check if Play Store account matches country/region');
          print('   6. Ensure Play Store app is up to date');
          print('   7. Verify subscription ID "jachtproef_premium" exists in Play Console');
          print('   8. Check if base plans "monthly" and "yearly" are configured');
          print('   9. Verify product IDs "jachtproef_premium:monthly" and "jachtproef_premium:yearly" are available');
        }
      }
      
  /// Verify platform-specific products are loaded correctly
  void _verifyPlatformSpecificProducts() {
      // Detailed product verification
      for (ProductDetails product in _products) {
        print('   ✅ ${product.id}: ${product.title} - ${product.price}');
        
      // Platform-specific product verification
      if (Platform.isIOS) {
        _verifyIOSProduct(product);
      } else if (Platform.isAndroid) {
        _verifyAndroidProduct(product);
      }
    }
    
    // Platform-specific availability checks
    if (Platform.isIOS) {
      _verifyIOSProductAvailability();
    } else if (Platform.isAndroid) {
      _verifyAndroidProductAvailability();
    }
  }

  /// Verify iOS-specific product details
  void _verifyIOSProduct(ProductDetails product) {
    if (product.id == 'jachtproef_monthly_399') {
          print('🔍 iOS MONTHLY PRODUCT VERIFICATION:');
          print('   - Product ID: ${product.id}');
          print('   - Title: ${product.title}');
          print('   - Description: ${product.description}');
          print('   - Price: ${product.price}');
          print('   - Raw Price: ${product.rawPrice}');
          print('   - Currency Code: ${product.currencyCode}');
    }
        }
        
  /// Verify Android-specific product details
  void _verifyAndroidProduct(ProductDetails product) {
    if (product.id == 'jachtproef_premium') {
          print('🔍 GOOGLE SUPPORT VERIFICATION: ProductDetails for jachtproef_premium:');
          print('   - Title: ${product.title}');
          print('   - Description: ${product.description}');
          print('   - Price: ${product.price}');
          print('   - Raw Price: ${product.rawPrice}');
          print('   - Currency Code: ${product.currencyCode}');
          print('   - Product ID: ${product.id}');
        }
      }
      
  /// Verify iOS product availability
  void _verifyIOSProductAvailability() {
        final hasMonthlyProduct = _products.any((p) => p.id == 'jachtproef_monthly_399');
        final hasYearlyProduct = _products.any((p) => p.id == 'jachtproef_yearly_2999');
        
        if (hasMonthlyProduct) {
          print('✅ iOS VERIFICATION: jachtproef_monthly_399 product found and loaded successfully');
        } else {
          print('❌ iOS VERIFICATION: jachtproef_monthly_399 product NOT found - this is why monthly plan doesn\'t work!');
        }
        
        if (hasYearlyProduct) {
          print('✅ iOS VERIFICATION: jachtproef_yearly_2999 product found and loaded successfully');
        } else {
          print('❌ iOS VERIFICATION: jachtproef_yearly_2999 product NOT found');
        }
  }

  /// Verify Android product availability
  void _verifyAndroidProductAvailability() {
        final hasPremiumProduct = _products.any((p) => p.id == 'jachtproef_premium');
        if (hasPremiumProduct) {
          print('✅ GOOGLE SUPPORT VERIFICATION: jachtproef_premium product found and loaded successfully');
        } else {
          print('❌ GOOGLE SUPPORT VERIFICATION: jachtproef_premium product NOT found - this is the issue!');
    }
  }

  /// Get available subscription products
  List<ProductDetails> get availableProducts => _products;

  /// Check if in-app purchases are available
  bool get isAvailable => _isAvailable;

  /// Diagnostic method to check payment service status
  Future<Map<String, dynamic>> getDiagnosticInfo() async {
    try {
      print('🔍 PAYMENT DIAGNOSTIC: Starting diagnostic check...');
      
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
      
      // Test InAppPurchase availability
      try {
        final iapAvailable = await InAppPurchase.instance.isAvailable();
        diagnostic['iapAvailable'] = iapAvailable;
        print('🔍 PAYMENT DIAGNOSTIC: InAppPurchase.instance.isAvailable() = $iapAvailable');
      } catch (e) {
        diagnostic['iapAvailable'] = false;
        diagnostic['iapError'] = e.toString();
        print('❌ PAYMENT DIAGNOSTIC: InAppPurchase.instance.isAvailable() failed: $e');
      }
      
      // Test product loading if not already loaded
      if (_products.isEmpty && _inAppPurchase != null) {
        print('🔍 PAYMENT DIAGNOSTIC: Attempting to load products...');
        try {
          final response = await _inAppPurchase!.queryProductDetails(_productIds);
          diagnostic['productLoadResponse'] = {
            'error': response.error?.toString(),
            'notFoundIDs': response.notFoundIDs,
            'productDetailsCount': response.productDetails.length,
          };
          print('🔍 PAYMENT DIAGNOSTIC: Product load response: ${diagnostic['productLoadResponse']}');
        } catch (e) {
          diagnostic['productLoadError'] = e.toString();
          print('❌ PAYMENT DIAGNOSTIC: Product loading failed: $e');
        }
      }
      
      print('🔍 PAYMENT DIAGNOSTIC: Complete diagnostic info: $diagnostic');
      return diagnostic;
    } catch (e) {
      print('❌ PAYMENT DIAGNOSTIC: Diagnostic failed: $e');
      return {
        'error': e.toString(),
        'isAvailable': _isAvailable,
        'productsLoaded': _products.length,
      };
    }
  }

  /// Purchase a subscription with platform-specific handling
  Future<bool> purchaseSubscription(String productId, {String? planType}) async {
    print('🟢 [DEBUG] purchaseSubscription called for productId: $productId, planType: $planType');
    print('🟢 [DEBUG] Platform: ${Platform.operatingSystem}');
    
    DebugLoggingService().info('💳 Starting purchase attempt', tag: 'PAYMENT', data: {
      'product_id': productId,
      'plan_type': planType,
      'platform': Platform.operatingSystem,
      'iap_available': _isAvailable,
      'products_loaded': _products.length,
    });
    
    final isChromebookDevice = await isChromebook();
    DebugLoggingService().info('💳 Device check', tag: 'PAYMENT', data: {
      'is_chromebook': isChromebookDevice,
      'device_info': _deviceInfo,
    });
    
    if (!_isAvailable || _inAppPurchase == null) {
      final error = 'In-app purchases not available on ${isChromebookDevice ? "CHROMEBOOK" : Platform.operatingSystem}';
      print('🔴 [DEBUG] purchaseSubscription: Not available, error: $error');
      DebugLoggingService().error('💳 Purchase failed: $error', tag: 'PAYMENT');
      if (isChromebookDevice) {
        DebugLoggingService().warn('💳 Chromebook detected - limited payment support', tag: 'PAYMENT');
        throw Exception('Betalingen zijn beperkt beschikbaar op Chromebooks.\n\n' +
                       'Voor de beste ervaring:\n' +
                       '• Gebruik een Android telefoon of tablet\n' +
                       '• Of gebruik een iPhone/iPad\n' +
                       '• Of probeer via een webbrowser op jachtproefalert.nl');
      }
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
    print('🍎 [DEBUG] iOS purchase flow for productId: $productId');
    
    ProductDetails? product;
    try {
      product = _products.firstWhere((p) => p.id == productId);
      print('🟢 [DEBUG] iOS: Product found: ${product.id}');
      DebugLoggingService().info('💳 iOS Product found', tag: 'PAYMENT', data: {
        'product_id': product.id,
        'product_title': product.title,
        'product_price': product.price,
      });
    } catch (e) {
      print('🔴 [DEBUG] iOS: Product not found for $productId');
      throw Exception('Product niet gevonden: $productId');
    }
    
    // Create a completer to wait for purchase completion
    final completer = Completer<bool>();
    _pendingPurchaseCompleters[productId] = completer;
    
    try {
      final purchaseParam = PurchaseParam(productDetails: product!);
      print('🟢 [DEBUG] iOS: About to call buyNonConsumable for $productId');
      final bool success = await _inAppPurchase!.buyNonConsumable(purchaseParam: purchaseParam);
      print('🟢 [DEBUG] iOS: buyNonConsumable called, success: $success');
      
      if (!success) {
        _pendingPurchaseCompleters.remove(productId);
        return false;
      }
      
      // iOS-specific: Wait for purchase completion with timeout
      print('🟡 [DEBUG] iOS: Waiting for purchase completion...');
      print('🟡 [DEBUG] iOS: Apple payment dialog should appear now');
      
      try {
        // Wait for the purchase to complete with a 30-second timeout
        final result = await completer.future.timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            print('🚨 CRITICAL: iOS purchase timeout - Apple payment dialog did not appear or complete');
            print('🚨 This indicates a serious issue with the iOS payment flow');
            _pendingPurchaseCompleters.remove(productId);
            throw Exception('Apple payment dialog did not appear. Please try again or contact support.');
          },
        );
        return result;
      } catch (e) {
        print('🔴 [DEBUG] iOS: Error during purchase completion: $e');
        _pendingPurchaseCompleters.remove(productId);
        rethrow;
      }
    } catch (e) {
      print('🔴 [DEBUG] iOS: Error during buyNonConsumable: $e');
      _pendingPurchaseCompleters.remove(productId);
      throw Exception('Aankoop mislukt: $e');
    }
  }

  /// Android-specific subscription purchase
  Future<bool> _purchaseSubscriptionAndroid(String productId, {String? planType}) async {
    print('🤖 [DEBUG] Android purchase flow for productId: $productId, planType: $planType');
    
    ProductDetails? product;
    try {
      product = _products.firstWhere((p) => p.id == productId);
      print('🟢 [DEBUG] Android: Product found: ${product.id}');
      DebugLoggingService().info('💳 Android Product found', tag: 'PAYMENT', data: {
        'product_id': product.id,
        'product_title': product.title,
        'product_price': product.price,
        'plan_type': planType,
      });
    } catch (e) {
      print('🔴 [DEBUG] Android: Product not found for $productId');
      throw Exception('Product niet gevonden: $productId');
    }
    
    // Create a completer to wait for purchase completion
    final completer = Completer<bool>();
    _pendingPurchaseCompleters[productId] = completer;
    
    try {
      final purchaseParam = PurchaseParam(productDetails: product!);
      print('🟢 [DEBUG] Android: About to call buyNonConsumable for $productId');
      final bool success = await _inAppPurchase!.buyNonConsumable(purchaseParam: purchaseParam);
      print('🟢 [DEBUG] Android: buyNonConsumable called, success: $success');
      
      if (!success) {
        _pendingPurchaseCompleters.remove(productId);
        return false;
      }
      
      // Android-specific: Wait for purchase completion with timeout
      print('🟡 [DEBUG] Android: Waiting for purchase completion...');
      print('🟡 [DEBUG] Android: Google Play payment dialog should appear now');
      
      try {
        // Wait for the purchase to complete with a 30-second timeout
        final result = await completer.future.timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            print('🚨 CRITICAL: Android purchase timeout - Google Play payment dialog did not appear or complete');
            print('🚨 This indicates a serious issue with the Android payment flow');
            _pendingPurchaseCompleters.remove(productId);
            throw Exception('Google Play payment dialog did not appear. Please try again or contact support.');
          },
        );
        return result;
    } catch (e) {
        print('🔴 [DEBUG] Android: Error during purchase completion: $e');
        _pendingPurchaseCompleters.remove(productId);
        rethrow;
      }
    } catch (e) {
      print('🔴 [DEBUG] Android: Error during buyNonConsumable: $e');
      _pendingPurchaseCompleters.remove(productId);
      throw Exception('Aankoop mislukt: $e');
    }
  }

  /// Handle purchase updates with platform-specific logic
  void _handlePurchaseUpdate(PurchaseDetails purchaseDetails) async {
    print('🔍 [DEBUG] Processing purchase update for platform: ${Platform.operatingSystem}');
    print('🔍 [DEBUG] Product ID: ${purchaseDetails.productID}');
    print('🔍 [DEBUG] Status: ${purchaseDetails.status}');
    print('🔍 [DEBUG] pendingCompletePurchase: ${purchaseDetails.pendingCompletePurchase}');
    
      // CHROMEBOOK DEBUG: Enhanced error logging
      final isChromebookDevice = await isChromebook();
    
    // Platform-specific purchase handling
    if (Platform.isIOS) {
      _handlePurchaseUpdateIOS(purchaseDetails, isChromebookDevice);
    } else if (Platform.isAndroid) {
      _handlePurchaseUpdateAndroid(purchaseDetails, isChromebookDevice);
    } else {
      print('❌ [DEBUG] Unsupported platform for purchase handling');
    }
  }

  /// iOS-specific purchase update handling
  void _handlePurchaseUpdateIOS(PurchaseDetails purchaseDetails, bool isChromebookDevice) {
    print('🍎 [DEBUG] iOS purchase update handling');
    
    if (purchaseDetails.status == PurchaseStatus.purchased ||
        purchaseDetails.status == PurchaseStatus.restored) {
      
      // iOS-specific: Handle TestFlight auto-approval and normal App Store purchases
      if (purchaseDetails.pendingCompletePurchase == true) {
        print('✅ iOS: Purchase confirmed and needs completion: ${purchaseDetails.productID}');
      } else {
        print('🟡 iOS: TestFlight auto-approval detected: ${purchaseDetails.productID}');
        print('🟡 iOS: This is normal TestFlight behavior - purchase was auto-approved');
      }
      
      // Handle successful purchase (both TestFlight auto-approval and normal purchases)
      _handleSuccessfulPurchase(purchaseDetails);
      
      // Complete pending purchase with success
      final completer = _pendingPurchaseCompleters.remove(purchaseDetails.productID);
      if (completer != null && !completer.isCompleted) {
        completer.complete(true);
      }
    } else if (purchaseDetails.status == PurchaseStatus.error) {
      _handlePurchaseErrorIOS(purchaseDetails, isChromebookDevice);
    } else if (purchaseDetails.status == PurchaseStatus.canceled) {
      _handlePurchaseCancellationIOS(purchaseDetails, isChromebookDevice);
    }

    // Complete the purchase if needed
    if (purchaseDetails.pendingCompletePurchase) {
      _completePurchaseIOS(purchaseDetails, isChromebookDevice);
    }
  }

  /// Android-specific purchase update handling
  void _handlePurchaseUpdateAndroid(PurchaseDetails purchaseDetails, bool isChromebookDevice) {
    print('🤖 [DEBUG] Android purchase update handling');
    
    if (purchaseDetails.status == PurchaseStatus.purchased ||
        purchaseDetails.status == PurchaseStatus.restored) {
      
      // Android-specific: Handle Google Play purchases
      if (purchaseDetails.pendingCompletePurchase == true) {
        print('✅ Android: Purchase confirmed and needs completion: ${purchaseDetails.productID}');
      } else {
        print('🟡 Android: Purchase already completed: ${purchaseDetails.productID}');
      }
      
      // Handle successful purchase
      _handleSuccessfulPurchase(purchaseDetails);
      
      // Complete pending purchase with success
      final completer = _pendingPurchaseCompleters.remove(purchaseDetails.productID);
      if (completer != null && !completer.isCompleted) {
        completer.complete(true);
      }
    } else if (purchaseDetails.status == PurchaseStatus.error) {
      _handlePurchaseErrorAndroid(purchaseDetails, isChromebookDevice);
    } else if (purchaseDetails.status == PurchaseStatus.canceled) {
      _handlePurchaseCancellationAndroid(purchaseDetails, isChromebookDevice);
    }

    // Complete the purchase if needed
    if (purchaseDetails.pendingCompletePurchase) {
      _completePurchaseAndroid(purchaseDetails, isChromebookDevice);
    }
  }

  /// Handle iOS-specific purchase errors
  void _handlePurchaseErrorIOS(PurchaseDetails purchaseDetails, bool isChromebookDevice) {
        final errorCode = purchaseDetails.error?.code;
        final errorMessage = purchaseDetails.error?.message;
        
    print('❌ iOS: Purchase error: $errorCode - $errorMessage');
        
        if (isChromebookDevice) {
      print('🚨 iOS CHROMEBOOK ERROR DETECTED:');
      print('   Device: $_deviceInfo');
      print('   This error might be Chromebook-specific!');
    }
    
    // Complete pending purchase with error
    final completer = _pendingPurchaseCompleters.remove(purchaseDetails.productID);
    if (completer != null && !completer.isCompleted) {
      completer.complete(false);
    }
  }

  /// Handle Android-specific purchase errors
  void _handlePurchaseErrorAndroid(PurchaseDetails purchaseDetails, bool isChromebookDevice) {
    final errorCode = purchaseDetails.error?.code;
    final errorMessage = purchaseDetails.error?.message;
    
    print('❌ Android: Purchase error: $errorCode - $errorMessage');
    
    if (isChromebookDevice) {
      print('🚨 Android CHROMEBOOK ERROR DETECTED:');
          print('   Device: $_deviceInfo');
          print('   This error might be Chromebook-specific!');
          
          // Log specific Chromebook error patterns
          if (errorCode == 'BillingResponseCode.BILLING_UNAVAILABLE') {
            print('💡 CHROMEBOOK: Google Play Billing might not be properly configured');
          } else if (errorCode == 'BillingResponseCode.ITEM_UNAVAILABLE') {
            print('💡 CHROMEBOOK: Subscription products might not be available on this device');
          } else if (errorCode == 'BillingResponseCode.DEVELOPER_ERROR') {
            print('💡 CHROMEBOOK: App signing or configuration issue');
          }
        }
        
        // Complete pending purchase with error
        final completer = _pendingPurchaseCompleters.remove(purchaseDetails.productID);
        if (completer != null && !completer.isCompleted) {
          completer.complete(false);
        }
  }

  /// Handle iOS-specific purchase cancellations
  void _handlePurchaseCancellationIOS(PurchaseDetails purchaseDetails, bool isChromebookDevice) {
    print('🚫 iOS: Purchase canceled by user: ${purchaseDetails.productID}');
    if (isChromebookDevice) {
      print('🔍 iOS CHROMEBOOK: User canceled - check if payment UI is working properly');
    }
        
    // Complete pending purchase with cancellation
        final completer = _pendingPurchaseCompleters.remove(purchaseDetails.productID);
        if (completer != null && !completer.isCompleted) {
      completer.complete(false);
        }
  }

  /// Handle Android-specific purchase cancellations
  void _handlePurchaseCancellationAndroid(PurchaseDetails purchaseDetails, bool isChromebookDevice) {
    print('🚫 Android: Purchase canceled by user: ${purchaseDetails.productID}');
        if (isChromebookDevice) {
      print('🔍 Android CHROMEBOOK: User canceled - check if payment UI is working properly');
        }
        
        // Complete pending purchase with cancellation
        final completer = _pendingPurchaseCompleters.remove(purchaseDetails.productID);
        if (completer != null && !completer.isCompleted) {
          completer.complete(false);
        }
      }

  /// Complete iOS purchase
  void _completePurchaseIOS(PurchaseDetails purchaseDetails, bool isChromebookDevice) {
        try {
      InAppPurchase.instance.completePurchase(purchaseDetails);
      print('✅ iOS: Purchase completed successfully');
        } catch (e) {
      print('❌ iOS: Error completing purchase: $e');
          if (isChromebookDevice) {
        print('🚨 iOS CHROMEBOOK: Error in completePurchase() - this might be the root cause!');
          }
        }
      }

  /// Complete Android purchase
  void _completePurchaseAndroid(PurchaseDetails purchaseDetails, bool isChromebookDevice) {
    try {
      InAppPurchase.instance.completePurchase(purchaseDetails);
      print('✅ Android: Purchase completed successfully');
    } catch (e) {
      print('❌ Android: Error completing purchase: $e');
      if (isChromebookDevice) {
        print('🚨 Android CHROMEBOOK: Error in completePurchase() - this might be the root cause!');
      }
    }
  }

  /// Handle successful purchase with platform-specific logic
  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchaseDetails) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null || _firestore == null) return;

      print('✅ Purchase successful: ${purchaseDetails.productID}');
      print('✅ Platform: ${Platform.operatingSystem}');
      
      // Platform-specific successful purchase handling
      if (Platform.isIOS) {
        await _handleSuccessfulPurchaseIOS(purchaseDetails, user);
      } else if (Platform.isAndroid) {
        await _handleSuccessfulPurchaseAndroid(purchaseDetails, user);
      } else {
        print('❌ [DEBUG] Unsupported platform for successful purchase handling');
      }

      // Track purchase completion for abandonment analysis
      await PlanAbandonmentService.trackPurchaseCompletion();
    } catch (e) {
      print('Error handling successful purchase: $e');
    }
  }

  /// iOS-specific successful purchase handling
  Future<void> _handleSuccessfulPurchaseIOS(PurchaseDetails purchaseDetails, User user) async {
    print('🍎 [DEBUG] iOS successful purchase handling');
      
    // Check if this is a trial purchase for iOS
    final bool isTrialPurchase = purchaseDetails.productID == 'jachtproef_monthly_399' || 
                                 purchaseDetails.productID == 'jachtproef_yearly_2999';
    
    if (isTrialPurchase) {
      // This is a trial purchase - set up trial data
      final String planType = purchaseDetails.productID == 'jachtproef_monthly_399' ? 'monthly' : 'yearly';
      
      await _setupTrialDataIOS(user.uid, planType, purchaseDetails.productID, 'ios');
      print('✅ iOS: Trial setup completed for plan: $planType');
      
      // Navigate to Quick Setup after successful trial setup (new trial only)
      // Only call this for new purchases, not restored purchases
      if (purchaseDetails.status == PurchaseStatus.purchased) {
        _navigateToQuickSetup();
      }
    }
  }

  /// Android-specific successful purchase handling
  Future<void> _handleSuccessfulPurchaseAndroid(PurchaseDetails purchaseDetails, User user) async {
    print('🤖 [DEBUG] Android successful purchase handling');
    
    // Check if this is a trial purchase for Android
    final bool isTrialPurchase = purchaseDetails.productID == 'jachtproef_premium';
    
    if (isTrialPurchase) {
      // For Android, we need to determine the plan type from the purchase details
      // This might need to be passed from the calling context or determined differently
      final String planType = 'monthly'; // Default fallback - this should be improved
      
      await _setupTrialDataAndroid(user.uid, planType, purchaseDetails.productID, 'android');
      print('✅ Android: Trial setup completed for plan: $planType');
      
      // Navigate to Quick Setup after successful trial setup (new trial only)
      // Only call this for new purchases, not restored purchases
      if (purchaseDetails.status == PurchaseStatus.purchased) {
        _navigateToQuickSetup();
      }
    }
  }

  /// iOS-specific trial data setup
  Future<void> _setupTrialDataIOS(String userId, String planType, String productId, String platform) async {
    await _firestore!.collection('users').doc(userId).set({
          'createdAt': FieldValue.serverTimestamp(),
          'trialStartDate': FieldValue.serverTimestamp(),
          'selectedPlan': planType,
          'subscriptionStatus': 'trial',
          'trialEndDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 14))),
          'trialEnded': false,
      'isPremium': true, // Only granted AFTER successful subscription setup
      'paymentSetupCompleted': true, // Mark payment flow as completed
          'subscription': {
        'productId': productId,
            'status': 'trial',
        'platform': platform,
            'trialStartDate': FieldValue.serverTimestamp(),
            'trialEndDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 14))),
        'willAutoRenew': true,
        'autoRenewDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 14))),
          },
        }, SetOptions(merge: true));

    print('✅ iOS: Trial started with plan: $planType - Subscription will auto-charge after 14 days');
  }

  /// Android-specific trial data setup
  Future<void> _setupTrialDataAndroid(String userId, String planType, String productId, String platform) async {
    await _firestore!.collection('users').doc(userId).set({
      'createdAt': FieldValue.serverTimestamp(),
      'trialStartDate': FieldValue.serverTimestamp(),
      'selectedPlan': planType,
      'subscriptionStatus': 'trial',
      'trialEndDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 14))),
      'trialEnded': false,
      'isPremium': true, // Only granted AFTER successful subscription setup
      'paymentSetupCompleted': true, // Mark payment flow as completed
      'subscription': {
        'productId': productId,
        'status': 'trial',
        'platform': platform,
        'trialStartDate': FieldValue.serverTimestamp(),
        'trialEndDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 14))),
        'willAutoRenew': true,
        'autoRenewDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 14))),
      },
    }, SetOptions(merge: true));

    print('✅ Android: Trial started with plan: $planType - Subscription will auto-charge after 14 days');
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
    if (_shouldNavigateToQuickSetup) {
      print('🔍 Navigation already in progress, skipping duplicate call');
      return;
    }
    print('🔍 DEBUG: _navigateToQuickSetup called - this should only happen after successful trial setup');
    print('🔍 DEBUG: Stack trace: ${StackTrace.current}');
    print('🔍 Setting navigation flag for Quick Setup...');
    _shouldNavigateToQuickSetup = true;
    notifyListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('🔍 Navigation flag set, AuthWrapper will handle navigation');
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
        // Check if we're running on macOS (TestFlight on Mac)
        if (Platform.operatingSystem == 'macos') {
          print('🟡 [DEBUG] Running on macOS (TestFlight) - NOT a simulator');
          return false;
        }
        
        // Check for simulator environment variables
        final isSimulator = Platform.environment.containsKey('SIMULATOR_DEVICE_NAME') ||
                           Platform.environment.containsKey('SIMULATOR_HOST_HOME') ||
                           Platform.environment.containsKey('SIMULATOR_DEVICE_FAMILY');
        
        print('🟡 [DEBUG] iOS environment check - isSimulator: $isSimulator');
        return isSimulator;
      }
      return false;
    } catch (e) {
      print('Error checking simulator: $e');
      return false;
    }
  }

  /// Restore purchases
  Future<void> restorePurchases() async {
    if (!_isAvailable || _inAppPurchase == null) return;

    try {
      await _inAppPurchase!.restorePurchases();
    } catch (e) {
      print('Error restoring purchases: $e');
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
      print('Error getting subscription info: $e');
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
        print('❌ No authenticated user for email sending');
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
        print('✅ Subscription email sent: ${result['message']}');
        print('📧 Email ID: ${result['email_id']}');
      } else {
        print('❌ Failed to send subscription email: ${response.statusCode}');
        print('Response: ${response.body}');
      }
    } catch (e) {
      print('❌ Error sending subscription email: $e');
      // Don't throw error - email is nice-to-have, not critical
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
    print('✅ DEBUG: Forced bypass trial started for plan: $planType');
  }

  Future<bool> isInAppPurchaseAvailable() async {
    try {
      return await InAppPurchase.instance.isAvailable();
    } catch (e) {
      // TODO: Handle or log error if needed
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
      print('Error checking trial status: $e');
      return false;
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
      print('Error getting trial days remaining: $e');
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
      print('Error checking subscription: $e');
      return false;
    }
  }

  /// Check if user has premium access (trial or subscription)
  Future<bool> hasPremiumAccess() async {
    try {
      final bool inTrial = await isInTrialPeriod();
      final bool hasSubscription = await hasActiveSubscription();
      final bool hasPremium = inTrial || hasSubscription;
      
      // CHROMEBOOK DEBUG: Log premium access checks
      final isChromebookDevice = await isChromebook();
      if (isChromebookDevice) {
        print('🔍 CHROMEBOOK PREMIUM CHECK: inTrial=$inTrial, hasSubscription=$hasSubscription, result=$hasPremium');
      }
      
      return hasPremium;
    } catch (e) {
      print('❌ Error checking premium access: $e');
      final isChromebookDevice = await isChromebook();
      if (isChromebookDevice) {
        print('🚨 CHROMEBOOK: Error in premium access check - defaulting to false');
      }
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
      print('❌ Error checking payment setup status: $e');
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

      print('Trial started for user');
    } catch (e) {
      print('Error starting trial: $e');
    }
  }

  /// Start trial with selected plan - Platform-specific handling
  Future<void> startTrialWithPlan(String planType) async {
    print('🟢 [DEBUG] startTrialWithPlan called with planType: $planType');
    print('🟢 [DEBUG] Platform: ${Platform.operatingSystem}');
    
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null || _firestore == null) {
        print('🔴 [DEBUG] User not logged in or Firestore not available');
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
      print('❌ Error starting trial with plan: $e');
      rethrow;
    }
  }

  /// iOS-specific trial setup
  Future<void> _startTrialWithPlanIOS(String planType, User user) async {
    print('🍎 [DEBUG] iOS trial setup for planType: $planType');
    
    // iOS Simulator bypass
    bool isSimulator = false;
    try {
      isSimulator = Platform.environment.containsKey('SIMULATOR_DEVICE_NAME');
    } catch (_) {}
    print('🟡 [DEBUG] iOS: isSimulator: $isSimulator, Platform: ${Platform.operatingSystem}');
    
    if (Platform.isIOS && isSimulator) {
      print('🟠 [DEBUG] iOS: Simulator bypass triggered');
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
      print('🔴 [DEBUG] iOS: Invalid plan type: $planType');
      throw Exception('Invalid plan type: $planType');
    }

    // Initialize the in-app purchase if not already done
    if (!_isAvailable) {
      print('🟡 [DEBUG] iOS: Payment service not available, initializing...');
      await initialize();
    }

    // Ensure products are loaded
    if (_products.isEmpty) {
      print('🟡 [DEBUG] iOS: No products loaded, attempting to load products...');
      await _loadProducts();
      if (_products.isEmpty) {
        print('🔴 [DEBUG] iOS: Still no products loaded after retry');
        throw Exception('Producten konden niet worden geladen. Controleer je internetverbinding en probeer het opnieuw.');
      }
    }

    // Verify the specific product is available
    final hasRequestedProduct = _products.any((p) => p.id == productId);
    print('🟡 [DEBUG] iOS: Checking if requested product $productId is available: $hasRequestedProduct');
    if (!hasRequestedProduct) {
      print('🔴 [DEBUG] iOS: Requested product $productId not found in available products');
      print('🔍 iOS: Available products: ${_products.map((p) => p.id).toList()}');
      // Try to reload products one more time
      print('🟡 [DEBUG] iOS: Final attempt to reload products...');
      await _loadProducts();
      final hasProductAfterReload = _products.any((p) => p.id == productId);
      print('🟡 [DEBUG] iOS: Product available after reload: $hasProductAfterReload');
      if (!hasProductAfterReload) {
        print('🔴 [DEBUG] iOS: Product still not available after reload');
        throw Exception('Het geselecteerde abonnement is momenteel niet beschikbaar. Probeer het later opnieuw.');
      }
    }

    // Check if running on simulator
    final isSimulatorRuntime = await _isRunningOnSimulator();
    print('🟡 [DEBUG] iOS: isRunningOnSimulator: $isSimulatorRuntime');
    print('🟡 [DEBUG] iOS: Platform.operatingSystem: ${Platform.operatingSystem}');
    print('🟡 [DEBUG] iOS: Platform.isIOS: ${Platform.isIOS}');
    print('🟡 [DEBUG] iOS: Platform.environment keys: ${Platform.environment.keys.where((key) => key.contains('SIMULATOR')).toList()}');
    
    if (isSimulatorRuntime) {
      print('🟠 [DEBUG] iOS: Simulator detected in runtime check, bypassing payment');
      await _setupTrialDataIOS(user.uid, planType, productId, 'ios-simulator');
      // Navigate to Quick Setup after successful trial setup (new trial only)
      _navigateToQuickSetup();
      return;
    } else {
      // Actual iOS device: Purchase the subscription with trial
      print('🟢 [DEBUG] iOS: About to call purchaseSubscription for $productId, planType: $planType');
      print('🟢 [DEBUG] iOS: This should trigger the Apple payment dialog');
      await purchaseSubscription(productId, planType: planType);
      print('🟢 [DEBUG] iOS: purchaseSubscription call finished (should now wait for user confirmation)');
      // Note: _navigateToQuickSetup() will be called in the purchase callback after successful purchase
      return;
    }
  }

  /// Android-specific trial setup
  Future<void> _startTrialWithPlanAndroid(String planType, User user) async {
    print('🤖 [DEBUG] Android trial setup for planType: $planType');
    
    // Get the correct product ID for Android (always 'jachtproef_premium')
    String productId = 'jachtproef_premium';
    print('🟡 [DEBUG] Android: Using jachtproef_premium for $planType subscription');

    // Initialize the in-app purchase if not already done
    if (!_isAvailable) {
      print('🟡 [DEBUG] Android: Payment service not available, initializing...');
      await initialize();
    }

    // Ensure products are loaded
    if (_products.isEmpty) {
      print('🟡 [DEBUG] Android: No products loaded, attempting to load products...');
      await _loadProducts();
      if (_products.isEmpty) {
        print('🔴 [DEBUG] Android: Still no products loaded after retry');
        throw Exception('Producten konden niet worden geladen. Controleer je internetverbinding en probeer het opnieuw.');
      }
    }

    // Verify the specific product is available
    final hasRequestedProduct = _products.any((p) => p.id == productId);
    print('🟡 [DEBUG] Android: Checking if requested product $productId is available: $hasRequestedProduct');
    if (!hasRequestedProduct) {
      print('🔴 [DEBUG] Android: Requested product $productId not found in available products');
      print('🔍 Android: Available products: ${_products.map((p) => p.id).toList()}');
      // Try to reload products one more time
      print('🟡 [DEBUG] Android: Final attempt to reload products...');
      await _loadProducts();
      final hasProductAfterReload = _products.any((p) => p.id == productId);
      print('🟡 [DEBUG] Android: Product available after reload: $hasProductAfterReload');
      if (!hasProductAfterReload) {
        print('🔴 [DEBUG] Android: Product still not available after reload');
        throw Exception('Het geselecteerde abonnement is momenteel niet beschikbaar. Probeer het later opnieuw.');
      }
    }

    // Android device: Purchase the subscription with trial
    print('🟢 [DEBUG] Android: About to call purchaseSubscription for $productId, planType: $planType');
    print('🟢 [DEBUG] Android: This should trigger the Google Play payment dialog');
    await purchaseSubscription(productId, planType: planType);
    print('🟢 [DEBUG] Android: purchaseSubscription call finished (should now wait for user confirmation)');
    // Note: _navigateToQuickSetup() will be called in the purchase callback after successful purchase
  }
} 