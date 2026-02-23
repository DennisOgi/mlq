import 'package:flutter/foundation.dart';
import '../services/organization_settings_service.dart';

class OrganizationSettingsProvider with ChangeNotifier {
  final OrganizationSettingsService _settingsService = OrganizationSettingsService.instance;
  
  // Settings cache
  Map<String, String> _settings = {};
  bool _isLoading = false;
  bool _isLoaded = false;
  
  // Getters
  Map<String, String> get settings => _settings;
  bool get isLoading => _isLoading;
  bool get isLoaded => _isLoaded;
  
  // Get specific setting values
  String get organizationName => _settings['organization_name'] ?? 'My Leadership Quest';
  String get logoUrl => _settings['organization_logo_url'] ?? '';
  String get primaryColor => _settings['primary_color'] ?? '#2196F3';
  String get secondaryColor => _settings['secondary_color'] ?? '#FF9800';
  String get welcomeMessage => _settings['welcome_message'] ?? 'Welcome to your leadership journey!';
  
  // Load all settings
  Future<void> loadSettings() async {
    if (_isLoaded) return; // Prevent multiple loads
    
    _isLoading = true;
    notifyListeners();
    
    try {
      _settings = await _settingsService.loadSettings();
      _isLoaded = true;
      debugPrint('Organization settings loaded: ${_settings.length} settings');
    } catch (e) {
      debugPrint('Error loading organization settings: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Update a specific setting
  Future<bool> updateSetting(String key, String value) async {
    try {
      final success = await _settingsService.updateSetting(key, value);
      
      if (success) {
        _settings[key] = value;
        notifyListeners();
        debugPrint('Setting updated: $key = $value');
      }
      
      return success;
    } catch (e) {
      debugPrint('Error updating setting: $e');
      return false;
    }
  }
  
  // Upload organization logo
  Future<String?> uploadLogo(Uint8List imageBytes, String fileName) async {
    try {
      // Delete old logo first
      final oldLogoUrl = logoUrl;
      if (oldLogoUrl.isNotEmpty) {
        await _settingsService.deleteOldLogo(oldLogoUrl);
      }
      
      // Upload new logo
      final newLogoUrl = await _settingsService.uploadLogo(imageBytes, fileName);
      
      if (newLogoUrl != null) {
        _settings['organization_logo_url'] = newLogoUrl;
        notifyListeners();
        debugPrint('Logo updated: $newLogoUrl');
      }
      
      return newLogoUrl;
    } catch (e) {
      debugPrint('Error uploading logo: $e');
      return null;
    }
  }
  
  // Update organization name
  Future<bool> updateOrganizationName(String name) async {
    return await updateSetting('organization_name', name);
  }
  
  // Update primary color
  Future<bool> updatePrimaryColor(String color) async {
    return await updateSetting('primary_color', color);
  }
  
  // Update secondary color
  Future<bool> updateSecondaryColor(String color) async {
    return await updateSetting('secondary_color', color);
  }
  
  // Update welcome message
  Future<bool> updateWelcomeMessage(String message) async {
    return await updateSetting('welcome_message', message);
  }
  
  // Refresh settings (useful after external updates)
  Future<void> refreshSettings() async {
    _isLoaded = false;
    _settingsService.clearCache();
    await loadSettings();
  }
  
  // Check if logo is set
  bool get hasLogo => logoUrl.isNotEmpty;
  
  // Get logo URL or fallback to default asset
  String getLogoUrlOrDefault() {
    return hasLogo ? logoUrl : 'assets/images/default_logo.png';
  }
}
