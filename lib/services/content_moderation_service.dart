import 'package:flutter/foundation.dart';

/// A service for moderating user-generated content to ensure it's appropriate 
/// for children aged 8-14 years.
class ContentModerationService {
  /// Singleton instance
  static final ContentModerationService instance = ContentModerationService._();

  ContentModerationService._();

  /// Comprehensive list of inappropriate words to filter
  /// Expanded for production use with common profanity and variations
  final List<String> _inappropriateWords = [
    // Strong profanity
    'fuck', 'shit', 'damn', 'ass', 'bitch', 'hell',
    'crap', 'bastard', 'piss', 'dick', 'pussy', 'cock',
    'asshole', 'bullshit', 'motherfucker', 'fck', 'wtf',
    // Hate speech and slurs (basic list)
    'nigger', 'nigga', 'faggot', 'retard', 'retarded',
    // Sexual content
    'sex', 'porn', 'nude', 'naked', 'xxx',
    // Violence
    'kill', 'die', 'death', 'suicide', 'murder',
    // Drugs
    'weed', 'cocaine', 'drug', 'drugs', 'meth',
    // Common variations and leetspeak
    'fuk', 'sht', 'btch', 'dmn', 'fck',
  ];

  /// Spam patterns to detect
  final List<RegExp> _spamPatterns = [
    RegExp(r'(.)\1{4,}'), // Repeated characters (e.g., "aaaaa")
    RegExp(r'http[s]?://'), // URLs
    RegExp(r'www\.'), // Web addresses
    RegExp(r'\b[A-Z]{5,}\b'), // ALL CAPS words (5+ letters)
    RegExp(r'(.)\s*\1\s*\1\s*\1\s*\1'), // Spaced repeated chars
  ];

  /// Checks if text contains inappropriate content
  /// Returns null if content is appropriate
  /// Returns a message explaining why the content was rejected if inappropriate
  String? validateContent(String content) {
    if (content.isEmpty) {
      return 'Content cannot be empty.';
    }

    // Check minimum length (prevent single character spam)
    if (content.trim().length < 3) {
      return 'Please write a more meaningful message (at least 3 characters).';
    }

    // Check maximum length
    if (content.length > 500) {
      return 'Your post is too long. Please keep it under 500 characters.';
    }

    // Convert to lowercase for case-insensitive matching
    final lowerContent = content.toLowerCase();

    // Check for spam patterns
    for (final pattern in _spamPatterns) {
      if (pattern.hasMatch(content)) {
        if (pattern.pattern.contains('http') || pattern.pattern.contains('www')) {
          return 'Links are not allowed. Please share your thoughts without URLs.';
        }
        if (pattern.pattern.contains('[A-Z]')) {
          return 'Please don\'t use excessive CAPS. Write naturally!';
        }
        return 'Your message looks like spam. Please write naturally!';
      }
    }

    // Check for inappropriate words
    for (final word in _inappropriateWords) {
      final wordPattern = RegExp(r'\b' + word + r'\b', caseSensitive: false);
      if (wordPattern.hasMatch(lowerContent)) {
        return 'Your post contains inappropriate language. Please remember that '
               'this is a kid-friendly app. 🌟';
      }
    }

    // Check for words with intentional misspellings (like f*ck, s**t, etc.)
    final potentialProfanityPattern = RegExp(r'\b[a-z]*[\*\$\#\@][a-z\*\$\#\@]*\b');
    if (potentialProfanityPattern.hasMatch(lowerContent)) {
      return 'Your post may contain inappropriate language. Please keep it positive! 😊';
    }

    // Check for excessive emojis (more than 10)
    final emojiPattern = RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true);
    final emojiCount = emojiPattern.allMatches(content).length;
    if (emojiCount > 10) {
      return 'Too many emojis! Please use fewer emojis in your post.';
    }

    return null; // Content is appropriate
  }

  /// Filters inappropriate content by replacing it with asterisks
  /// This is a fallback for when we want to allow the content but clean it up
  String filterContent(String content) {
    String filteredContent = content;

    for (final word in _inappropriateWords) {
      final replacement = '*' * word.length;
      final wordPattern = RegExp(r'\b' + word + r'\b', caseSensitive: false);
      filteredContent = filteredContent.replaceAll(wordPattern, replacement);
    }

    return filteredContent;
  }

  /// More advanced check that could use a third-party API for content moderation
  /// (This is a placeholder for future implementation)
  Future<bool> isContentAppropriate(String content) async {
    // For now, use the basic check
    return validateContent(content) == null;
  }

  /// Report inappropriate content for admin review
  Future<void> reportContent(String contentId, String reportReason, String reportedBy) async {
    try {
      // In a real implementation, this would send the report to a database
      // For now, just log it
      debugPrint('Content reported: $contentId by $reportedBy - Reason: $reportReason');
      
      // This would be where we'd store the report in Supabase/Firebase
    } catch (e) {
      debugPrint('Error reporting content: $e');
    }
  }
}
