enum SchoolLibraryResourceType {
  videoFile,
  youtube,
  pdf,
  image,
  link,
  document,
}

extension SchoolLibraryResourceTypeX on SchoolLibraryResourceType {
  String get dbValue {
    switch (this) {
      case SchoolLibraryResourceType.videoFile:
        return 'video_file';
      case SchoolLibraryResourceType.youtube:
        return 'youtube';
      case SchoolLibraryResourceType.pdf:
        return 'pdf';
      case SchoolLibraryResourceType.image:
        return 'image';
      case SchoolLibraryResourceType.link:
        return 'link';
      case SchoolLibraryResourceType.document:
        return 'document';
    }
  }

  String get label {
    switch (this) {
      case SchoolLibraryResourceType.videoFile:
        return 'Video file';
      case SchoolLibraryResourceType.youtube:
        return 'YouTube';
      case SchoolLibraryResourceType.pdf:
        return 'PDF';
      case SchoolLibraryResourceType.image:
        return 'Image';
      case SchoolLibraryResourceType.link:
        return 'Link';
      case SchoolLibraryResourceType.document:
        return 'Document';
    }
  }

  static SchoolLibraryResourceType fromDb(String? value) {
    switch (value) {
      case 'video_file':
        return SchoolLibraryResourceType.videoFile;
      case 'youtube':
        return SchoolLibraryResourceType.youtube;
      case 'pdf':
        return SchoolLibraryResourceType.pdf;
      case 'image':
        return SchoolLibraryResourceType.image;
      case 'link':
        return SchoolLibraryResourceType.link;
      case 'document':
        return SchoolLibraryResourceType.document;
      default:
        return SchoolLibraryResourceType.link;
    }
  }
}

class SchoolLibraryItem {
  final String id;
  final String schoolId;
  final String? createdBy;
  final String title;
  final String? description;
  final SchoolLibraryResourceType resourceType;
  final String? storagePath;
  final String? externalUrl;
  final String? youtubeId;
  final String? mimeType;
  final int byteSize;
  final int durationSeconds;
  final String? thumbnailUrl;
  final bool isPublished;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SchoolLibraryItem({
    required this.id,
    required this.schoolId,
    this.createdBy,
    required this.title,
    this.description,
    required this.resourceType,
    this.storagePath,
    this.externalUrl,
    this.youtubeId,
    this.mimeType,
    this.byteSize = 0,
    this.durationSeconds = 0,
    this.thumbnailUrl,
    this.isPublished = false,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get hasStorageFile => storagePath != null && storagePath!.isNotEmpty;

  String? get displayThumbnail {
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) return thumbnailUrl;
    if (youtubeId != null && youtubeId!.isNotEmpty) {
      return 'https://img.youtube.com/vi/$youtubeId/mqdefault.jpg';
    }
    return null;
  }

  String get sizeLabel {
    if (byteSize <= 0) return '';
    if (byteSize < 1024) return '$byteSize B';
    if (byteSize < 1024 * 1024) {
      return '${(byteSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(byteSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory SchoolLibraryItem.fromJson(Map<String, dynamic> json) {
    return SchoolLibraryItem(
      id: json['id'] as String,
      schoolId: json['school_id'] as String,
      createdBy: json['created_by'] as String?,
      title: json['title'] as String? ?? 'Untitled',
      description: json['description'] as String?,
      resourceType:
          SchoolLibraryResourceTypeX.fromDb(json['resource_type'] as String?),
      storagePath: json['storage_path'] as String?,
      externalUrl: json['external_url'] as String?,
      youtubeId: json['youtube_id'] as String?,
      mimeType: json['mime_type'] as String?,
      byteSize: (json['byte_size'] as num?)?.toInt() ?? 0,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
      thumbnailUrl: json['thumbnail_url'] as String?,
      isPublished: json['is_published'] as bool? ?? false,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'school_id': schoolId,
      if (createdBy != null) 'created_by': createdBy,
      'title': title,
      'description': description,
      'resource_type': resourceType.dbValue,
      'storage_path': storagePath,
      'external_url': externalUrl,
      'youtube_id': youtubeId,
      'mime_type': mimeType,
      'byte_size': byteSize,
      'duration_seconds': durationSeconds,
      'thumbnail_url': thumbnailUrl,
      'is_published': isPublished,
      'sort_order': sortOrder,
    };
  }

  SchoolLibraryItem copyWith({
    String? id,
    String? schoolId,
    String? createdBy,
    String? title,
    String? description,
    SchoolLibraryResourceType? resourceType,
    String? storagePath,
    String? externalUrl,
    String? youtubeId,
    String? mimeType,
    int? byteSize,
    int? durationSeconds,
    String? thumbnailUrl,
    bool? isPublished,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SchoolLibraryItem(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      createdBy: createdBy ?? this.createdBy,
      title: title ?? this.title,
      description: description ?? this.description,
      resourceType: resourceType ?? this.resourceType,
      storagePath: storagePath ?? this.storagePath,
      externalUrl: externalUrl ?? this.externalUrl,
      youtubeId: youtubeId ?? this.youtubeId,
      mimeType: mimeType ?? this.mimeType,
      byteSize: byteSize ?? this.byteSize,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      isPublished: isPublished ?? this.isPublished,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class SchoolLibraryUsage {
  final String schoolId;
  final int usedBytes;
  final int itemCount;
  final int maxSchoolBytes;
  final int maxFileBytes;
  final int remainingBytes;

  const SchoolLibraryUsage({
    required this.schoolId,
    required this.usedBytes,
    required this.itemCount,
    required this.maxSchoolBytes,
    required this.maxFileBytes,
    required this.remainingBytes,
  });

  double get usedFraction {
    if (maxSchoolBytes <= 0) return 0;
    return (usedBytes / maxSchoolBytes).clamp(0.0, 1.0);
  }

  String get usedLabel => _fmt(usedBytes);
  String get maxLabel => _fmt(maxSchoolBytes);
  String get remainingLabel => _fmt(remainingBytes);
  String get maxFileLabel => _fmt(maxFileBytes);

  static String _fmt(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  factory SchoolLibraryUsage.fromJson(Map<String, dynamic> json) {
    return SchoolLibraryUsage(
      schoolId: json['school_id']?.toString() ?? '',
      usedBytes: (json['used_bytes'] as num?)?.toInt() ?? 0,
      itemCount: (json['item_count'] as num?)?.toInt() ?? 0,
      maxSchoolBytes: (json['max_school_bytes'] as num?)?.toInt() ?? 0,
      maxFileBytes: (json['max_file_bytes'] as num?)?.toInt() ?? 0,
      remainingBytes: (json['remaining_bytes'] as num?)?.toInt() ?? 0,
    );
  }
}
