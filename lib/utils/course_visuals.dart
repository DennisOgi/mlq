import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// Shared mini-course visuals — brand palette only (no rainbow Material colors).
class MlqCourseVisuals {
  MlqCourseVisuals._();

  static const List<Color> palette = [
    AppColors.primary,
    AppColors.primaryDark,
    AppColors.secondary,
    AppColors.tertiary,
    AppColors.accent1,
    AppColors.accent2,
    AppColors.academic,
  ];

  static Color colorFor(String topicOrTitle) {
    final t = topicOrTitle.toLowerCase();

    if (_matches(t, ['leadership', 'influence', 'resilience'])) {
      return AppColors.primary;
    }
    if (_matches(t, [
      'self-discipline',
      'mindset',
      'personal growth',
      'conflict',
    ])) {
      return AppColors.primaryDark;
    }
    if (_matches(t, ['goal', 'motivation', 'productivity', 'time'])) {
      return AppColors.secondary;
    }
    if (_matches(t, ['teamwork', 'decision', 'public speaking'])) {
      return AppColors.tertiary;
    }
    if (_matches(t, ['emotional', 'confidence', 'creativity'])) {
      return AppColors.accent1;
    }
    if (_matches(t, ['problem', 'critical'])) {
      return AppColors.accent2;
    }
    if (_matches(t, ['communication'])) {
      return AppColors.academic;
    }

    final hash = topicOrTitle.hashCode.abs();
    return palette[hash % palette.length];
  }

  static IconData iconFor(String topicOrTitle) {
    final t = topicOrTitle.toLowerCase();
    if (t.contains('leadership')) return Icons.people_rounded;
    if (t.contains('personal growth')) return Icons.trending_up_rounded;
    if (t.contains('confidence')) return Icons.stars_rounded;
    if (t.contains('communication')) return Icons.chat_bubble_rounded;
    if (t.contains('motivation')) return Icons.bolt_rounded;
    if (t.contains('emotional')) return Icons.favorite_rounded;
    if (t.contains('self-discipline')) return Icons.self_improvement_rounded;
    if (t.contains('mindset')) return Icons.psychology_rounded;
    if (t.contains('productivity')) return Icons.speed_rounded;
    if (t.contains('creativity')) return Icons.brush_rounded;
    if (t.contains('goal')) return Icons.flag_rounded;
    if (t.contains('decision')) return Icons.how_to_vote_rounded;
    if (t.contains('resilience')) return Icons.shield_rounded;
    if (t.contains('problem')) return Icons.lightbulb_rounded;
    if (t.contains('influence')) return Icons.campaign_rounded;
    if (t.contains('time')) return Icons.schedule_rounded;
    if (t.contains('conflict')) return Icons.handshake_rounded;
    if (t.contains('teamwork')) return Icons.group_work_rounded;
    if (t.contains('public speaking')) return Icons.record_voice_over_rounded;
    if (t.contains('critical')) return Icons.psychology_alt_rounded;
    return Icons.school_rounded;
  }

  static const String _coverDir = 'assets/images/ui/covers';

  /// Who is pictured. Used so boys see boy art and girls see girl art.
  /// `mixed` (e.g. two students talking) is fine for everyone.
  static const Map<String, String> _pictured = {
    'health': 'female', // jogging girl
    'goal_health': 'male', // boy stretching
    'goal_health_girl': 'female',
    'goal_health_boy': 'male',
    'goal_academic': 'female',
    'goal_academic_girl': 'female',
    'goal_academic_boy': 'male',
    'goal_social_girls': 'female',
    'goal_social_boys': 'male',
    'leadership': 'male',
    'planning': 'male',
    'thinking': 'male',
    'mindset': 'female',
    'emotions': 'female',
    'resilience': 'female',
    'communication': 'mixed',
  };

