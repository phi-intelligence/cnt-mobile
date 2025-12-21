import '../services/api_service.dart';

String? resolveMediaUrl(String? path) {
  if (path == null || path.isEmpty) return null;
  return ApiService().getMediaUrl(path);
}

