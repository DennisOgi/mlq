import 'package:intl/intl.dart';

class AppDateUtils {
  // Format date to display day of week and date (e.g., "Monday, Jan 1")
  static String formatDayAndDate(DateTime date) {
    return DateFormat('EEEE, MMM d').format(date);
  }

  // Format date to display month and day (e.g., "Jan 1")
  static String formatMonthAndDay(DateTime date) {
    return DateFormat('MMM d').format(date);
  }

  // Format date to display full date (e.g., "January 1, 2025")
  static String formatFullDate(DateTime date) {
    return DateFormat('MMMM d, yyyy').format(date);
  }

  // Format date to display short date (e.g., "01/01/2025")
  static String formatShortDate(DateTime date) {
    return DateFormat('MM/dd/yyyy').format(date);
  }

  // Format date to display time (e.g., "3:30 PM")
  static String formatTime(DateTime date) {
    return DateFormat('h:mm a').format(date);
  }

  // Format date to display day of week (e.g., "Monday")
  static String formatDayOfWeek(DateTime date) {
    return DateFormat('EEEE').format(date);
  }

  // Format date to display short day of week (e.g., "Mon")
  static String formatShortDayOfWeek(DateTime date) {
    return DateFormat('E').format(date);
  }

  // Get start of day
  static DateTime startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  // Get end of day
  static DateTime endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59);
  }

  // Get start of week (assuming Monday is the first day of the week)
  static DateTime startOfWeek(DateTime date) {
    final day = date.weekday;
    return DateTime(date.year, date.month, date.day - (day - 1));
  }

  // Get end of week (assuming Sunday is the last day of the week)
  static DateTime endOfWeek(DateTime date) {
    final day = date.weekday;
    return DateTime(date.year, date.month, date.day + (7 - day), 23, 59, 59);
  }

  // Get start of month
  static DateTime startOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  // Get end of month
  static DateTime endOfMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0, 23, 59, 59);
  }

  // Check if two dates are the same day
  static bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
  }

  // Check if a date is today
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return isSameDay(date, now);
  }

  // Check if a date is yesterday
  static bool isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return isSameDay(date, yesterday);
  }

  // Check if a date is tomorrow
  static bool isTomorrow(DateTime date) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return isSameDay(date, tomorrow);
  }

  // Get a friendly string for a date (e.g., "Today", "Yesterday", "Tomorrow", or the formatted date)
  static String getFriendlyDateString(DateTime date) {
    if (isToday(date)) {
      return 'Today';
    } else if (isYesterday(date)) {
      return 'Yesterday';
    } else if (isTomorrow(date)) {
      return 'Tomorrow';
    } else {
      return formatDayAndDate(date);
    }
  }

  // Get a relative time string (e.g., "2 hours ago", "5 minutes ago", "Just now")
  // Handles slight clock skew or future timestamps gracefully so "Just now" does
  // not persist for long periods when createdAt is ahead of the device time.
  static String getRelativeTimeString(DateTime date) {
    final now = DateTime.now();
    var difference = now.difference(date);

    // If the timestamp is in the future relative to the device clock, use the
    // absolute difference so that we still show a sensible "X minutes ago"
    // instead of being stuck on "Just now" for hours.
    if (difference.isNegative) {
      difference = date.difference(now);
    }

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else {
      return formatMonthAndDay(date);
    }
  }
}
