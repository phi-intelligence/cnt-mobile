import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../models/document_asset.dart';
import '../services/api_service.dart';

class DocumentsProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<DocumentAsset> _documents = [];
  bool _isLoading = false;
  String? _error;

  List<DocumentAsset> get documents => List.unmodifiable(_documents);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchDocuments({String? category}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _documents = await _api.getDocuments(category: category);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<DocumentAsset?> addDocument({
    required String title,
    String? description,
    required String fileName,
    Uint8List? bytes,
    String? filePath,
    String category = 'Bible',
    bool isFeatured = false,
  }) async {
    try {
      final uploadUrl = await _api.uploadDocumentFile(
        fileName: fileName,
        bytes: bytes,
        filePath: filePath,
      );

      if (uploadUrl.isEmpty) {
        throw Exception('Upload failed');
      }

      final document = await _api.createDocument(
        title: title,
        description: description,
        filePath: uploadUrl,
        category: category,
        isFeatured: isFeatured,
      );

      _documents.insert(0, document);
      notifyListeners();
      return document;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteDocument(int documentId) async {
    try {
      await _api.deleteDocument(documentId);
      _documents.removeWhere((doc) => doc.id == documentId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }
}

