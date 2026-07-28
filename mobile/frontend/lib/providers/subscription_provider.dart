import 'package:flutter/foundation.dart';

import '../models/subscription.dart';
import '../services/subscription_service.dart';
import '../services/token_storage_service.dart';
import '../utils/app_logger.dart';

class SubscriptionProvider extends ChangeNotifier {
  final SubscriptionService _service = SubscriptionService();
  static final _storage = TokenStorageService.instance;

  SubscriptionMe? _me;
  List<SubscriptionPlan> _plans = [];
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

  SubscriptionMe? get me => _me;
  List<SubscriptionPlan> get plans => List.unmodifiable(_plans);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isInitialized => _isInitialized;

  bool get isEntitled => _me?.entitled ?? false;
  bool get enforcementEnabled => _me?.enforcementEnabled ?? false;
  bool get needsSubscription => _me?.needsSubscription ?? false;

  Future<void> refreshMe() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _me = await _service.getMe();
      _error = null;
    } catch (e) {
      _error = e.toString();
      AppLogger.error('SubscriptionProvider.refreshMe failed', error: e);
    } finally {
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> loadPlans() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _plans = await _service.listPlans();
      _error = null;
    } catch (e) {
      _error = e.toString();
      AppLogger.error('SubscriptionProvider.loadPlans failed', error: e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> startCheckout({
    required bool acceptTerms,
    required bool acceptPrivacy,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _service.initialize(
        acceptTerms: acceptTerms,
        acceptPrivacy: acceptPrivacy,
      );

      if (result.reference.isNotEmpty) {
        await _storage.write(
          key: SubscriptionService.pendingReferenceKey,
          value: result.reference,
        );
      }

      _error = null;
      return result.authorizationUrl;
    } catch (e) {
      _error = e.toString();
      AppLogger.error('SubscriptionProvider.startCheckout failed', error: e);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> completeCheckout(String? reference) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      var resolvedReference = reference;
      if (resolvedReference == null || resolvedReference.isEmpty) {
        resolvedReference = await _storage.read(
          key: SubscriptionService.pendingReferenceKey,
        );
      }

      if (resolvedReference == null || resolvedReference.isEmpty) {
        throw const SubscriptionServiceException(
          'Missing payment reference from Paystack callback',
        );
      }

      final result = await _service.verify(resolvedReference);
      await _storage.delete(key: SubscriptionService.pendingReferenceKey);
      await refreshMe();

      if (result.status == 'success' || result.entitled) {
        _error = null;
        return true;
      }

      _error = 'Payment was not completed successfully';
      return false;
    } catch (e) {
      _error = e.toString();
      AppLogger.error('SubscriptionProvider.completeCheckout failed', error: e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> cancelSubscription() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _service.cancel();
      await refreshMe();
      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      AppLogger.error(
        'SubscriptionProvider.cancelSubscription failed',
        error: e,
      );
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _me = null;
    _plans = [];
    _error = null;
    _isInitialized = false;
    _isLoading = false;
    _storage.delete(key: SubscriptionService.pendingReferenceKey);
    notifyListeners();
  }
}
