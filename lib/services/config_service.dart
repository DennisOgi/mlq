import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A service for securely managing configuration values and API keys
/// Uses flutter_secure_storage for sensitive data in production
/// Falls back to SharedPreferences in debug mode for easier development
class ConfigService {
  static final ConfigService _instance = ConfigService._internal();
  static ConfigService get instance => _instance;
  
  factory ConfigService() {
    return _instance;
  }
  
  ConfigService._internal();
  
  // Storage instances
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  SharedPreferences? _prefs;
  
  // Configuration keys
  static const String _geminiApiKeyKey = 'gemini_api_key';
  static const String _defaultGeminiApiKey = 'AIzaSyCQEaFf5DAKyLZJ5HlMx5a_C_UYcbazxlo'; // Updated API key
  // Flutterwave config (public values only; secrets must live on server)
  static const String _flwPublicKeyKey = 'flutterwave_public_key';
  static const String _flwIsTestModeKey = 'flutterwave_is_test_mode';
  static const String _flwRedirectUrlKey = 'flutterwave_redirect_url';
  // PRODUCTION LIVE KEYS - UPDATED 2025-10-02
  static const String _defaultFlwPublicKey = 'FLWPUBK-3458a6b1472c5d67e1f5e1ccc4be9598-X'; // LIVE KEY
  static const bool _defaultFlwIsTestMode = false; // PRODUCTION MODE
  static const String _defaultFlwRedirectUrl = 'mlq://payment-callback';
  
  // Initialization flag
  bool _isInitialized = false;
  
  /// Initialize the config service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _prefs = await SharedPreferences.getInstance();
    
    // Set default values if not already set
    // This allows first-time initialization with our default values
    if (kReleaseMode) {
      if (await _secureStorage.read(key: _geminiApiKeyKey) == null) {
        await _secureStorage.write(key: _geminiApiKeyKey, value: _defaultGeminiApiKey);
      }
      // Flutterwave defaults
      if (await _secureStorage.read(key: _flwPublicKeyKey) == null) {
        await _secureStorage.write(key: _flwPublicKeyKey, value: _defaultFlwPublicKey);
      }
      if (await _secureStorage.read(key: _flwIsTestModeKey) == null) {
        await _secureStorage.write(key: _flwIsTestModeKey, value: _defaultFlwIsTestMode.toString());
      }
      if (await _secureStorage.read(key: _flwRedirectUrlKey) == null) {
        await _secureStorage.write(key: _flwRedirectUrlKey, value: _defaultFlwRedirectUrl);
      }
    } else {
      if (_prefs!.getString(_geminiApiKeyKey) == null) {
        await _prefs!.setString(_geminiApiKeyKey, _defaultGeminiApiKey);
      }
      // Flutterwave defaults - FORCE LIVE KEY FOR PRODUCTION
      // Clear any old test keys and set live key
      await _prefs!.setString(_flwPublicKeyKey, _defaultFlwPublicKey);
      await _prefs!.setBool(_flwIsTestModeKey, _defaultFlwIsTestMode);
      await _prefs!.setString(_flwRedirectUrlKey, _defaultFlwRedirectUrl);
      debugPrint('🔑 [ConfigService] PRODUCTION MODE - Live key set: ${_defaultFlwPublicKey.substring(0, 15)}...');
      debugPrint('🔑 [ConfigService] Test mode: $_defaultFlwIsTestMode');
    }
    
