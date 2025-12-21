import 'package:flutter/foundation.dart';

import '../models/support_message.dart';
import '../services/api_service.dart';

class SupportProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  final List<SupportMessage> _myMessages = [];
  final List<SupportMessage> _adminMessages = [];

  SupportStats? _stats;
  bool _isLoading = false;
  bool _isAdminLoading = false;
  String? _error;

  List<SupportMessage> get myMessages => List.unmodifiable(_myMessages);
  List<SupportMessage> get adminMessages => List.unmodifiable(_adminMessages);
  SupportStats? get stats => _stats;
  bool get isLoading => _isLoading;
  bool get isAdminLoading => _isAdminLoading;
  String? get error => _error;
  int get unreadAdminCount => _stats?.unreadAdminCount ?? 0;
  int get unreadUserCount => _stats?.unreadUserCount ?? 0;

  Future<void> fetchMyMessages() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final messages = await _api.getMySupportMessages();
      _myMessages
        ..clear()
        ..addAll(messages);
    } catch (e) {
      _error = 'Failed to load support messages: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> submitMessage({
    required String subject,
    required String message,
  }) async {
    try {
      final created = await _api.createSupportMessage(
        subject: subject,
        message: message,
      );
      _myMessages.insert(0, created);
      await fetchStats();
    } catch (e) {
      _error = 'Failed to send message: $e';
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> fetchAdminMessages({String? status}) async {
    _isAdminLoading = true;
    _error = null;
    notifyListeners();

    try {
      final messages = await _api.getSupportMessagesForAdmin(status: status);
      _adminMessages
        ..clear()
        ..addAll(messages);
    } catch (e) {
      _error = 'Failed to load admin support messages: $e';
    } finally {
      _isAdminLoading = false;
      notifyListeners();
    }
  }

  Future<void> replyToMessage({
    required int messageId,
    required String response,
    String status = 'responded',
  }) async {
    try {
      final updated = await _api.replyToSupportMessage(
        messageId: messageId,
        responseText: response,
        status: status,
      );

      final index = _adminMessages.indexWhere((msg) => msg.id == messageId);
      if (index != -1) {
        _adminMessages[index] = updated;
      }
      await fetchStats();
    } catch (e) {
      _error = 'Failed to reply: $e';
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> markMessageAsRead({
    required int messageId,
    required bool forAdmin,
  }) async {
    try {
      final updated = await _api.markSupportMessageRead(
        messageId: messageId,
        actor: forAdmin ? 'admin' : 'user',
      );

      if (forAdmin) {
        final index = _adminMessages.indexWhere((m) => m.id == messageId);
        if (index != -1) {
          _adminMessages[index] = updated;
        }
      } else {
        final index = _myMessages.indexWhere((m) => m.id == messageId);
        if (index != -1) {
          _myMessages[index] = updated;
        }
      }

      await fetchStats();
    } catch (e) {
      _error = 'Failed to update message state: $e';
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> fetchStats() async {
    try {
      _stats = await _api.getSupportStats();
    } catch (e) {
      _error = 'Failed to load support stats: $e';
    } finally {
      notifyListeners();
    }
  }
}

