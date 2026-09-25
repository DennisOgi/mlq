import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:my_leadership_quest/services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Client for peer referral codes and invite-link capture.
///
/// Payout still happens server-side when the invitee buys Monthly/Quarterly.
class ReferralService {
  static final ReferralService _instance = ReferralService._internal();
  factory ReferralService() => _instance;
  ReferralService._internal();

  static const pendingCodeKey = 'pending_referral_code';

  StreamSubscription<Uri>? _linkSub;
  bool _linksStarted = false;
  Future<Map<String, dynamic>?>? _inFlightApply;

  Future<Map<String, dynamic>> ensureMyCode() async {
    try {
      final result =
          await SupabaseService().client.rpc('ensure_my_referral_code');
      return _asMap(result);
    } catch (e) {
      debugPrint('❌ [Referral] ensureMyCode: $e');
      return {'success': false, 'error': _errorCode(e)};
    }
  }

  Future<Map<String, dynamic>> applyCode(String code) async {
    try {
      final normalized = _normalizeCode(code);
      if (normalized == null) {
        return {'success': false, 'error': 'invalid_code'};
      }
      final result = await SupabaseService().client.rpc(
        'apply_referral_code',
        params: {'p_code': normalized},
      );
      return _asMap(result);
    } catch (e) {
      debugPrint('❌ [Referral] applyCode: $e');
      return {'success': false, 'error': _errorCode(e)};
    }
  }

  Future<Map<String, dynamic>> getStats() async {
    try {
      final result =
          await SupabaseService().client.rpc('get_my_referral_stats');
      return _asMap(result);
    } catch (e) {
      debugPrint('❌ [Referral] getStats: $e');
      return {'success': false, 'error': _errorCode(e)};
    }
  }

  String shareMessage(String code) {
    return 'Join me on My Leadership Quest!\n\n'
        'My invite code: $code\n\n'
        'Create an account and enter this code on signup (or in Invite & Earn). '
        'If you subscribe to Monthly or Quarterly, I earn a LeadWallet reward.\n\n'
        'Open in app: mlq://invite?ref=$code';
  }

  /// Persist a referral code until the invitee authenticates and applies it.
  Future<void> savePendingCode(String? raw) async {
    final code = _normalizeCode(raw);
    if (code == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(pendingCodeKey, code);
    debugPrint('📎 [Referral] Pending code saved: $code');
  }

  Future<String?> getPendingCode() async {
    final prefs = await SharedPreferences.getInstance();
    return _normalizeCode(prefs.getString(pendingCodeKey));
  }

  Future<void> clearPendingCode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(pendingCodeKey);
  }

  /// Extract `ref` from invite URIs and store for post-auth apply.
  Future<bool> captureFromUri(Uri? uri) async {
    if (uri == null) return false;
    final ref = uri.queryParameters['ref'] ??
        uri.queryParameters['code'] ??
        uri.queryParameters['referral'];
    if (ref == null || ref.trim().isEmpty) {
      // Path style: /invite/MLQ-XXXX or mlq://invite/MLQ-XXXX
      if (uri.pathSegments.isNotEmpty) {
        final last = uri.pathSegments.last;
        if (_normalizeCode(last) != null &&
            last.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '').startsWith('MLQ')) {
          await savePendingCode(last);
          return true;
        }
      }
      return false;
    }
    await savePendingCode(ref);
    return true;
  }

  /// After login/register: apply pending code once, then clear on success
  /// or permanent rejection (already attributed / self / invalid).
  Future<Map<String, dynamic>?> tryApplyPendingCode() async {
    if (_inFlightApply != null) return _inFlightApply;
    final future = _tryApplyPendingCodeBody();
    _inFlightApply = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlightApply, future)) {
        _inFlightApply = null;
      }
    }
  }

  Future<Map<String, dynamic>?> _tryApplyPendingCodeBody() async {
    final code = await getPendingCode();
    if (code == null) return null;
    if (!SupabaseService().isAuthenticated) {
      return {'success': false, 'error': 'not_authenticated', 'kept': true};
    }

    var result = await applyCode(code);
    var err = result['error']?.toString();

    // Profile row can lag behind auth.uid() on first signup.
    for (var attempt = 0;
        attempt < 3 && result['success'] != true && err == 'profile_not_ready';
        attempt++) {
      await Future<void>.delayed(Duration(milliseconds: 600 * (attempt + 1)));
      result = await applyCode(code);
      err = result['error']?.toString();
    }

    final ok = result['success'] == true;
    final clear = ok ||
        err == 'already_attributed' ||
        err == 'self_referral' ||
        err == 'invalid_or_inactive_code' ||
        err == 'invalid_code';
    if (clear) {
      await clearPendingCode();
    }
    debugPrint(
      ok
          ? '✅ [Referral] Applied pending code $code'
          : '⚠️ [Referral] Pending apply failed ($err) clear=$clear',
    );
    return result;
  }

  /// Listen for cold/warm invite links (custom scheme + https).
  Future<void> startInviteLinkListener() async {
    if (_linksStarted) return;
    try {
      final appLinks = AppLinks();
      final initial = await appLinks.getInitialLink();
      await captureFromUri(initial);
      // Apply leftover pending codes too (session restore / yesterday's tap).
      unawaited(tryApplyPendingCode());
      await _linkSub?.cancel();
      _linkSub = appLinks.uriLinkStream.listen(
        (uri) async {
          final captured = await captureFromUri(uri);
          if (captured) {
            await tryApplyPendingCode();
          }
        },
        onError: (Object e) {
          debugPrint('❌ [Referral] link stream: $e');
        },
      );
      _linksStarted = true;
    } catch (e) {
      _linksStarted = false;
      debugPrint('❌ [Referral] startInviteLinkListener: $e');
    }
  }

  void disposeLinkListener() {
    unawaited(_linkSub?.cancel());
    _linkSub = null;
    _linksStarted = false;
  }

  Map<String, dynamic> _asMap(dynamic result) {
    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }
    if (result is String && result.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(result);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return {'success': false, 'error': 'unexpected_response'};
  }

  String _errorCode(Object e) {
    final raw = e.toString();
    for (final code in [
      'already_attributed',
      'self_referral',
      'invalid_or_inactive_code',
      'invalid_code',
      'not_authenticated',
      'profile_not_ready',
    ]) {
      if (raw.contains(code)) return code;
    }
    return raw;
  }

  /// Canonical form: `MLQ-XXXXXX` (hyphens/spaces ignored on input).
  String? _normalizeCode(String? raw) {
    if (raw == null) return null;
    final compact =
        raw.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (compact.length < 4) return null;
    if (compact.startsWith('MLQ') && compact.length > 3) {
      return 'MLQ-${compact.substring(3)}';
    }
    return compact;
  }
}
