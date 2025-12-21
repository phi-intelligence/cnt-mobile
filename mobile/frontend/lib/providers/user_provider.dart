import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class UserProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _stats;
  bool _isLoading = false;
  String? _error;
  
  Map<String, dynamic>? get user => _user;
  Map<String, dynamic>? get stats => _stats;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  Future<void> fetchUser() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      _user = await _api.getCurrentUser();
      _stats = await _api.getUserStats();
      _error = null;
    } catch (e) {
      _error = 'Failed to load user: $e';
      print('Error fetching user: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  void clearUser() {
    _user = null;
    _stats = null;
    notifyListeners();
  }
  
  Future<bool> updateProfile(Map<String, dynamic> profileData) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final updatedUser = await _api.updateProfile(profileData);
      if (updatedUser != null) {
        _user = updatedUser;
        _error = null;
        return true;
      }
      _error = 'Failed to update profile';
      return false;
    } catch (e) {
      _error = 'Error updating profile: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<Map<String, dynamic>?> getBankDetails() async {
    try {
      return await _api.getBankDetails();
    } catch (e) {
      _error = 'Error getting bank details: $e';
      return null;
    }
  }
  
  Future<bool> updateBankDetails(Map<String, dynamic> bankData) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final success = await _api.updateBankDetails(bankData);
      _error = success ? null : 'Failed to update bank details';
      return success;
    } catch (e) {
      _error = 'Error updating bank details: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<Map<String, dynamic>> checkUsernameAvailability(String username) async {
    try {
      return await _api.checkUsernameAvailability(username);
    } catch (e) {
      return {'available': false, 'error': e.toString()};
    }
  }

  Future<String?> uploadAvatar({
    required String fileName,
    List<int>? bytes,
    String? filePath,
  }) async {
    try {
      final url = await _api.uploadProfileImage(
        fileName: fileName,
        bytes: bytes,
        filePath: filePath,
      );

      if (_user != null) {
        _user = {
          ..._user!,
          'avatar': url,
        };
      } else {
        await fetchUser();
      }
      notifyListeners();
      return url;
    } catch (e) {
      _error = 'Error uploading avatar: $e';
      notifyListeners();
      return null;
    }
  }
}

