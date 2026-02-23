import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import 'supabase_service.dart';

class OrganizationSettingsService {
  static final OrganizationSettingsService _instance = OrganizationSettingsService._internal();
  
  static OrganizationSettingsService get instance => _instance;
  
  factory OrganizationSettingsService() {
    return _instance;
  }

  // Upload an arbitrary asset and return its public URL without updating settings
  // Useful for sponsor logos attached to a single premium challenge
  Future<String?> uploadPublicAsset(Uint8List imageBytes, String fileName, {String folder = 'logos/sponsors'}) async {
    try {
      // Compress and optimize image
      final optimizedBytes = await _optimizeImage(imageBytes);

      // Generate unique file name
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(fileName).toLowerCase();
      final uniqueFileName = 'asset_${timestamp}$extension';

      // Upload to Supabase Storage at the specified folder
      final uploadPath = '$folder/$uniqueFileName';
      await _client.storage
          .from('organization-assets')
          .uploadBinary(uploadPath, optimizedBytes);

      // Return public URL
      final publicUrl = _client.storage
          .from('organization-assets')
          .getPublicUrl(uploadPath);

      debugPrint('Public asset uploaded successfully: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading public asset: $e');
      return null;
    }
  }
  
  OrganizationSettingsService._internal();
  
  // Get Supabase client
  SupabaseClient get _client => SupabaseService.instance.client;
  
  // Cache for organization settings
  Map<String, String> _settingsCache = {};
  bool _isLoaded = false;
  
  // Load all organization settings
  Future<Map<String, String>> loadSettings() async {
    try {
      final response = await _client
          .from('organization_settings')
          .select('setting_key, setting_value');
      
      _settingsCache = {};
      for (final setting in response) {
        _settingsCache[setting['setting_key']] = setting['setting_value'] ?? '';
      }
      
      _isLoaded = true;
      debugPrint('Loaded ${_settingsCache.length} organization settings');
      return _settingsCache;
    } catch (e) {
      debugPrint('Error loading organization settings: $e');
      return {};
    }
  }
  
  // Get a specific setting value
  Future<String> getSetting(String key, {String defaultValue = ''}) async {
    if (!_isLoaded) {
      await loadSettings();
    }
    return _settingsCache[key] ?? defaultValue;
  }
  
  // Update a setting value
  Future<bool> updateSetting(String key, String value, {String? updatedBy}) async {
    try {
      await _client
          .from('organization_settings')
          .update({
            'setting_value': value,
            'updated_at': DateTime.now().toIso8601String(),
            'updated_by': updatedBy ?? _client.auth.currentUser?.id,
          })
          .eq('setting_key', key);
      
      // Update cache
      _settingsCache[key] = value;
      
      debugPrint('Updated organization setting: $key = $value');
      return true;
    } catch (e) {
      debugPrint('Error updating organization setting: $e');
      return false;
    }
  }
  
  // Upload organization logo
  Future<String?> uploadLogo(Uint8List imageBytes, String fileName) async {
    try {
      // Compress and optimize image
      final optimizedBytes = await _optimizeImage(imageBytes);
      
      // Generate unique file name
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(fileName).toLowerCase();
      final uniqueFileName = 'logo_${timestamp}$extension';
      
      // Upload to Supabase Storage
      final uploadPath = 'logos/$uniqueFileName';
      await _client.storage
          .from('organization-assets')
          .uploadBinary(uploadPath, optimizedBytes);
      
      // Get public URL
      final publicUrl = _client.storage
          .from('organization-assets')
          .getPublicUrl(uploadPath);
      
      // Update organization logo setting
      await updateSetting('organization_logo_url', publicUrl);
      
      debugPrint('Logo uploaded successfully: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading logo: $e');
      return null;
    }
  }
  
  // Delete old logo from storage
  Future<bool> deleteOldLogo(String logoUrl) async {
    try {
      if (logoUrl.isEmpty) return true;
      
      // Extract file path from URL
      final uri = Uri.parse(logoUrl);
      final pathSegments = uri.pathSegments;
      
      // Find the path after 'organization-assets'
      final bucketIndex = pathSegments.indexOf('organization-assets');
      if (bucketIndex == -1 || bucketIndex >= pathSegments.length - 1) {
        return false;
      }
      
      final filePath = pathSegments.sublist(bucketIndex + 1).join('/');
      
      await _client.storage
          .from('organization-assets')
          .remove([filePath]);
      
      debugPrint('Old logo deleted: $filePath');
      return true;
    } catch (e) {
      debugPrint('Error deleting old logo: $e');
      return false;
    }
  }
  
  // Optimize image for web usage
  Future<Uint8List> _optimizeImage(Uint8List imageBytes) async {
    try {
      // Decode image
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) return imageBytes;
      
      // Resize if too large (max 512x512 for logos)
      if (image.width > 512 || image.height > 512) {
        image = img.copyResize(
          image,
          width: image.width > image.height ? 512 : null,
          height: image.height > image.width ? 512 : null,
          interpolation: img.Interpolation.linear,
        );
      }
      
      // Encode as PNG with compression
      final optimizedBytes = img.encodePng(image, level: 6);
      
      debugPrint('Image optimized: ${imageBytes.length} -> ${optimizedBytes.length} bytes');
      return Uint8List.fromList(optimizedBytes);
    } catch (e) {
      debugPrint('Error optimizing image: $e');
      return imageBytes;
    }
  }
  
  // Get organization logo URL
  Future<String> getLogoUrl() async {
    return await getSetting('organization_logo_url');
  }
  
  // Get organization name
  Future<String> getOrganizationName() async {
    return await getSetting('organization_name', defaultValue: 'My Leadership Quest');
  }
  
  // Get primary color
  Future<String> getPrimaryColor() async {
    return await getSetting('primary_color', defaultValue: '#2196F3');
  }
  
  // Get secondary color
  Future<String> getSecondaryColor() async {
    return await getSetting('secondary_color', defaultValue: '#FF9800');
  }
  
  // Get welcome message
  Future<String> getWelcomeMessage() async {
    return await getSetting('welcome_message', defaultValue: 'Welcome to your leadership journey!');
  }
  
  // Get MLQ organization UUID
  Future<String> getMlqOrganizationId() async {
    return await getSetting('mlq_organization_id', defaultValue: '215d53ce-8500-4d7a-b280-e54e820b014a');
  }
  
  // Clear cache (useful for testing or when settings are updated externally)
  void clearCache() {
    _settingsCache.clear();
    _isLoaded = false;
  }
}