  // Order matters: first match wins (health before "time"/"screen" etc.).
  static const List<MapEntry<String, List<String>>> _coverRules = [
    MapEntry('health', [
      'handwash', 'teeth', 'smile', 'water', 'thirst', 'soda', 'juice',
      'rainbow', 'snack', 'breakfast', 'protein', 'sugar', 'sleep', 'rest',
      'screen', 'move', 'posture', 'health', 'hydrat', 'hygiene', 'fitness',
      'exercise',
    ]),
    MapEntry('leadership', ['lead', 'influence', 'vision']),
    MapEntry('planning', [
      'goal', 'time', 'productiv', 'focus', 'concentrat', 'discipline',
      'habit', 'accountab', 'organi', 'responsib', 'new year', 'holiday',
      'back to school', 'fresh start',
    ]),
    MapEntry('communication', [
      'communicat', 'listen', 'speak', 'voice', 'team', 'collab',
      'conflict', 'respect', 'inclusion', 'friend', 'boundar',
    ]),
    MapEntry('emotions', [
      'emotion', 'empathy', 'gratitude', 'apprecia', 'stress', 'calm',
      'breathe', 'kind',
    ]),
    MapEntry('resilience', [
      'resilien', 'bounc', 'adapt', 'new things', 'peer pressure',
    ]),
    MapEntry('thinking', [
      'decision', 'problem', 'creativ', 'critical', 'choice', 'honest',
      'integrity',
    ]),
    MapEntry('mindset', [
      'mindset', 'motivat', 'confiden', 'growth', 'identity', 'purpose',
      'celebrat', 'self-advoca', 'learning',
    ]),
  ];

  /// Topic → covers in that scene family. Gendered variants plus the
  /// canonical topic art so a 3-course day can show three different pictures
  /// without jumping to an unrelated topic.
  static const Map<String, List<String>> _coverPools = {
    'health': [
      'health',
      'goal_health',
      'goal_health_girl',
      'goal_health_boy',
      'resilience',
    ],
    'leadership': [
      'leadership',
      'goal_social_boys',
      'goal_social_girls',
      'communication',
    ],
    'planning': [
      'planning',
      'goal_academic',
      'goal_academic_boy',
      'goal_academic_girl',
    ],
    'communication': [
      'communication',
      'goal_social_boys',
      'goal_social_girls',
      'emotions',
    ],
    'emotions': [
      'emotions',
      'mindset',
      'goal_social_girls',
      'communication',
    ],
    'resilience': [
      'resilience',
      'mindset',
      'health',
      'goal_health_girl',
    ],
    'thinking': [
      'thinking',
      'planning',
      'goal_academic_boy',
      'goal_academic',
    ],
    'mindset': [
      'mindset',
      'resilience',
      'emotions',
      'goal_academic_girl',
    ],
  };

  static const Map<String, List<String>> _goalPools = {
    'academic': ['goal_academic', 'goal_academic_girl', 'goal_academic_boy'],
    'social': ['goal_social_girls', 'goal_social_boys'],
    'health': ['goal_health', 'goal_health_girl', 'goal_health_boy'],
  };

  static bool _isFemaleAsset(String name) => _pictured[name] == 'female';
  static bool _isMaleAsset(String name) => _pictured[name] == 'male';

  /// Prefer art matching [gender]. Never show the opposite gender.
  /// When gender is unknown, keep the full pool so a same-topic trio
  /// still gets distinct pictures.
  static List<String> _forGender(List<String> pool, String? gender) {
    final g = (gender ?? '').toLowerCase();
    final wantFemale = g == 'female' || g == 'girl' || g == 'f';
    final wantMale = g == 'male' || g == 'boy' || g == 'm';
    if (!wantFemale && !wantMale) return List<String>.from(pool);

    return pool.where((p) {
      if (wantFemale) return !_isMaleAsset(p);
      return !_isFemaleAsset(p);
    }).toList();
  }

