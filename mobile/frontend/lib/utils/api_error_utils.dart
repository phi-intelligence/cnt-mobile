/// Sanitizes API errors before showing to users or logging.
class ApiErrorUtils {
  ApiErrorUtils._();

  static String sanitizeForUser(Object error, {String fallback = 'Something went wrong. Please try again.'}) {
    final message = error.toString();
    if (message.contains('SocketException') ||
        message.contains('TimeoutException') ||
        message.contains('Connection')) {
      return 'Network error. Please check your connection and try again.';
    }
    if (message.contains('401') || message.contains('403')) {
      return 'You do not have permission to perform this action.';
    }
    if (message.contains('404')) {
      return 'The requested resource was not found.';
    }
    if (message.contains('500') || message.contains('502') || message.contains('503')) {
      return 'Server error. Please try again later.';
    }
    // Never expose raw server response bodies to users.
    if (message.contains('HTTP') && message.length > 120) {
      return fallback;
    }
    if (message.startsWith('Exception: ')) {
      final detail = message.substring('Exception: '.length);
      if (detail.length > 120 || detail.contains('{') || detail.contains('detail')) {
        return fallback;
      }
      return detail;
    }
    return message.length > 120 ? fallback : message;
  }

  static String sanitizeForLog(String body, {int maxLength = 200}) {
    if (body.length <= maxLength) return '[response truncated]';
    return '${body.substring(0, maxLength)}... [truncated]';
  }
}
