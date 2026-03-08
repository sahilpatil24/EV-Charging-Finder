import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;

class PaymentService {
  static const String publishableKey =
      'pk_test_51T7xbbBAzaxr8MBGthT4soGFhj7Fhpxgp6kP1h6LD33Zf1TKxYetNw5bs4BOIPkpTpOx2q1vL3vkX8vdme3dkilj00QFu72a2p';

  static const String _baseUrl = 'http://10.0.2.2:3000';

  static void init() {
    Stripe.publishableKey = publishableKey;
    // Do NOT set merchantIdentifier on Android — iOS Apple Pay only
  }

  /// Step 1 only: hit backend, init PaymentSheet, return clientSecret.
  /// Does NOT present the sheet — caller must close bottom sheet first.
  static Future<String> createAndInitPaymentSheet({
    required int amountInPaise,
    required String currency,
    required String description,
  }) async {
    debugPrint('📡 POST $_baseUrl/create-payment-intent  amount=$amountInPaise');

    final response = await http
        .post(
      Uri.parse('$_baseUrl/create-payment-intent'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'amount': amountInPaise,
        'currency': currency,
        'description': description,
      }),
    )
        .timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw Exception(
          'Server timeout — is your Node backend running on port 3000?'),
    );

    debugPrint('📬 Response ${response.statusCode}: ${response.body}');

    if (response.statusCode != 200) {
      throw Exception('Backend error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final clientSecret = data['clientSecret'] as String;
    final paymentIntentId = data['paymentIntentId'] as String;

    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        merchantDisplayName: 'EV Charging Finder',
        style: ThemeMode.dark,
        // Remove shapes entirely
        appearance: PaymentSheetAppearance(
          colors: PaymentSheetAppearanceColors(
            primary: const Color(0xFF00C853),
            background: const Color(0xFF0F172A),
            componentBackground: const Color(0xFF1E293B),
            primaryText: Colors.white,
            secondaryText: Colors.grey,
          ),
        ),
      ),
    );

    return paymentIntentId;
  }

  /// Step 2: present the already-initialised sheet.
  /// Must be called AFTER the bottom sheet is closed.
  /// Returns true = paid, false = cancelled.
  static Future<bool> presentSheet() async {
    try {
      await Stripe.instance.presentPaymentSheet();
      return true;
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        debugPrint('User cancelled payment');
        return false;
      }
      debugPrint('Stripe error: ${e.error.message}');
      rethrow;
    }
  }
}