  /// Put title-relevant covers first so water stories get the bottle art,
  /// habit stories get planning, etc. Remaining pool items still fill unique slots.
  static List<String> _preferForText(List<String> pool, String text) {
    final t = text.toLowerCase();
    final preferred = <String>[];
    void take(List<String> names) {
      for (final n in names) {
        if (pool.contains(n) && !preferred.contains(n)) preferred.add(n);
      }
    }

    if (_matches(t, ['water', 'thirst', 'soda', 'juice', 'hydrat'])) {
      take(['goal_health_girl', 'goal_health_boy', 'goal_health', 'health']);
    } else if (_matches(t, ['protein', 'breakfast', 'snack', 'sugar', 'food'])) {
      take(['health', 'goal_health', 'goal_health_boy', 'goal_health_girl']);
    } else if (_matches(t, ['handwash', 'teeth', 'smile', 'hygiene'])) {
      take(['planning', 'health', 'goal_health']);
    } else if (_matches(t, ['move', 'posture', 'exercise', 'fitness', 'sleep'])) {
      take(['health', 'resilience', 'goal_health', 'goal_health_boy']);
    } else if (_matches(t, ['lead', 'influence', 'vision'])) {
      take(['leadership', 'goal_social_boys', 'goal_social_girls']);
    } else if (_matches(t, ['communicat', 'listen', 'team', 'friend'])) {
      take(['communication', 'goal_social_girls', 'goal_social_boys']);
    } else if (_matches(t, ['mindset', 'motivat', 'confiden'])) {
      take(['mindset', 'resilience', 'thinking']);
    } else if (_matches(t, ['decision', 'problem', 'creativ', 'critical'])) {
      take(['thinking', 'planning', 'goal_academic_boy']);
    } else if (_matches(t, ['goal', 'habit', 'time', 'productiv'])) {
      take(['planning', 'goal_academic', 'goal_academic_boy', 'goal_academic_girl']);
    }

    final rest = pool.where((p) => !preferred.contains(p));
    return [...preferred, ...rest];
  }

  static String _pick(List<String> pool, int? seed, {String? gender, String? text}) {
    var filtered = _forGender(pool, gender);
    if (filtered.isEmpty) filtered = List<String>.from(pool);
    if (text != null && text.isNotEmpty) {
      filtered = _preferForText(filtered, text);
    }
    return '$_coverDir/${filtered[(seed ?? 0).abs() % filtered.length]}.webp';
  }

  static int seedOf(String value) {
    var h = 0;
    for (final c in value.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h;
  }

  static String? _topicKey(String topicOrTitle) {
    final t = topicOrTitle.toLowerCase();
    for (final rule in _coverRules) {
      if (_matches(t, rule.value)) return rule.key;
    }
    return null;
  }

  /// Cover illustration for a course topic/title, or null when no key matches.
  static String? coverFor(String topicOrTitle, {int? seed, String? gender}) {
    final key = _topicKey(topicOrTitle);
    if (key == null) return null;
    return _pick(
      _coverPools[key]!,
      seed,
      gender: gender,
      text: topicOrTitle,
    );
  }

  static String? coverForAny(
    Iterable<String> candidates, {
    int? seed,
    String? gender,
  }) {
    for (final c in candidates) {
      final path = coverFor(c, seed: seed, gender: gender);
      if (path != null) return path;
    }
    return null;
  }

  /// Cover for a mini course. Daily ids end in `_course_<i>`, so the index
  /// picks a unique picture from the topic pool.
  static String? courseCover(
    String id,
    String topic,
    String title, {
    String? gender,
  }) {
    final m = RegExp(r'^(.*)_course_(\d+)$').firstMatch(id);
    final seed = m != null ? int.parse(m.group(2)!) : seedOf(id);
    final key = _topicKey(topic) ?? _topicKey(title);
    if (key == null) return null;
    return _pick(
      _coverPools[key]!,
      seed,
      gender: gender,
      text: '$topic $title',
    );
  }

  static String goalCoverFor(String category, {String? seed, String? gender}) {
    final pool = _goalPools[category.toLowerCase()] ?? _goalPools['health']!;
    return _pick(pool, seed == null ? 0 : seedOf(seed), gender: gender);
  }

  static bool _matches(String haystack, List<String> needles) {
    for (final n in needles) {
      if (haystack.contains(n)) return true;
    }
    return false;
  }
}
