import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/environment.dart';
import 'auth_service.dart';

class DonationService {
  final AuthService _authService = AuthService();
  
  /// Get API base URL from centralized Environment configuration
  static String get baseUrl => Environment.apiBaseUrl;
  
  /// Create a Stripe payment intent for donation
  Future<Map<String, dynamic>> createPaymentIntent({
    required int recipientUserId,
    required double amount,
    String currency = 'USD',
  }) async {
    try {
      final headers = await _authService.getAuthHeaders();
      headers['Content-Type'] = 'application/json';
      
      final response = await http.post(
        Uri.parse('$baseUrl/donations/create-payment-intent'),
        headers: headers,
        body: jsonEncode({
          'recipient_user_id': recipientUserId,
          'amount': amount,
          'currency': currency,
        }),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        final errorBody = response.body;
        try {
          final error = json.decode(errorBody);
          throw Exception(error['detail'] ?? 'Failed to create payment intent');
        } catch (_) {
          throw Exception('Failed to create payment intent: ${response.statusCode}');
        }
      }
    } catch (e) {
      throw Exception('Payment intent error: $e');
    }
  }
  
  /// Confirm donation after Stripe payment succeeds
  Future<Map<String, dynamic>> confirmDonation(String paymentIntentId) async {
    try {
      final headers = await _authService.getAuthHeaders();
      
      final response = await http.post(
        Uri.parse('$baseUrl/donations/confirm/$paymentIntentId'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        final errorBody = response.body;
        try {
          final error = json.decode(errorBody);
          throw Exception(error['detail'] ?? 'Failed to confirm donation');
        } catch (_) {
          throw Exception('Failed to confirm donation: ${response.statusCode}');
        }
      }
    } catch (e) {
      throw Exception('Confirmation error: $e');
    }
  }

  /// Process a donation (legacy method)
  Future<Map<String, dynamic>> processDonation({
    required int recipientUserId,
    required double amount,
    String currency = 'USD',
    required String paymentMethod, // 'stripe' or 'paypal'
  }) async {
    try {
      final headers = await _authService.getAuthHeaders();
      headers['Content-Type'] = 'application/json';
      
      final response = await http.post(
        Uri.parse('$baseUrl/donations'),
        headers: headers,
        body: jsonEncode({
          'recipient_user_id': recipientUserId,
          'amount': amount,
          'currency': currency,
          'payment_method': paymentMethod,
        }),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        final errorBody = response.body;
        try {
          final error = json.decode(errorBody);
          throw Exception(error['detail'] ?? 'Donation failed');
        } catch (_) {
          throw Exception('Donation failed: ${response.statusCode} - $errorBody');
        }
      }
    } catch (e) {
      throw Exception('Donation error: $e');
    }
  }
}

