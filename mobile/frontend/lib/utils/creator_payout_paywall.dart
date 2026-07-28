/// Global hook for redirecting users to Paystack payout setup on
/// HTTP 403 `creator_payout_required`.
class CreatorPayoutPaywall {
  static void Function(String message)? onRequired;

  static void notifyRequired([
    String message =
        'Set up Paystack payouts before creating or posting content.',
  ]) {
    onRequired?.call(message);
  }

  static void clear() {
    onRequired = null;
  }
}

class CreatorPayoutRequiredException implements Exception {
  final String message;

  const CreatorPayoutRequiredException([
    this.message =
        'Set up Paystack payouts before creating or posting content.',
  ]);

  @override
  String toString() => message;
}
