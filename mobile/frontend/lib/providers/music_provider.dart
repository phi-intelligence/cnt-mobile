import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/content_item.dart';
import '../models/api_models.dart';

class MusicProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  
  List<ContentItem> _tracks = [];
  List<ContentItem> _featuredTracks = [];
  bool _isLoading = false;
  String? _error;
  String? _selectedGenre;
  String? _selectedArtist;
  
  List<ContentItem> get tracks => _tracks;
  List<ContentItem> get featuredTracks => _featuredTracks;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get selectedGenre => _selectedGenre;
  String? get selectedArtist => _selectedArtist;
  
  Future<void> fetchTracks({String? genre, String? artist}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Fetch music tracks from API
      final tracksData = await _api.getMusicTracks(genre: genre, artist: artist);
      
      // Convert MusicTrack models to ContentItem models
      _tracks = tracksData.map((track) {
        return ContentItem(
          id: track.id.toString(),
          title: track.title,
          creator: track.artist,
          description: track.album,
          coverImage: track.coverImage != null 
            ? _api.getMediaUrl(track.coverImage!) 
            : null,
          audioUrl: _api.getMediaUrl(track.audioUrl),
          duration: track.duration != null 
            ? Duration(seconds: track.duration!)
            : null,
          category: track.genre ?? 'Music',
          plays: track.playsCount,
          createdAt: track.createdAt,
        );
      }).toList();
      
      // Get featured tracks
      _featuredTracks = _tracks.where((track) => tracksData
        .firstWhere((t) => t.id.toString() == track.id)
        .isFeatured)
        .take(5)
        .toList();
      
      // If no featured tracks, take top 5 by plays
      if (_featuredTracks.isEmpty) {
        _featuredTracks = List.from(_tracks);
        _featuredTracks.sort((a, b) => b.plays.compareTo(a.plays));
        _featuredTracks = _featuredTracks.take(5).toList();
      }
      
      _error = null;
      print('✅ Loaded ${_tracks.length} music tracks from API');
    } catch (e) {
      _error = 'Failed to load music: $e';
      print('❌ Error fetching tracks: $e');
      _addMockData();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  void filterByGenre(String? genre) {
    _selectedGenre = genre;
    fetchTracks(genre: genre, artist: _selectedArtist);
  }
  
  void filterByArtist(String? artist) {
    _selectedArtist = artist;
    fetchTracks(genre: _selectedGenre, artist: artist);
  }
  
  Future<ContentItem?> getTrackById(int id) async {
    try {
      final track = await _api.getMusicTrack(id);
      return ContentItem(
        id: track.id.toString(),
        title: track.title,
        creator: track.artist,
        description: track.album,
        coverImage: track.coverImage != null 
          ? _api.getMediaUrl(track.coverImage!) 
          : null,
        audioUrl: _api.getMediaUrl(track.audioUrl),
        duration: track.duration != null 
          ? Duration(seconds: track.duration!)
          : null,
        category: track.genre ?? 'Music',
        plays: track.playsCount,
        createdAt: track.createdAt,
      );
    } catch (e) {
      print('Error fetching track: $e');
      return null;
    }
  }
  
  void _addMockData() {
    _tracks = [
      ContentItem(
        id: 'm1',
        title: 'Amazing Grace',
        creator: 'Worship Team',
        coverImage: 'https://via.placeholder.com/300',
        audioUrl: 'https://example.com/music1.mp3',
        duration: Duration(minutes: 4, seconds: 30),
        category: 'worship',
        plays: 5432,
        likes: 234,
        createdAt: DateTime.now().subtract(Duration(hours: 12)),
      ),
      ContentItem(
        id: 'm2',
        title: 'Great Is Thy Faithfulness',
        creator: 'Choir',
        coverImage: 'https://via.placeholder.com/300',
        audioUrl: 'https://example.com/music2.mp3',
        duration: Duration(minutes: 5, seconds: 15),
        category: 'hymn',
        plays: 4321,
        likes: 189,
        createdAt: DateTime.now().subtract(Duration(days: 1)),
      ),
      ContentItem(
        id: 'm3',
        title: 'How Great Thou Art',
        creator: 'Worship Band',
        coverImage: 'https://via.placeholder.com/300',
        audioUrl: 'https://example.com/music3.mp3',
        duration: Duration(minutes: 6),
        category: 'worship',
        plays: 6789,
        likes: 312,
        createdAt: DateTime.now().subtract(Duration(hours: 6)),
      ),
    ];
    _featuredTracks = _tracks;
  }
}
