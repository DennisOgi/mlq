import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized error to message mapper for user-friendly UI
class ErrorHandler {
  static String toMessage(Object error) {
    // Already-curated, user-facing error from our services
    if (error.runtimeType.toString() == 'UserFacingError') {
      return error.toString();
    }

    // Network issues
    if (error is SocketException) {
      return 'Network issue detected. Please check your internet connection and try again.';
    }
    if (error is TimeoutException) {
      return 'That took too long. Please try again in a moment.';
    }

    // Supabase auth specific
    if (error is AuthException) {
      final msg = (error.message ?? '').toLowerCase();
      if (msg.contains('invalid') || msg.contains('credential')) {
        return 'Your email or password is incorrect. Please try again.';
      }
      if (msg.contains('email not confirmed') || msg.contains('confirm')) {
        return 'Please confirm your email before logging in.';
      }
      return 'We couldn\'t complete your request right now. Please try again.';
    }

    // Postgrest errors (data layer)
    if (error is PostgrestException) {
      // Avoid exposing sensitive details
      return 'We couldn\'t complete your request right now. Please try again.';
    }

    // Fallback general message
    return 'Something went wrong. Please try again.';
  }
}
