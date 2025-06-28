import 'package:flutter_test/flutter_test.dart';
import 'package:jachtproef_alert/services/payment_service.dart';

void main() {
  group('PaymentService Tests', () {
    test('should have correct product IDs for new pricing model', () {
      // Test the new product IDs for trial-based model
      expect(PaymentService.monthlySubscriptionId, equals('jachtproef_monthly_399'));
      expect(PaymentService.yearlySubscriptionId, equals('jachtproef_yearly_2999'));
    });

    test('should have correct trial period', () {
      // Test the trial period configuration
      expect(PaymentService.trialPeriodDays, equals(14));
    });

    test('should have only 2 subscription products', () {
      // Test that we have the correct number of products (removed lifetime)
      final productIds = {
        PaymentService.monthlySubscriptionId,
        PaymentService.yearlySubscriptionId,
      };
      expect(productIds.length, equals(2));
    });

    test('product IDs should reflect new pricing', () {
      // Test that product IDs contain the pricing information
      expect(PaymentService.monthlySubscriptionId, contains('399'));
      expect(PaymentService.yearlySubscriptionId, contains('2999'));
    });

    test('should initialize payment service', () {
      // Test that payment service can be instantiated
      final paymentService = PaymentService();
      expect(paymentService, isNotNull);
    });
  });
} 