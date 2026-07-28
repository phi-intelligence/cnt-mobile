import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/environment.dart';
import '../models/subscription.dart';
import '../utils/app_logger.dart';
import '../utils/pinned_http_client.dart';
import 'auth_service.dart';

class SubscriptionServiceException implements Exception {
  final String message;

  const SubscriptionServiceException(this.message);

  @override
  String toString() => message;
}

/// Service for Paystack platform subscriptions (payment v1).
class SubscriptionService {
  static final _httpClient = PinnedHttpClient.instance;
  final AuthService _authService = AuthService();

  static String get baseUrl => Environment.apiBaseUrl;

  static const String pendingReferenceKey = 'paystack_subscription_reference';

  Future<List<SubscriptionPlan>> listPlans() async {
    try {
      final headers = await _authService.getAuthHeaders();
      final response = await _httpClient
          .get(
            Uri.parse('$baseUrl/subscriptions/plans'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          return data
              .map((item) =>
                  SubscriptionPlan.fromJson(item as Map<String, dynamic>))
              .toList();
        }
        return [];
      }

      throw SubscriptionServiceException(_parseErrorMessage(response));
    } catch (e) {
      if (e is SubscriptionServiceException) rethrow;
      AppLogger.error('Error listing subscription plans', error: e);
      throw const SubscriptionServiceException(
        'Failed to load subscription plans',
      );
    }
  }

  Future<SubscriptionMe> getMe() async {
    try {
      final headers = await _authService.getAuthHeaders();
      final response = await _httpClient
          .get(
            Uri.parse('$baseUrl/subscriptions/me'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return SubscriptionMe.fromJson(
          json.decode(response.body) as Map<String, dynamic>,
        );
      }

      throw SubscriptionServiceException(_parseErrorMessage(response));
    } catch (e) {
      if (e is SubscriptionServiceException) rethrow;
      AppLogger.error('Error fetching subscription status', error: e);
      throw const SubscriptionServiceException(
        'Failed to load subscription status',
      );
    }
  }

  Future<SubscriptionInitializeResult> initialize({
    required bool acceptTerms,
    required bool acceptPrivacy,
  }) async {
    try {
      final headers = await _authService.getAuthHeaders();
      headers['Content-Type'] = 'application/json';

      final response = await _httpClient
          .post(
            Uri.parse('$baseUrl/subscriptions/initialize'),
            headers: headers,
            body: jsonEncode({
              'accept_terms': acceptTerms,
              'accept_privacy': acceptPrivacy,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return SubscriptionInitializeResult.fromJson(
          json.decode(response.body) as Map<String, dynamic>,
        );
      }

      throw SubscriptionServiceException(_parseErrorMessage(response));
    } catch (e) {
      if (e is SubscriptionServiceException) rethrow;
      AppLogger.error('Error initializing subscription checkout', error: e);
      throw const SubscriptionServiceException(
        'Failed to start subscription checkout',
      );
    }
  }

  Future<SubscriptionVerifyResult> verify(String reference) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final response = await _httpClient
          .get(
            Uri.parse('$baseUrl/subscriptions/verify/$reference'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return SubscriptionVerifyResult.fromJson(
          json.decode(response.body) as Map<String, dynamic>,
        );
      }

      throw SubscriptionServiceException(_parseErrorMessage(response));
    } catch (e) {
      if (e is SubscriptionServiceException) rethrow;
      AppLogger.error('Error verifying subscription payment', error: e);
      throw const SubscriptionServiceException(
        'Failed to verify subscription payment',
      );
    }
  }

  Future<SubscriptionCancelResult> cancel() async {
    try {
      final headers = await _authService.getAuthHeaders();
      headers['Content-Type'] = 'application/json';

      final response = await _httpClient
          .post(
            Uri.parse('$baseUrl/subscriptions/cancel'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return SubscriptionCancelResult.fromJson(
          json.decode(response.body) as Map<String, dynamic>,
        );
      }

      throw SubscriptionServiceException(_parseErrorMessage(response));
    } catch (e) {
      if (e is SubscriptionServiceException) rethrow;
      AppLogger.error('Error canceling subscription', error: e);
      throw const SubscriptionServiceException('Failed to cancel subscription');
    }
  }

  String _parseErrorMessage(http.Response response) {
    final body = response.body;
    try {
      final decoded = json.decode(body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail is String && detail.isNotEmpty) {
          return detail;
        }
        if (detail is Map<String, dynamic>) {
          final message = detail['message'] as String?;
          if (message != null && message.isNotEmpty) {
            return message;
          }
        }
      }
    } catch (_) {
      // Fall through to generic message.
    }
    return 'Request failed (${response.statusCode})';
  }
}