    _isInitialized = true;
    debugPrint('ConfigService initialized');
  }
  
  /// Get the Gemini API key
  Future<String> getGeminiApiKey() async {
    if (!_isInitialized) await initialize();
    
    try {
      if (kReleaseMode) {
        // In production, use secure storage
        return await _secureStorage.read(key: _geminiApiKeyKey) ?? _defaultGeminiApiKey;
      } else {
        // In debug, use SharedPreferences for easier development
        return _prefs!.getString(_geminiApiKeyKey) ?? _defaultGeminiApiKey;
      }
    } catch (e) {
      debugPrint('Error retrieving Gemini API key: $e');
      return _defaultGeminiApiKey;
    }
  }
  
  /// Set the Gemini API key
  Future<void> setGeminiApiKey(String apiKey) async {
    if (!_isInitialized) await initialize();
    
    try {
      if (kReleaseMode) {
        await _secureStorage.write(key: _geminiApiKeyKey, value: apiKey);
      } else {
        await _prefs!.setString(_geminiApiKeyKey, apiKey);
      }
    } catch (e) {
      debugPrint('Error setting Gemini API key: $e');
    }
  }
  
  /// Reset the Gemini API key to the default value
  Future<void> resetGeminiApiKey() async {
    await setGeminiApiKey(_defaultGeminiApiKey);
  }
  
  // ---------- Flutterwave (client-side) configuration ----------
  /// Get Flutterwave public key (client side). Secret/encryption keys must be on server only.
  Future<String> getFlutterwavePublicKey() async {
    if (!_isInitialized) await initialize();
    
    // ALWAYS return live key for production
    const key = _defaultFlwPublicKey;
    
    debugPrint('🔑 [ConfigService] PRODUCTION - Flutterwave Public Key: ${key.substring(0, 15)}...');
    debugPrint('🔑 [ConfigService] Key Length: ${key.length}');
    debugPrint('🔑 [ConfigService] Is Live Key: ${!key.contains('TEST')}');
    
    return key;
  }

  Future<void> setFlutterwavePublicKey(String publicKey) async {
    if (!_isInitialized) await initialize();
    try {
      if (kReleaseMode) {
        await _secureStorage.write(key: _flwPublicKeyKey, value: publicKey);
      } else {
        await _prefs!.setString(_flwPublicKeyKey, publicKey);
      }
    } catch (e) {
    }
  }

  Future<bool> getFlutterwaveIsTestMode() async {
    if (!_isInitialized) await initialize();
    
    // ALWAYS return false for production
    debugPrint('🔑 [ConfigService] PRODUCTION MODE - Test mode: false');
    return false;
  }

  Future<void> setFlutterwaveIsTestMode(bool isTest) async {
    if (!_isInitialized) await initialize();
    try {
      if (kReleaseMode) {
        await _secureStorage.write(key: _flwIsTestModeKey, value: isTest.toString());
      } else {
        await _prefs!.setBool(_flwIsTestModeKey, isTest);
      }
    } catch (e) {
      debugPrint('Error setting Flutterwave test mode: $e');
    }
  }

  Future<String> getFlutterwaveRedirectUrl() async {
    if (!_isInitialized) await initialize();
    try {
      if (kReleaseMode) {
        return await _secureStorage.read(key: _flwRedirectUrlKey) ?? _defaultFlwRedirectUrl;
      } else {
        return _prefs!.getString(_flwRedirectUrlKey) ?? _defaultFlwRedirectUrl;
      }
    } catch (e) {
      debugPrint('Error retrieving Flutterwave redirect URL: $e');
      return _defaultFlwRedirectUrl;
    }
  }

  Future<void> setFlutterwaveRedirectUrl(String url) async {
    if (!_isInitialized) await initialize();
    try {
      if (kReleaseMode) {
        await _secureStorage.write(key: _flwRedirectUrlKey, value: url);
      } else {
        await _prefs!.setString(_flwRedirectUrlKey, url);
      }
    } catch (e) {
      debugPrint('Error setting Flutterwave redirect URL: $e');
    }
  }

  /// Clear all stored configuration
  Future<void> clearAllConfig() async {
    if (!_isInitialized) await initialize();
    
    try {
      if (kReleaseMode) {
        await _secureStorage.deleteAll();
      } else {
        await _prefs!.clear();
      }
    } catch (e) {
      debugPrint('Error clearing configuration: $e');
    }
  }
}
