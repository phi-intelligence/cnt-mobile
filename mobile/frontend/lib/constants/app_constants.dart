/// App-wide constants
class AppConstants {
  AppConstants._();

  // App info
  static const String appName = 'Christ New Tabernacle';
  static const String appVersion = '1.0.0';
  
  // API endpoints (will use platform_utils for actual URLs)
  static const String apiBasePath = '/api/v1';
  static const String podcastsEndpoint = '$apiBasePath/podcasts';
  static const String musicEndpoint = '$apiBasePath/music/tracks';
  static const String playlistsEndpoint = '$apiBasePath/playlists';
  static const String bibleStoriesEndpoint = '$apiBasePath/bible-stories';
  static const String communityEndpoint = '$apiBasePath/community/posts';
  static const String liveStreamsEndpoint = '$apiBasePath/live/streams';
  static const String categoriesEndpoint = '$apiBasePath/categories';
  static const String uploadEndpoint = '$apiBasePath/upload';
  static const String authEndpoint = '$apiBasePath/auth';
  
  // Voice chat room types
  static const String roomTypePrayer = 'prayer';
  static const String roomTypeBibleStudy = 'bible-study';
  static const String roomTypeFellowship = 'fellowship';
  static const String roomTypeSupport = 'support';
  static const String roomTypeGeneral = 'general';
  
  // Content categories
  static const List<String> podcastCategories = [
    'All',
    'Sermons',
    'Teaching',
    'Prayer',
    'Worship',
    'Testimony',
    'Bible Study',
    'Youth',
  ];
  
  static const List<String> musicGenres = [
    'All',
    'Worship',
    'Gospel',
    'Contemporary',
    'Hymns',
    'Choir',
    'Instrumental',
  ];
  
  // Pagination
  static const int itemsPerPage = 20;
  
  // Cache durations
  static const Duration cacheExpiry = Duration(hours: 1);
  
  // Timeouts
  static const Duration requestTimeout = Duration(seconds: 30);
  
  // Asset paths
  static const String assetsImagesPath = 'assets/images/';
  static const String assetsIconsPath = 'assets/icons/';
}

