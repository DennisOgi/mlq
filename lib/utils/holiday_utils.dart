import 'package:flutter/material.dart';

class HolidayUtils {
  /// Returns a holiday-specific greeting if today is a holiday, otherwise null.
  static String? getHolidayGreeting() {
    final now = DateTime.now();
    final month = now.month;
    final day = now.day;

    // Global Holidays
    if (month == 1 && day == 1) return '🎆 Happy New Year';
    if (month == 2 && day == 14) return '❤️ Happy Valentine\'s Day';
    if (month == 5 && day == 1) return '👷 Happy Workers\' Day';
    if (month == 12 && day == 25) return '🎄 Merry Christmas';
    if (month == 12 && day == 26) return '🎁 Happy Boxing Day';

    // Nigerian Holidays
    if (month == 5 && day == 27) return '🎈 Happy Children\'s Day';
    if (month == 6 && day == 12) return '🇳🇬 Happy Democracy Day';
    if (month == 10 && day == 1) return '🇳🇬 Happy Independence Day';

    return null;
  }

  /// Returns a holiday-specific subtitle if today/soon is a holiday, otherwise null.
  static String? getHolidaySubtitle() {
    final now = DateTime.now();
    final month = now.month;
    final day = now.day;
    final year = now.year;
    
    final christmas = DateTime(year, 12, 25);
    final newYear = DateTime(year + (month == 12 ? 1 : 0), 1, 1);

    // Nigerian Holidays
    if (month == 5 && day == 27) {
      return 'Today is your special day! Keep dreaming big and leading the way! ✨';
    }
    if (month == 6 && day == 12) {
      return 'Celebrating our freedom and democracy! Keep leading with purpose.';
    }
    if (month == 10 && day == 1) {
      return 'Happy Independence! You are the future of this great nation.';
    }

    // Christmas Period
    if (month == 12 && day == 25) {
      return '🎁 Merry Christmas! Enjoy this special day!';
    }
    
    // Days until Christmas (Dec 1 - Dec 24)
    if (month == 12 && day < 25) {
      final daysUntil = christmas.difference(now).inDays;
      if (daysUntil == 1) {
        return '🎅 Christmas Eve! The magic is almost here!';
      }
      return '🎄 $daysUntil days until Christmas! Keep spreading joy!';
    }
    
    // After Christmas, before New Year
    if (month == 12 && day > 25) {
      final daysUntil = newYear.difference(now).inDays;
      if (daysUntil == 1) {
        return '✨ New Year\'s Eve! Get ready for a fresh start!';
      }
      return '✨ $daysUntil days until the New Year! Finish strong!';
    }
    
    // New Year's Day
    if (month == 1 && day == 1) {
      return '🎆 Happy New Year! A fresh start awaits!';
    }
    
    // January (New Year period)
    if (month == 1 && day <= 12) {
      return '🌟 New year, new goals! Make this year amazing!';
    }

    // Valentine's Day
    if (month == 2 && day == 14) {
      return 'Spread love and kindness today! ❤️';
    }
    
    // Workers' Day
    if (month == 5 && day == 1) {
      return 'Celebrating hard work and dedication! Keep striving for greatness.';
    }

    return null;
  }
}
