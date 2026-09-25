import 'package:flutter/foundation.dart';

import '../models/school_library_item.dart';
import '../services/school_library_service.dart';

class SchoolLibraryProvider extends ChangeNotifier {
  final SchoolLibraryService _service = SchoolLibraryService.instance;

  List<SchoolLibraryItem> _items = [];
  SchoolLibraryUsage? _usage;
  bool _loading = false;
  String? _error;
  String? _schoolId;

  List<SchoolLibraryItem> get items => _items;
  SchoolLibraryUsage? get usage => _usage;
  bool get loading => _loading;
  String? get error => _error;

  List<SchoolLibraryItem> get publishedItems =>
      _items.where((i) => i.isPublished).toList();

  Future<void> loadForSchool({
    required String schoolId,
    bool publishedOnly = false,
  }) async {
    _schoolId = schoolId;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _items = await _service.listForSchool(
        schoolId: schoolId,
        publishedOnly: publishedOnly,
      );
      if (!publishedOnly) {
        try {
          _usage = await _service.getUsage(schoolId);
        } catch (e) {
          debugPrint('[SchoolLibraryProvider] usage error: $e');
        }
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('[SchoolLibraryProvider] load error: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh({bool publishedOnly = false}) async {
    final id = _schoolId;
    if (id == null) return;
    await loadForSchool(schoolId: id, publishedOnly: publishedOnly);
  }

  Future<SchoolLibraryItem> addLinkOrYoutube({
    required String schoolId,
    required String title,
    String? description,
    required SchoolLibraryResourceType type,
    String? youtubeInput,
    String? externalUrl,
    bool isPublished = false,
  }) async {
    final item = await _service.createLinkOrYoutube(
      schoolId: schoolId,
      title: title,
      description: description,
      type: type,
      youtubeInput: youtubeInput,
      externalUrl: externalUrl,
      isPublished: isPublished,
    );
    _items.insert(0, item);
    notifyListeners();
    return item;
  }

  Future<SchoolLibraryItem> addUpload({
    required String schoolId,
    required String title,
    String? description,
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
    bool isPublished = false,
  }) async {
    final item = await _service.createWithUpload(
      schoolId: schoolId,
      title: title,
      description: description,
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
      isPublished: isPublished,
    );
    _items.insert(0, item);
    try {
      _usage = await _service.getUsage(schoolId);
    } catch (_) {}
    notifyListeners();
    return item;
  }

  Future<void> updateDetails(
    SchoolLibraryItem item, {
    required String title,
    String? description,
  }) async {
    final updated = await _service.updateItem(
      item.copyWith(title: title, description: description),
    );
    final idx = _items.indexWhere((i) => i.id == item.id);
    if (idx != -1) {
      _items[idx] = updated;
      notifyListeners();
    }
  }

  Future<void> togglePublished(SchoolLibraryItem item) async {
    final updated = await _service.setPublished(item.id, !item.isPublished);
    final idx = _items.indexWhere((i) => i.id == item.id);
    if (idx != -1) {
      _items[idx] = updated;
      notifyListeners();
    }
  }

  Future<void> delete(SchoolLibraryItem item) async {
    await _service.deleteItem(item);
    _items.removeWhere((i) => i.id == item.id);
    if (_schoolId != null) {
      try {
        _usage = await _service.getUsage(_schoolId!);
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<String> signedUrl(SchoolLibraryItem item) {
    return _service.createSignedUrl(item);
  }
}
