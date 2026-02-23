import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A service to handle caching data for offline use
class CacheService {
  static final CacheService _instance = CacheService._internal();
  
  factory CacheService() => _instance;
  
  CacheService._internal();
  
  /// Cache expiration times
  static const Duration shortCache = Duration(minutes: 30);
  static const Duration mediumCache = Duration(hours: 12);
  static const Duration longCache = Duration(days: 7);
  
  /// Initialize the cache service
  Future<void> initialize() async {
    // Create cache directories if they don't exist
    await _createCacheDirectories();
    
    // Clean expired cache entries
    await cleanExpiredCache();
  }
  
  /// Create necessary cache directories
  Future<void> _createCacheDirectories() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${appDir.path}/app_cache');
      
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      
      // Create subdirectories for different types of cached data
      final imageCache = Directory('${cacheDir.path}/images');
      final dataCache = Directory('${cacheDir.path}/data');
      
      if (!await imageCache.exists()) {
        await imageCache.create();
      }
      
      if (!await dataCache.exists()) {
        await dataCache.create();
      }
    } catch (e) {
      debugPrint('Error creating cache directories: $e');
    }
  }
  
  /// Get the path to the cache directory
  Future<String> get cachePath async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/app_cache';
  }
  
  /// Cache JSON data with a specified key and expiration duration
  Future<bool> cacheData({
    required String key,
    required Map<String, dynamic> data,
    Duration expiration = mediumCache,
  }) async {
    try {
      final cacheDir = await cachePath;
      final file = File('$cacheDir/data/$key.json');
      
      // Create metadata with expiration time
      final metadata = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'expiration': expiration.inMilliseconds,
        'data': data,
      };
      
      // Write data to file
      await file.writeAsString(jsonEncode(metadata));
      return true;
    } catch (e) {
      debugPrint('Error caching data: $e');
      return false;
    }
  }
  
  /// Retrieve cached JSON data by key
  Future<Map<String, dynamic>?> getCachedData(String key) async {
    try {
      final cacheDir = await cachePath;
      final file = File('$cacheDir/data/$key.json');
      
      if (!await file.exists()) {
        return null;
      }
      
      // Read and parse the cached data
      final jsonString = await file.readAsString();
      final metadata = jsonDecode(jsonString) as Map<String, dynamic>;
      
      // Check if cache has expired
      final timestamp = metadata['timestamp'] as int;
      final expiration = metadata['expiration'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      if (now - timestamp > expiration) {
        // Cache has expired, delete it
        await file.delete();
        return null;
      }
      
      return metadata['data'] as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error retrieving cached data: $e');
      return null;
    }
  }
  
  /// Cache an image file
  Future<bool> cacheImage({
    required String key,
    required List<int> imageBytes,
    Duration expiration = longCache,
  }) async {
    try {
      final cacheDir = await cachePath;
      final file = File('$cacheDir/images/$key');
      
      // Write image to file
      await file.writeAsBytes(imageBytes);
      
      // Store metadata in shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('img_cache_${key}_timestamp', DateTime.now().millisecondsSinceEpoch);
      await prefs.setInt('img_cache_${key}_expiration', expiration.inMilliseconds);
      
      return true;
    } catch (e) {
      debugPrint('Error caching image: $e');
      return false;
    }
  }
  
  /// Get a cached image file
  Future<File?> getCachedImage(String key) async {
    try {
      final cacheDir = await cachePath;
      final file = File('$cacheDir/images/$key');
      
      if (!await file.exists()) {
        return null;
      }
      
      // Check expiration from shared preferences
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt('img_cache_${key}_timestamp');
      final expiration = prefs.getInt('img_cache_${key}_expiration');
      
      if (timestamp == null || expiration == null) {
        return file; // No expiration info, return the file anyway
      }
      
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - timestamp > expiration) {
        // Cache has expired, delete it
        await file.delete();
        await prefs.remove('img_cache_${key}_timestamp');
        await prefs.remove('img_cache_${key}_expiration');
        return null;
      }
      
      return file;
    } catch (e) {
      debugPrint('Error retrieving cached image: $e');
      return null;
    }
  }
  
  /// Clean expired cache entries
  Future<void> cleanExpiredCache() async {
    try {
      // Clean expired data files
      final cacheDir = await cachePath;
      final dataDir = Directory('$cacheDir/data');
      final imageDir = Directory('$cacheDir/images');
      
      if (await dataDir.exists()) {
        final files = await dataDir.list().toList();
        for (var entity in files) {
          if (entity is File && entity.path.endsWith('.json')) {
            try {
              final jsonString = await entity.readAsString();
              final metadata = jsonDecode(jsonString) as Map<String, dynamic>;
              
              final timestamp = metadata['timestamp'] as int;
              final expiration = metadata['expiration'] as int;
              final now = DateTime.now().millisecondsSinceEpoch;
              
              if (now - timestamp > expiration) {
                await entity.delete();
              }
            } catch (e) {
              // If we can't read the file, delete it
              await entity.delete();
            }
          }
        }
      }
      
      // Clean expired image files
      if (await imageDir.exists()) {
        final prefs = await SharedPreferences.getInstance();
        final files = await imageDir.list().toList();
        
        for (var entity in files) {
          if (entity is File) {
            final key = entity.path.split('/').last;
            final timestamp = prefs.getInt('img_cache_${key}_timestamp');
            final expiration = prefs.getInt('img_cache_${key}_expiration');
            
            if (timestamp == null || expiration == null) {
              continue; // No expiration info, keep the file
            }
            
            final now = DateTime.now().millisecondsSinceEpoch;
            if (now - timestamp > expiration) {
              await entity.delete();
              await prefs.remove('img_cache_${key}_timestamp');
              await prefs.remove('img_cache_${key}_expiration');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error cleaning expired cache: $e');
    }
  }
  
  /// Clear all cached data
  Future<void> clearAllCache() async {
    try {
      final cacheDir = await cachePath;
      final directory = Directory(cacheDir);
      
      if (await directory.exists()) {
        await directory.delete(recursive: true);
        await _createCacheDirectories();
      }
      
      // Clear cache-related shared preferences
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (var key in keys) {
        if (key.startsWith('img_cache_')) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }
}
