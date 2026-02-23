# Gemini API Key Location

## Primary Location

**File**: `lib/services/config_service.dart`  
**Line**: 24

```dart
static const String _defaultGeminiApiKey = 'AIzaSyBLIM77eiE6nb2WjYI2ZpxxWFrSl1QhJ-4';
```

## How It Works

### ConfigService Architecture

The app uses `ConfigService` to manage API keys securely:

1. **Production Mode** (`kReleaseMode`):
   - Stores keys in `FlutterSecureStorage` (encrypted)
   - Keys are encrypted at rest on the device

2. **Debug Mode** (`kDebugMode`):
   - Falls back to `SharedPreferences` for easier development

### Initialization Flow

```dart
await ConfigService.instance.initialize();
final apiKey = await ConfigService.instance.getGeminiApiKey();
```

## Key Rotation

To update the Gemini API key:

### Option 1: Update Default
1. Open `lib/services/config_service.dart`
2. Update line 24: `_defaultGeminiApiKey = 'YOUR_NEW_KEY'`
3. Clear app data or reinstall

### Option 2: Runtime Update
```dart
await ConfigService.instance.setGeminiApiKey('YOUR_NEW_KEY');
```

## Edge Function Key

For the server-side Edge Function:

**Location**: Supabase Dashboard → Edge Functions → Environment Variables

**Variable Name**: `GEMINI_API_KEY`  
**Value**: Your Gemini API key

## Current Keys in Codebase

### 1. Gemini API Key (AI Services)
- **Location**: `lib/services/config_service.dart:24`
- **Key**: `AIzaSyCQEaFf5DAKyLZJ5HlMx5a_C_UYcbazxlo` (Updated 2025-10-09)
- **Used For**: AI Coach, Mini-course generation

### 2. Firebase API Keys (Push Notifications)
- **Location**: `lib/firebase_options.dart`
- **Key**: `AIzaSyDrPeaQiGvj4Vv4SLIFYjIEKTluf4Nvi8k`
- **Used For**: Firebase services (different from Gemini)

## Security Best Practices

### Recommended for Production

1. **Environment Variables**: Use flutter_dotenv
2. **Build-time Injection**: `--dart-define=GEMINI_API_KEY=key`
3. **Backend Proxy**: Most secure - key never exposed to client
4. **Key Rotation**: Rotate every 90 days
