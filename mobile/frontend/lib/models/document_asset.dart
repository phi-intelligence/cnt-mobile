class DocumentAsset {
  final int id;
  final String title;
  final String? description;
  final String filePath;
  final String? thumbnailPath;
  final String? category;
  final bool isFeatured;
  final DateTime createdAt;

  DocumentAsset({
    required this.id,
    required this.title,
    required this.description,
    required this.filePath,
    required this.thumbnailPath,
    required this.category,
    required this.isFeatured,
    required this.createdAt,
  });

  factory DocumentAsset.fromJson(Map<String, dynamic> json) {
    return DocumentAsset(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      filePath: json['file_path'] as String,
      thumbnailPath: json['thumbnail_path'] as String?,
      category: json['category'] as String?,
      isFeatured: json['is_featured'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

}

