import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/environment.dart';
import '../models/donation.dart';
import '../services/auth_service.dart';
import '../services/subscription_exceptions.dart';
import '../utils/app_logger.dart';
import '../utils/pinned_http_client.dart';
import '../utils/subscription_http_helper.dart';

class DonationServiceException implements Exception {
  final String message;

  const DonationServiceException(this.message);

  @override
  String toString() => message;
}

/// Service for Paystack donations (v2).
class DonationService {
  static final _httpClient = PinnedHttpClient.instance;
  final AuthService _authService = AuthService();

  static String get baseUrl => Environment.apiBaseUrl;

  static const String pendingReferenceKey = 'paystack_donation_reference';

  Future<DonationInitializeResult> initialize({
    required int amountPesewas,
    int? recipientUserId,
    String? contentType,
    int? contentId,
  }) async {
    try {
      final headers = await _authService.getAuthHeaders();
      headers['Content-Type'] = 'application/json';

      final body = <String, dynamic>{
        'amount_pesewas': amountPesewas,
      };

      if (recipientUserId != null) {
        body['recipient_user_id'] = recipientUserId;
      } else if (contentType != null && contentId != null) {
        body['content_type'] = contentType;
        body['content_id'] = contentId;
      }

      final response = await _httpClient
          .post(
            Uri.parse('$baseUrl/donations/initialize'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 402) {
        SubscriptionHttpHelper.throwIfSubscriptionRequired(response);
      }

      if (response.statusCode == 200) {
        return DonationInitializeResult.fromJson(
          json.decode(response.body) as Map<String, dynamic>,
        );
      }

      throw DonationServiceException(_parseErrorMessage(response));
    } on SubscriptionRequiredException {
      rethrow;
    } catch (e) {
      if (e is DonationServiceException) rethrow;
      AppLogger.error('Error initializing donation', error: e);
      throw const DonationServiceException('Failed to start donation checkout');
    }
  }

  Future<DonationVerifyResult> verify(String reference) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final response = await _httpClient
          .get(
            Uri.parse('$baseUrl/donations/verify/$reference'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 402) {
        SubscriptionHttpHelper.throwIfSubscriptionRequired(response);
      }

      if (response.statusCode == 200) {
        return DonationVerifyResult.fromJson(
          json.decode(response.body) as Map<String, dynamic>,
        );
      }

      throw DonationServiceException(_parseErrorMessage(response));
    } on SubscriptionRequiredException {
      rethrow;
    } catch (e) {
      if (e is DonationServiceException) rethrow;
      AppLogger.error('Error verifying donation', error: e);
      throw const DonationServiceException('Failed to verify donation payment');
    }
  }

  Future<DonationEligibility> eligibilityForUser(int userId) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final response = await _httpClient
          .get(
            Uri.parse('$baseUrl/donations/eligibility/$userId'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 402) {
        SubscriptionHttpHelper.throwIfSubscriptionRequired(response);
      }

      if (response.statusCode == 200) {
        return DonationEligibility.fromJson(
          json.decode(response.body) as Map<String, dynamic>,
        );
      }

      throw DonationServiceException(_parseErrorMessage(response));
    } on SubscriptionRequiredException {
      rethrow;
    } catch (e) {
      if (e is DonationServiceException) rethrow;
      AppLogger.error('Error checking donation eligibility', error: e);
      throw const DonationServiceException(
        'Failed to check donation eligibility',
      );
    }
  }

  Future<DonationEligibility> eligibilityForMedia({
    required String contentType,
    required int contentId,
  }) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final response = await _httpClient
          .get(
            Uri.parse(
              '$baseUrl/donations/media/$contentType/$contentId/eligibility',
            ),
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 402) {
        SubscriptionHttpHelper.throwIfSubscriptionRequired(response);
      }

      if (response.statusCode == 200) {
        return DonationEligibility.fromJson(
          json.decode(response.body) as Map<String, dynamic>,
        );
      }

      throw DonationServiceException(_parseErrorMessage(response));
    } on SubscriptionRequiredException {
      rethrow;
    } catch (e) {
      if (e is DonationServiceException) rethrow;
      AppLogger.error('Error checking media donation eligibility', error: e);
      throw const DonationServiceException(
        'Failed to check donation eligibility',
      );
    }
  }

  Future<DonationHistoryPage> listReceived({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final uri = Uri.parse('$baseUrl/donations/received').replace(
        queryParameters: {
          'limit': '$limit',
          'offset': '$offset',
        },
      );
      final response = await _httpClient
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 402) {
        SubscriptionHttpHelper.throwIfSubscriptionRequired(response);
      }

      if (response.statusCode == 200) {
        return DonationHistoryPage.fromJson(
          json.decode(response.body) as Map<String, dynamic>,
        );
      }

      throw DonationServiceException(_parseErrorMessage(response));
    } on SubscriptionRequiredException {
      rethrow;
    } catch (e) {
      if (e is DonationServiceException) rethrow;
      AppLogger.error('Error loading received donations', error: e);
      throw const DonationServiceException('Failed to load received donations');
    }
  }

  Future<DonationHistoryPage> listSent({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final uri = Uri.parse('$baseUrl/donations/sent').replace(
        queryParameters: {
          'limit': '$limit',
          'offset': '$offset',
        },
      );
      final response = await _httpClient
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 402) {
        SubscriptionHttpHelper.throwIfSubscriptionRequired(response);
      }

      if (response.statusCode == 200) {
        return DonationHistoryPage.fromJson(
          json.decode(response.body) as Map<String, dynamic>,
        );
      }

      throw DonationServiceException(_parseErrorMessage(response));
    } on SubscriptionRequiredException {
      rethrow;
    } catch (e) {
      if (e is DonationServiceException) rethrow;
      AppLogger.error('Error loading sent donations', error: e);
      throw const DonationServiceException('Failed to load sent donations');
    }
  }

  Future<DonationHistoryPage> listAllAdmin({
    int limit = 50,
    int offset = 0,
    String? statusFilter,
  }) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final queryParameters = <String, String>{
        'limit': '$limit',
        'offset': '$offset',
      };
      if (statusFilter != null && statusFilter.isNotEmpty) {
        queryParameters['status_filter'] = statusFilter;
      }

      final uri = Uri.parse('$baseUrl/donations/admin/all').replace(
        queryParameters: queryParameters,
      );
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return DonationHistoryPage.fromJson(
          json.decode(response.body) as Map<String, dynamic>,
        );
      }

      throw DonationServiceException(_parseErrorMessage(response));
    } catch (e) {
      if (e is DonationServiceException) rethrow;
      AppLogger.error('Error loading admin donations', error: e);
      throw const DonationServiceException('Failed to load donations');
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
