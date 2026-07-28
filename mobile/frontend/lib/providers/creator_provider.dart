import 'package:flutter/material.dart';

import '../models/creator_payout.dart';
import '../screens/bank_details_screen.dart';
import '../services/creator_payout_service.dart';
import '../services/subscription_exceptions.dart';
import '../utils/app_logger.dart';

/// Tracks whether the signed-in user may create/post content.
///
/// Creator-ready = Paystack payout onboarded (`acceptsDonations && payoutsEnabled`).
/// Admins are always treated as ready.
class CreatorProvider extends ChangeNotifier {
  final CreatorPayoutService _payoutService = CreatorPayoutService();

  CreatorPayoutStatus? _status;
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _error;
  bool _isAdmin = false;
  bool _isAuthenticated = false;

  CreatorPayoutStatus? get status => _status;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get error => _error;

  /// True when the user can open Create / post flows.
  bool get isCreatorReady {
    if (!_isAuthenticated) return false;
    if (_isAdmin) return true;
    return _status?.acceptsDonations == true && _status?.payoutsEnabled == true;
  }

  void syncAuth({required bool isAuthenticated, required bool isAdmin}) {
    final authChanged =
        _isAuthenticated != isAuthenticated || _isAdmin != isAdmin;
    _isAuthenticated = isAuthenticated;
    _isAdmin = isAdmin;

    if (!isAuthenticated) {
      clear();
      return;
    }

    if (authChanged || !_hasLoaded) {
      refresh();
    }
  }

  void clear() {
    _status = null;
    _isLoading = false;
    _hasLoaded = false;
    _error = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    if (!_isAuthenticated) {
      clear();
      return;
    }

    if (_isAdmin) {
      _status = null;
      _isLoading = false;
      _hasLoaded = true;
      _error = null;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _status = await _payoutService.getMe();
      _error = null;
    } on SubscriptionRequiredException {
      _status = null;
      _error = null;
    } catch (e) {
      AppLogger.error('Error refreshing creator payout status', error: e);
      _error = e.toString();
      _status = null;
    } finally {
      _isLoading = false;
      _hasLoaded = true;
      notifyListeners();
    }
  }

  Future<void> openPayoutSetup(
    BuildContext context, {
    bool fromCreator = true,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BankDetailsScreen(isFromCreator: fromCreator),
      ),
    );
    if (context.mounted) {
      await refresh();
    }
  }

  /// Returns true if create/post is allowed. Otherwise shows dialog + payout.
  Future<bool> ensureReadyOrRedirect(BuildContext context) async {
    if (_isAdmin) return true;

    if (!_hasLoaded || _isLoading) {
      await refresh();
    }

    if (isCreatorReady) return true;

    if (!context.mounted) return false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Become a Creator'),
        content: const Text(
          'Set up Paystack payouts (bank or mobile money) before you can create or post content.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              openPayoutSetup(context, fromCreator: true);
            },
            child: const Text('Set Up Payouts'),
          ),
        ],
      ),
    );

    return false;
  }
}
