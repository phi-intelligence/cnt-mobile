import 'dart:convert';

import 'package:http/http.dart' as http;

import '../services/subscription_exceptions.dart';
import 'subscription_paywall.dart';

/// Shared HTTP 402 handling for services that do not use [ApiService].
class SubscriptionHttpHelper {
  static const String defaultMessage =
      'An active subscription is required to access this feature.';

  static Never throwIfSubscriptionRequired(http.Response response) {
    if (response.statusCode != 402) {
      throw StateError('Expected HTTP 402, got ${response.statusCode}');
    }
    final message = parse402Message(response.body);
    SubscriptionPaywall.notifyRequired(message);
    throw SubscriptionRequiredException(message);
  }

  static String parse402Message(String body) {
    var message = defaultMessage;

    try {
      final decoded = json.decode(body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail is String && detail.isNotEmpty) {
          message = detail;
        } else if (detail is Map<String, dynamic>) {
          final detailMessage = detail['message'] as String?;
          if (detailMessage != null && detailMessage.isNotEmpty) {
            message = detailMessage;
          }
        }
      }
    } catch (_) {
      // Keep default message.
    }

    return message;
  }
}
