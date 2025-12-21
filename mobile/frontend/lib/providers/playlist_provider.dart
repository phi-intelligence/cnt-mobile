import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class PlaylistProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  
  List<dynamic> _playlists = [];
  bool _isLoading = false;
  String? _error;
  
  List<dynamic> get playlists => _playlists;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  Future<void> fetchPlaylists() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      _playlists = await _api.getPlaylists();
      _error = null;
    } catch (e) {
      _error = 'Failed to load playlists: $e';
      print('Error fetching playlists: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<bool> createPlaylist({
    required String name,
    String? description,
  }) async {
    try {
      final playlist = await _api.createPlaylist(
        name: name,
        description: description,
      );
      _playlists.insert(0, playlist);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to create playlist: $e';
      notifyListeners();
      return false;
    }
  }
  
  Future<bool> addToPlaylist(int playlistId, String contentType, int contentId) async {
    final success = await _api.addToPlaylist(playlistId, contentType, contentId);
    if (success) {
      // Refresh playlists to get updated item count
      await fetchPlaylists();
    }
    return success;
  }
}

