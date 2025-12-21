// Stub file for web platform - File operations are not available on web
// This file is only used when compiling for web to avoid import errors

/// Stub File class for web platform
class File {
  final String path;
  File(this.path);
  Future<bool> exists() async => false;
  Future<int> length() async => 0;
  Future<File> writeAsBytes(List<int> bytes, {int mode = 0}) async {
    // Stub implementation - should never be called on web
    // This method exists only to satisfy the type checker
    // The mode parameter is ignored (0 = write mode)
    throw UnsupportedError('File.writeAsBytes is not supported on web platform');
  }
}


