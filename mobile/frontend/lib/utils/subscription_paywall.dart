/// Global hook for redirecting users to the subscribe flow on HTTP 402.
class SubscriptionPaywall {
  static void Function(String message)? onRequired;

  static void notifyRequired([
    String message =
        'An active subscription is required to access this feature.',
  ]) {
    onRequired?.call(message);
  }

  static void clear() {
    onRequired = null;
  }
}
