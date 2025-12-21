import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/content_item.dart';
import '../services/api_service.dart';

/// Playback context determines queue behavior
enum PlaybackContext {
  /// Queue is artist-scoped (next tracks are from same artist)
  artistQueue,
  /// Queue is global/section-scoped (next tracks from any artist in section)
  globalQueue,
}

class AudioPlayerState extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  final ApiService _api = ApiService();
  
  ContentItem? _currentTrack;
  List<ContentItem> _queue = [];
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 1.0;
  String? _currentSection; // Track which section this content came from
  int _currentOffset = 0; // Track pagination offset for fetching more tracks
  
  // Artist-scoped queue support
  PlaybackContext _playbackContext = PlaybackContext.globalQueue;
  int? _currentArtistId; // Creator/user ID for artist-scoped queue
  int _artistOffset = 0; // Pagination offset for artist tracks
  bool _artistTracksExhausted = false; // Flag when no more artist tracks available

  ContentItem? get currentTrack => _currentTrack;
  List<ContentItem> get queue => _queue;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  Duration get position => _position;
  Duration get duration => _duration;
  double get volume => _volume;
  String? get currentSection => _currentSection;

  AudioPlayerState() {
    _initPlayer();
  }

  void _initPlayer() {
    _player.positionStream.listen((position) {
      _position = position;
      notifyListeners();
    });

    _player.durationStream.listen((duration) {
      _duration = duration ?? Duration.zero;
      notifyListeners();
    });

    _player.playingStream.listen((playing) {
      _isPlaying = playing;
      notifyListeners();
    });

    // Listen for when playback completes - auto-play next track
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _playNextTrack();
      }
    });

    // Note: loadingStateStream may not be available in this just_audio version
    // _player.loadingStateStream.listen((loadingState) {
    //   _isLoading = loadingState == LoadingState.loading || loadingState == LoadingState.buffering;
    //   notifyListeners();
    // });
  }

  Future<void> loadTrack(ContentItem track) async {
    if (track.audioUrl == null) {
      print('No audio URL available for track');
      return;
    }
    
    _currentTrack = track;
    try {
      await _player.setUrl(track.audioUrl!);
      await _player.setVolume(_volume);
      notifyListeners();
    } catch (e) {
      print('Error loading track: $e');
    }
  }

  /// Play a ContentItem directly (main entry point from UI)
  Future<void> playContent(ContentItem item) async {
    if (item.audioUrl == null) {
      print('No audio URL available for ${item.title}');
      return;
    }

    _currentTrack = item;
    try {
      print('Loading audio: ${item.audioUrl}');
      await _player.setUrl(item.audioUrl!);
      await _player.setVolume(_volume);
      await play(); // Auto-play
      notifyListeners();
    } catch (e) {
      print('Error playing content: $e');
      _error = 'Failed to play audio: $e';
      notifyListeners();
    }
  }

  /// Play a ContentItem with a playlist queue for auto-play next
  Future<void> playContentWithQueue(
    ContentItem item, 
    List<ContentItem> playlist, {
    String? section,
  }) async {
    if (item.audioUrl == null) {
      print('No audio URL available for ${item.title}');
      return;
    }

    // Set the queue with all items that have audio
    _queue = playlist.where((p) => p.audioUrl != null && p.audioUrl!.isNotEmpty).toList();
    _currentTrack = item;
    _currentSection = section;
    _currentOffset = _queue.length; // Track how many tracks we've already loaded
    _playbackContext = PlaybackContext.globalQueue;
    _currentArtistId = null;
    _artistTracksExhausted = false;
    
    try {
      print('🎵 Playing ${item.title} with queue of ${_queue.length} tracks from section: $section');
      await _player.setUrl(item.audioUrl!);
      await _player.setVolume(_volume);
      await play();
      notifyListeners();
    } catch (e) {
      print('Error playing content: $e');
      _error = 'Failed to play audio: $e';
      notifyListeners();
    }
  }
  
  /// Play a ContentItem with an artist-scoped queue
  /// Next tracks will be from the same artist, then fallback to global
  Future<void> playContentWithArtistQueue(
    ContentItem item, 
    List<ContentItem> artistPlaylist,
  ) async {
    if (item.audioUrl == null) {
      print('No audio URL available for ${item.title}');
      return;
    }

    // Set the queue with artist's tracks that have audio
    _queue = artistPlaylist.where((p) => p.audioUrl != null && p.audioUrl!.isNotEmpty).toList();
    _currentTrack = item;
    _playbackContext = PlaybackContext.artistQueue;
    _currentArtistId = item.creatorId;
    _artistOffset = _queue.length;
    _artistTracksExhausted = false;
    _currentSection = 'Artist'; // Fallback section for global queue
    _currentOffset = 0;
    
    try {
      print('🎵 Playing ${item.title} with ARTIST queue of ${_queue.length} tracks');
      await _player.setUrl(item.audioUrl!);
      await _player.setVolume(_volume);
      await play();
      notifyListeners();
    } catch (e) {
      print('Error playing content: $e');
      _error = 'Failed to play audio: $e';
      notifyListeners();
    }
  }

  String? _error;
  String? get error => _error;

  Future<void> play() async {
    try {
      await _player.play();
      _isPlaying = true;
      notifyListeners();
    } catch (e) {
      print('Error playing: $e');
    }
  }

  Future<void> pause() async {
    await _player.pause();
    _isPlaying = false;
    notifyListeners();
  }

  /// Stop playback and clear current track
  Future<void> stop() async {
    await _player.stop();
    _isPlaying = false;
    _currentTrack = null;
    _position = Duration.zero;
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
    notifyListeners();
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _player.setVolume(_volume);
    notifyListeners();
  }

  // Track the last played track to allow replay
  ContentItem? _lastPlayedTrack;
  ContentItem? get lastPlayedTrack => _lastPlayedTrack;
  bool get hasFinishedPlayback => !_isPlaying && _currentTrack == null && _lastPlayedTrack != null;

  /// Replay the last played track
  Future<void> replayLastTrack() async {
    if (_lastPlayedTrack != null) {
      await playContent(_lastPlayedTrack!);
    }
  }

  /// Auto-play next track when current finishes
  Future<void> _playNextTrack() async {
    // Store the current track before potentially clearing it
    if (_currentTrack != null) {
      _lastPlayedTrack = _currentTrack;
    }
    
    if (_queue.isEmpty || _currentTrack == null) {
      // No queue - keep track reference but stop playing
      _isPlaying = false;
      // Don't clear _currentTrack - let the UI show replay option
      notifyListeners();
      return;
    }
    
    final currentIndex = _queue.indexOf(_currentTrack!);
    
    // If we're near the end of the queue, try to fetch more tracks
    if (currentIndex >= _queue.length - 3) {
      if (_playbackContext == PlaybackContext.artistQueue && !_artistTracksExhausted) {
        await _fetchMoreArtistTracks();
      } else if (_currentSection != null) {
      await _fetchMoreTracksForSection();
      }
    }
    
    if (currentIndex >= 0 && currentIndex < _queue.length - 1) {
      // Play next track in queue
      final nextTrack = _queue[currentIndex + 1];
      print('🎵 Auto-playing next track: ${nextTrack.title}');
      await loadTrack(nextTrack);
      await play();
    } else {
      // End of queue - try fetching more tracks one last time
      if (_playbackContext == PlaybackContext.artistQueue && !_artistTracksExhausted) {
        await _fetchMoreArtistTracks();
        // Check if we got new tracks
        if (currentIndex < _queue.length - 1) {
          final nextTrack = _queue[currentIndex + 1];
          print('🎵 Auto-playing next artist track: ${nextTrack.title}');
          await loadTrack(nextTrack);
          await play();
          return;
        }
        
        // Artist tracks exhausted, fallback to global queue
        print('🎵 Artist tracks exhausted, falling back to global queue');
        _playbackContext = PlaybackContext.globalQueue;
        _artistTracksExhausted = true;
        await _fetchMoreTracksForSection();
        if (currentIndex < _queue.length - 1) {
          final nextTrack = _queue[currentIndex + 1];
          print('🎵 Auto-playing from global fallback: ${nextTrack.title}');
          await loadTrack(nextTrack);
          await play();
          return;
        }
      } else if (_currentSection != null) {
        await _fetchMoreTracksForSection();
        // Check if we got new tracks
        if (currentIndex < _queue.length - 1) {
          final nextTrack = _queue[currentIndex + 1];
          print('🎵 Auto-playing next track from fetched content: ${nextTrack.title}');
          await loadTrack(nextTrack);
          await play();
          return;
        }
      }
      
      // No more tracks available - stop playing but keep track visible for replay
      print('🎵 Queue ended, no more tracks available');
      _isPlaying = false;
      // Don't clear _currentTrack - let the UI show replay option
      notifyListeners();
    }
  }
  
  /// Fetch more tracks from the same artist/creator for artist-scoped queue
  Future<void> _fetchMoreArtistTracks() async {
    if (_currentArtistId == null) {
      _artistTracksExhausted = true;
      return;
    }
    
    try {
      print('🎵 Fetching more tracks from creator ID: $_currentArtistId, skip: $_artistOffset');
      
      // Fetch podcasts by creator ID (user ID of the artist)
      final podcasts = await _api.getPodcastsByCreator(
        _currentArtistId!,
        skip: _artistOffset,
        limit: 20,
      );
      
      // Filter for tracks we don't already have
      final existingIds = _queue.map((t) => t.id).toSet();
      final newTracks = podcasts
          .map((p) => _api.podcastToContentItem(p))
          .where((t) => t.audioUrl != null && t.audioUrl!.isNotEmpty)
          .where((t) => !existingIds.contains(t.id))
          .toList();
      
      if (newTracks.isNotEmpty) {
        _queue.addAll(newTracks);
        _artistOffset += newTracks.length;
        print('🎵 Added ${newTracks.length} artist tracks to queue. Total queue size: ${_queue.length}');
        notifyListeners();
      } else {
        print('🎵 No more tracks available from artist');
        _artistTracksExhausted = true;
      }
    } catch (e) {
      print('🎵 Error fetching artist tracks: $e');
      _artistTracksExhausted = true;
    }
  }

  /// Fetch more tracks from the same section for continuous playback
  Future<void> _fetchMoreTracksForSection() async {
    if (_currentSection == null) return;
    
    try {
      print('🎵 Fetching more tracks from section: $_currentSection, skip: $_currentOffset');
      
      List<ContentItem> newTracks = [];
      
      switch (_currentSection) {
        case 'Audio Podcasts':
          final podcasts = await _api.getPodcasts(
            skip: _currentOffset,
            limit: 10,
            status: 'approved',
            newestFirst: true,
          );
          // Filter for audio podcasts only
          newTracks = podcasts
              .where((p) => p.audioUrl != null && p.audioUrl!.isNotEmpty)
              .map((p) => _api.podcastToContentItem(p))
              .toList();
          break;
        case 'Video Podcasts':
          final podcasts = await _api.getPodcasts(
            skip: _currentOffset,
            limit: 10,
            status: 'approved',
            newestFirst: true,
          );
          // Filter for video podcasts only
          newTracks = podcasts
              .where((p) => p.videoUrl != null && p.videoUrl!.isNotEmpty)
              .map((p) => _api.podcastToContentItem(p))
              .toList();
          break;
        case 'Music':
          // Music tracks are already loaded in memory via MusicProvider
          // For continuous music playback, we would need to implement
          // fetching from the music API endpoint if it exists
          print('🎵 Music continuous fetching not implemented - using existing queue');
          break;
        default:
          print('🎵 Unknown section: $_currentSection');
          return;
      }
      
      // Filter tracks with valid audio URLs
      final validTracks = newTracks.where((t) => t.audioUrl != null && t.audioUrl!.isNotEmpty).toList();
      
      if (validTracks.isNotEmpty) {
        _queue.addAll(validTracks);
        _currentOffset += validTracks.length;
        print('🎵 Added ${validTracks.length} tracks to queue. Total queue size: ${_queue.length}');
        notifyListeners();
      } else {
        print('🎵 No more tracks available in section: $_currentSection');
      }
    } catch (e) {
      print('🎵 Error fetching more tracks: $e');
    }
  }

  Future<void> next() async {
    if (_queue.isEmpty) return;
    
    final currentIndex = _currentTrack != null ? _queue.indexOf(_currentTrack!) : -1;
    if (currentIndex >= 0 && currentIndex < _queue.length - 1) {
      final nextTrack = _queue[currentIndex + 1];
      await loadTrack(nextTrack);
      await play();
    }
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;
    
    final currentIndex = _queue.indexOf(_currentTrack!);
    if (currentIndex > 0) {
      final prevTrack = _queue[currentIndex - 1];
      await loadTrack(prevTrack);
      await play();
    } else {
      // Restart current track
      await seek(Duration.zero);
    }
  }

  void addToQueue(ContentItem track) {
    _queue.add(track);
    notifyListeners();
  }

  void clearQueue() {
    _queue.clear();
    notifyListeners();
  }

  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}

