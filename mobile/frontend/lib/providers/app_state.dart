import 'package:flutter/foundation.dart';

class AppState extends ChangeNotifier {
  // User state
  String? currentUserId;
  
  // Player state
  bool isPlayingAudio = false;
  bool isPlayingVideo = false;
  String? currentMediaId;
  
  // Navigation state
  int currentTabIndex = 0;
  
  // Note: Dark mode removed - app uses light theme only
  
  void setCurrentTab(int index) {
    currentTabIndex = index;
    notifyListeners();
  }
  
  void updatePlayerState(bool playing) {
    isPlayingAudio = playing;
    notifyListeners();
  }
}

