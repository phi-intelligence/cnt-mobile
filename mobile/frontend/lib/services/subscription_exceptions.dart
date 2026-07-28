/// Thrown when the backend returns HTTP 402 (subscription required).
class SubscriptionRequiredException implements Exception {
  final String message;

  const SubscriptionRequiredException([
    this.message = 'An active subscription is required to access this feature.',
  ]);

  @override
  String toString() => message;
}
