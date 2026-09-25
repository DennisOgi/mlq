import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/school_library_item.dart';

class SchoolLibraryService {
  SchoolLibraryService._();
  static final SchoolLibraryService instance = SchoolLibraryService._();

  final SupabaseClient _db = Supabase.instance.client;
  static const String bucket = 'school-library';

  String? get _uid => _db.auth.currentUser?.id;

  static String _fmtBytes(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Extract a YouTube video id from a bare id or common URL forms.
  static String? extractYoutubeId(String input) {
    final raw = input.trim();
    if (raw.isEmpty) return null;
    if (RegExp(r'^[\w-]{11}$').hasMatch(raw)) return raw;
    final patterns = [
      RegExp(r'youtu\.be/([\w-]{11})'),
      RegExp(r'youtube\.com/watch\?v=([\w-]{11})'),
      RegExp(r'youtube\.com/embed/([\w-]{11})'),
      RegExp(r'youtube\.com/shorts/([\w-]{11})'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(raw);
      if (m != null) return m.group(1);
    }
    return null;
  }

  static SchoolLibraryResourceType inferTypeFromMime(String? mime) {
    final m = (mime ?? '').toLowerCase();
    if (m.startsWith('video/')) return SchoolLibraryResourceType.videoFile;
    if (m == 'application/pdf') return SchoolLibraryResourceType.pdf;
    if (m.startsWith('image/')) return SchoolLibraryResourceType.image;
    return SchoolLibraryResourceType.document;
  }

  Future<List<SchoolLibraryItem>> listForSchool({
    required String schoolId,
    bool publishedOnly = false,
  }) async {
    try {
      var q = _db
          .from('school_library_items')
          .select()
          .eq('school_id', schoolId);
      if (publishedOnly) {
        q = q.eq('is_published', true);
      }
      final rows = await q
          .order('sort_order', ascending: true)
          .order('created_at', ascending: false);
      return (rows as List)
          .map((r) => SchoolLibraryItem.fromJson(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e) {
      debugPrint('[SchoolLibrary] listForSchool error: $e');
      rethrow;
    }
  }

  Future<SchoolLibraryUsage> getUsage(String schoolId) async {
    final result = await _db.rpc(
      'get_school_library_usage',
      params: {'p_school_id': schoolId},
    );
    return SchoolLibraryUsage.fromJson(Map<String, dynamic>.from(result as Map));
  }

  Future<String> createSignedUrl(SchoolLibraryItem item, {int expiresIn = 3600}) async {
    if (!item.hasStorageFile) {
      throw Exception('Item has no uploaded file');
    }
    // Validate access via RPC, then mint signed URL from client storage API.
    final access = await _db.rpc(
      'create_school_library_signed_url',
      params: {
        'p_item_id': item.id,
        'p_expires_in': expiresIn,
      },
    );
    final map = Map<String, dynamic>.from(access as Map);
    if (map['success'] != true) {
      throw Exception(map['error']?.toString() ?? 'Access denied');
    }
    final path = map['path']?.toString() ?? item.storagePath!;
    final signed = await _db.storage
        .from(bucket)
        .createSignedUrl(path, expiresIn);
    return signed;
  }

  Future<SchoolLibraryItem> createLinkOrYoutube({
    required String schoolId,
    required String title,
    String? description,
    required SchoolLibraryResourceType type,
    String? youtubeInput,
    String? externalUrl,
    bool isPublished = false,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not authenticated');

    String? youtubeId;
    String? url = externalUrl?.trim();
    if (type == SchoolLibraryResourceType.youtube) {
      youtubeId = extractYoutubeId(youtubeInput ?? url ?? '');
      if (youtubeId == null) {
        throw Exception('Enter a valid YouTube URL or video ID');
      }
      url ??= 'https://www.youtube.com/watch?v=$youtubeId';
    } else if (type == SchoolLibraryResourceType.link) {
      if (url == null || url.isEmpty) {
        throw Exception('Enter a valid URL');
      }
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'https://$url';
      }
    } else {
      throw Exception('Use createWithUpload for file resources');
    }

    final row = {
      'school_id': schoolId,
      'created_by': uid,
      'title': title.trim(),
      'description': description?.trim(),
      'resource_type': type.dbValue,
      'youtube_id': youtubeId,
      'external_url': url,
      'is_published': isPublished,
      'byte_size': 0,
    };

    final inserted = await _db
        .from('school_library_items')
        .insert(row)
        .select()
        .single();
    return SchoolLibraryItem.fromJson(Map<String, dynamic>.from(inserted));
  }

  Future<SchoolLibraryItem> createWithUpload({
    required String schoolId,
    required String title,
    String? description,
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
    bool isPublished = false,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not authenticated');

    final usage = await getUsage(schoolId);
    if (bytes.length > usage.maxFileBytes) {
      throw Exception(
        'File is too large. Max ${_fmtBytes(usage.maxFileBytes)} per file.',
      );
    }
    if (bytes.length > usage.remainingBytes) {
      throw Exception(
        'School library storage is full '
        '(${usage.usedLabel} / ${usage.maxLabel}). '
        'Delete old files or use a YouTube/link instead.',
      );
    }

    final type = inferTypeFromMime(mimeType);
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

    // Insert metadata first to get a stable UUID for the storage path.
    final draft = await _db
        .from('school_library_items')
        .insert({
          'school_id': schoolId,
          'created_by': uid,
          'title': title.trim(),
          'description': description?.trim(),
          'resource_type': type.dbValue,
          // Temporary placeholder path until upload completes; constraint needs a source.
          'storage_path': '$schoolId/pending/$safeName',
          'mime_type': mimeType,
          'byte_size': bytes.length,
          'is_published': false,
        })
        .select()
        .single();

    final created = SchoolLibraryItem.fromJson(Map<String, dynamic>.from(draft));
    final storagePath = '$schoolId/${created.id}/$safeName';

    var uploaded = false;
    try {
      await _db.storage.from(bucket).uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: mimeType,
              upsert: true,
            ),
          );
      uploaded = true;

      final updated = await _db
          .from('school_library_items')
          .update({
            'storage_path': storagePath,
            'is_published': isPublished,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', created.id)
          .select()
          .single();

      return SchoolLibraryItem.fromJson(Map<String, dynamic>.from(updated));
    } catch (e) {
      if (uploaded) {
        try {
          await _db.storage.from(bucket).remove([storagePath]);
        } catch (_) {}
      }
      try {
        await _db.from('school_library_items').delete().eq('id', created.id);
      } catch (_) {}
      debugPrint('[SchoolLibrary] upload failed: $e');
      rethrow;
    }
  }

  Future<SchoolLibraryItem> updateItem(SchoolLibraryItem item) async {
    final updated = await _db
        .from('school_library_items')
        .update({
          'title': item.title.trim(),
          'description': item.description?.trim(),
          'is_published': item.isPublished,
          'sort_order': item.sortOrder,
          'external_url': item.externalUrl,
          'youtube_id': item.youtubeId,
          'thumbnail_url': item.thumbnailUrl,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', item.id)
        .select()
        .single();
    return SchoolLibraryItem.fromJson(Map<String, dynamic>.from(updated));
  }

  Future<SchoolLibraryItem> setPublished(String id, bool published) async {
    final updated = await _db
        .from('school_library_items')
        .update({
          'is_published': published,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id)
        .select()
        .single();
    return SchoolLibraryItem.fromJson(Map<String, dynamic>.from(updated));
  }

  Future<void> deleteItem(SchoolLibraryItem item) async {
    if (item.hasStorageFile) {
      try {
        await _db.storage.from(bucket).remove([item.storagePath!]);
      } catch (e) {
        debugPrint('[SchoolLibrary] storage delete warning: $e');
      }
    }
    await _db.from('school_library_items').delete().eq('id', item.id);
  }
}
