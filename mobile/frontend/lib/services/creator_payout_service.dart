import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/environment.dart';
import '../models/creator_payout.dart';
import '../services/auth_service.dart';
import '../services/subscription_exceptions.dart';
import '../utils/app_logger.dart';
import '../utils/pinned_http_client.dart';
import '../utils/subscription_http_helper.dart';

class CreatorPayoutServiceException implements Exception {
  final String message;

  const CreatorPayoutServiceException(this.message);

  @override
  String toString() => message;
}

/// Service for Paystack creator payout onboarding (donations v2).
class CreatorPayoutService {
  static final _httpClient = PinnedHttpClient.instance;
  final AuthService _authService = AuthService();

  static String get baseUrl => Environment.apiBaseUrl;

  Future<List<CreatorPayoutBank>> listBanks() async {
    try {
      final headers = await _authService.getAuthHeaders();
      final response = await _httpClient
          .get(
            Uri.parse('$baseUrl/creator-payout/banks'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 402) {
        SubscriptionHttpHelper.throwIfSubscriptionRequired(response);
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final banks = data['banks'];
        if (banks is List) {
          return banks
              .map((item) =>
                  CreatorPayoutBank.fromJson(item as Map<String, dynamic>))
              .where((bank) =>
                  bank.id > 0 && bank.code.isNotEmpty && bank.name.isNotEmpty)
              .toList();
        }
        return [];
      }

      throw CreatorPayoutServiceException(_parseErrorMessage(response));
    } on SubscriptionRequiredException {
      rethrow;
    } catch (e) {
      if (e is CreatorPayoutServiceException) rethrow;
      AppLogger.error('Error listing payout banks', error: e);
      throw const CreatorPayoutServiceException('Failed to load banks');
    }
  }

  Future<CreatorPayoutStatus> getMe() async {
    try {
      final headers = await _authService.getAuthHeaders();
      final response = await _httpClient
          .get(
            Uri.parse('$baseUrl/creator-payout/me'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 402) {
        SubscriptionHttpHelper.throwIfSubscriptionRequired(response);
      }

      if (response.statusCode == 200) {
        return CreatorPayoutStatus.fromJson(
          json.decode(response.body) as Map<String, dynamic>,
        );
      }

      throw CreatorPayoutServiceException(_parseErrorMessage(response));
    } on SubscriptionRequiredException {
      rethrow;
    } catch (e) {
      if (e is CreatorPayoutServiceException) rethrow;
      AppLogger.error('Error fetching payout status', error: e);
      throw const CreatorPayoutServiceException('Failed to load payout status');
    }
  }

  Future<CreatorPayoutStatus> onboard(CreatorPayoutOnboardRequest payload) async {
    try {
      final headers = await _authService.getAuthHeaders();
      headers['Content-Type'] = 'application/json';

      final response = await _httpClient
          .post(
            Uri.parse('$baseUrl/creator-payout/onboard'),
            headers: headers,
            body: jsonEncode(payload.toJson()),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 402) {
        SubscriptionHttpHelper.throwIfSubscriptionRequired(response);
      }

      if (response.statusCode == 200) {
        return CreatorPayoutStatus.fromJson(
          json.decode(response.body) as Map<String, dynamic>,
        );
      }

      throw CreatorPayoutServiceException(_parseErrorMessage(response));
    } on SubscriptionRequiredException {
      rethrow;
    } catch (e) {
      if (e is CreatorPayoutServiceException) rethrow;
      AppLogger.error('Error onboarding creator payout', error: e);
      throw const CreatorPayoutServiceException('Failed to set up payouts');
    }
  }

  Future<CreatorPayoutStatus> update(CreatorPayoutOnboardRequest payload) async {
    try {
      final headers = await _authService.getAuthHeaders();
      headers['Content-Type'] = 'application/json';

      final response = await _httpClient
          .put(
            Uri.parse('$baseUrl/creator-payout/me'),
            headers: headers,
            body: jsonEncode(payload.toJson()),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 402) {
        SubscriptionHttpHelper.throwIfSubscriptionRequired(response);
      }

      if (response.statusCode == 200) {
        return CreatorPayoutStatus.fromJson(
          json.decode(response.body) as Map<String, dynamic>,
        );
      }

      throw CreatorPayoutServiceException(_parseErrorMessage(response));
    } on SubscriptionRequiredException {
      rethrow;
    } catch (e) {
      if (e is CreatorPayoutServiceException) rethrow;
      AppLogger.error('Error updating creator payout', error: e);
      throw const CreatorPayoutServiceException(
        'Failed to update payout settings',
      );
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
      // Fall through.
    }
    return 'Request failed (${response.statusCode})';
  }
}
