import 'package:shared_preferences/shared_preferences.dart';

class BadgeSeenStore {
  static String _key(String userId) => 'seen_badges_names_$userId';

  static Future<Set<String>> _load(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key(userId)) ?? const [];
    return list.toSet();
  }

  static Future<void> _save(String userId, Set<String> names) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key(userId), names.toList());
  }

  static Future<bool> hasSeen(String userId, String badgeName) async {
    final seen = await _load(userId);
    return seen.contains(badgeName);
  }

  static Future<void> markSeen(String userId, String badgeName) async {
    final seen = await _load(userId);
    if (seen.add(badgeName)) {
      await _save(userId, seen);
    }
  }
}
