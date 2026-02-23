import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/mini_course_model.dart';

class AiCourseGeneratorService {
  static final AiCourseGeneratorService _instance = AiCourseGeneratorService._internal();
  factory AiCourseGeneratorService() => _instance;
  static AiCourseGeneratorService get instance => _instance;
  
  AiCourseGeneratorService._internal();
  
  final Uuid _uuid = const Uuid();
  
  // Gemini API configuration
  final String _apiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent';
  String? _apiKey;
  
  // Simple client-side rate limiter to avoid 429s
  // Enforce a minimum interval between requests (free tier ~15 RPM => ~4s/request)
  final Duration _minInterval = const Duration(seconds: 5);
  DateTime? _lastRequestTime;
  Future<void> _queue = Future.value();
  
  // Optional simple cache (by topic/age/difficulty) to avoid duplicate calls
  final Map<String, MiniCourseModel> _courseCache = {};
  
  // Available topics for course generation
  static const List<String> _availableTopics = [
    'Goal Setting',
    'Leadership Skills',
    'Teamwork',
    'Communication',
    'Time Management',
    'Problem Solving',
    'Emotional Intelligence',
    'Public Speaking',
    'Decision Making',
    'Conflict Resolution',
    'Creativity',
    'Self-Confidence',
  ];
  
  /// Initialize with API key
  void initialize(String apiKey) {
    _apiKey = apiKey;
    debugPrint('✅ AI Course Generator service initialized');
    debugPrint('✅ API Key length: ${apiKey.length}');
    debugPrint('✅ API Key preview: ${apiKey.length > 20 ? apiKey.substring(0, 20) + "..." : apiKey}');
  }
  
  /// Generate multiple mini-courses with random topics
  Future<List<MiniCourseModel>> generateMiniCourses({
    int count = 5,
    int targetAge = 12,
    String difficultyLevel = 'beginner',
  }) async {
    try {
      final List<MiniCourseModel> courses = [];
      final usedTopics = <String>{};
      
      for (int i = 0; i < count; i++) {
        // Select a random topic that hasn't been used yet
        String selectedTopic;
        int attempts = 0;
        do {
          selectedTopic = _availableTopics[Random().nextInt(_availableTopics.length)];
          attempts++;
        } while (usedTopics.contains(selectedTopic) && attempts < 20);
        
        usedTopics.add(selectedTopic);
        
        debugPrint('Generating course ${i + 1}/$count: $selectedTopic');
        
        final course = await generateCourse(
          topic: selectedTopic,
          targetAge: targetAge,
          difficultyLevel: difficultyLevel,
        );
        
        if (course != null) {
          courses.add(course);
        }
      }
      
      debugPrint('Generated ${courses.length} mini-courses successfully');
      return courses;
      
    } catch (e) {
      debugPrint('Error generating mini-courses: $e');
      return _getFallbackCourses();
    }
  }
  
  /// Generate a single mini-course for a specific topic
  Future<MiniCourseModel?> generateCourse({
    required String topic,
    int targetAge = 12,
    String difficultyLevel = 'beginner',
  }) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      debugPrint('❌ AI Course Generator: API key is null or empty');
      debugPrint('⚠️ Using fallback course for: $topic');
      return _getFallbackCourse(topic);
    }
    
    try {
      // Cache key to deduplicate rapid repeat requests
      final cacheKey = '$topic|$targetAge|$difficultyLevel';
      if (_courseCache.containsKey(cacheKey)) {
        return _courseCache[cacheKey];
      }
      
      final prompt = _buildCourseGenerationPrompt(topic, targetAge, difficultyLevel);
      final response = await _enqueue(() => _makeApiCall(prompt));
      
      if (response != null) {
        final parsed = _parseCourseFromResponse(response, topic);
        if (parsed != null) {
          _courseCache[cacheKey] = parsed;
        }
        return parsed;
      } else {
        return _getFallbackCourse(topic);
      }
      
    } catch (e) {
      debugPrint('❌ Error generating course for $topic: $e');
      debugPrint('❌ API Key present: ${_apiKey != null}');
      debugPrint('⚠️ Using fallback course');
      return _getFallbackCourse(topic);
    }
  }
  
  /// Enqueue tasks to ensure a minimum spacing between API requests
  Future<T> _enqueue<T>(Future<T> Function() task) async {
    // Chain onto the queue to serialize
    final previous = _queue;
    final completer = Completer<void>();
    _queue = previous.then((_) => completer.future);
    
    try {
      await previous;
      // Enforce min interval
      final now = DateTime.now();
      if (_lastRequestTime != null) {
        final elapsed = now.difference(_lastRequestTime!);
        if (elapsed < _minInterval) {
          final wait = _minInterval - elapsed;
          debugPrint('AI Course Generator: rate limiting, waiting ${wait.inMilliseconds}ms');
          await Future.delayed(wait);
        }
      }
      _lastRequestTime = DateTime.now();
      return await task();
    } finally {
      completer.complete();
    }
  }
  
  /// Build the AI prompt for course generation
  String _buildCourseGenerationPrompt(String topic, int targetAge, String difficultyLevel) {
    return '''
Generate a leadership mini-course for kids aged $targetAge on the topic: "$topic"

Requirements:
- Course should be appropriate for $difficultyLevel level
- Target age: $targetAge years old
- Focus on leadership development and personal growth
- Use encouraging, age-appropriate language
- Include practical examples kids can relate to

Course Structure:
1. Course Title: Creative and engaging title
2. Course Description: 2-3 sentences explaining what kids will learn
3. 4 Lessons: Each lesson should have:
   - Lesson title
   - Lesson content (2-3 paragraphs)
   - 3 key takeaways
4. Quiz: 5 multiple choice questions with:
   - Question text
   - 4 answer options
   - Correct answer index (0-3)

Format your response as valid JSON with this exact structure:
{
  "title": "Course Title Here",
  "description": "Course description here",
  "lessons": [
    {
      "title": "Lesson 1 Title",
      "content": "Lesson content here...",
      "keyTakeaways": ["Takeaway 1", "Takeaway 2", "Takeaway 3"]
    },
    {
      "title": "Lesson 2 Title", 
      "content": "Lesson content here...",
      "keyTakeaways": ["Takeaway 1", "Takeaway 2", "Takeaway 3"]
    },
    {
      "title": "Lesson 3 Title",
      "content": "Lesson content here...", 
      "keyTakeaways": ["Takeaway 1", "Takeaway 2", "Takeaway 3"]
    },
    {
      "title": "Lesson 4 Title",
      "content": "Lesson content here...",
      "keyTakeaways": ["Takeaway 1", "Takeaway 2", "Takeaway 3"]
    }
  ],
  "quiz": {
    "title": "Test Your Knowledge",
    "description": "Let's see what you learned!",
    "questions": [
      {
        "text": "Question 1 text?",
        "options": ["Option A", "Option B", "Option C", "Option D"],
        "correctAnswerIndex": 0
      },
      {
        "text": "Question 2 text?", 
        "options": ["Option A", "Option B", "Option C", "Option D"],
        "correctAnswerIndex": 1
      },
      {
        "text": "Question 3 text?",
        "options": ["Option A", "Option B", "Option C", "Option D"], 
        "correctAnswerIndex": 2
      },
      {
        "text": "Question 4 text?",
        "options": ["Option A", "Option B", "Option C", "Option D"],
        "correctAnswerIndex": 0
      },
      {
        "text": "Question 5 text?",
        "options": ["Option A", "Option B", "Option C", "Option D"],
        "correctAnswerIndex": 3
      }
    ]
  }
}

Generate the course content now:
''';
  }
  
  /// Make API call to Gemini
  Future<String?> _makeApiCall(String prompt) async {
    try {
      final requestBody = {
        'contents': [
          {
            'role': 'user',
            'parts': [{'text': prompt}]
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'topK': 40,
          'topP': 0.95,
          'maxOutputTokens': 2048,
        },
        'safetySettings': [
          {
            'category': 'HARM_CATEGORY_HARASSMENT',
            'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
          },
          {
            'category': 'HARM_CATEGORY_HATE_SPEECH',
            'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
          },
          {
            'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
            'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
          },
          {
            'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
            'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
          }
        ]
      };
      
      final response = await _postWithRetry(
        Uri.parse('$_apiUrl?key=$_apiKey'),
        headers: const {
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
        attempts: 3,
        timeout: const Duration(seconds: 25),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          final content = data['candidates'][0]['content']['parts'][0]['text'];
          return content?.toString();
        } else {
          debugPrint('AI Course Generator: No candidates in response');
          return null;
        }
      } else {
        debugPrint('AI Course Generator: API call failed with status ${response.statusCode}');
        debugPrint('AI Course Generator: Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('AI Course Generator: Error making API call: $e');
      return null;
    }
  }

  // Simple POST with retry and exponential backoff
  Future<http.Response> _postWithRetry(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
    int attempts = 3,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    int tryCount = 0;
    late Object lastError;
    while (tryCount < attempts) {
      try {
        final resp = await http
            .post(uri, headers: headers, body: body)
            .timeout(timeout);
        // If success, return
        if (resp.statusCode == 200) {
          return resp;
        }
        // Handle rate limit/service unavailable with backoff and optional Retry-After
        if (resp.statusCode == 429 || resp.statusCode == 503) {
          tryCount++;
          if (tryCount >= attempts) {
            return resp; // give up and return last response
          }
          // Parse Retry-After header (seconds)
          final retryAfterHeader = resp.headers['retry-after'];
          Duration wait;
          if (retryAfterHeader != null) {
            final seconds = int.tryParse(retryAfterHeader.trim());
            if (seconds != null && seconds > 0) {
              wait = Duration(seconds: seconds);
            } else {
              // Exponential backoff with jitter
              final baseMs = 800 * (1 << (tryCount - 1)); // 800, 1600, 3200
              final jitter = Random().nextInt(250);
              wait = Duration(milliseconds: baseMs + jitter);
            }
          } else {
            final baseMs = 800 * (1 << (tryCount - 1));
            final jitter = Random().nextInt(250);
            wait = Duration(milliseconds: baseMs + jitter);
          }
          debugPrint('AI Course Generator: Received ${resp.statusCode}. Retrying in ${wait.inMilliseconds}ms (attempt $tryCount/$attempts)');
          await Future.delayed(wait);
          // Loop to retry
          continue;
        }
        // Non-retryable status, return immediately
        return resp;
      } catch (e) {
        lastError = e;
        tryCount++;
        final waitMs = 400 * (1 << (tryCount - 1));
        debugPrint('AI Course Generator: POST attempt $tryCount failed: $e. Retrying in ${waitMs}ms');
        if (tryCount >= attempts) break;
        await Future.delayed(Duration(milliseconds: waitMs));
      }
    }
    if (lastError is TimeoutException) {
      throw lastError;
    }
    throw Exception('POST to $uri failed after $attempts attempts: $lastError');
  }
  
  /// Parse course from AI response
  MiniCourseModel? _parseCourseFromResponse(String response, String topic) {
    try {
      // Extract JSON from response (in case there's extra text)
      String jsonString = response;
      final jsonStart = response.indexOf('{');
      final jsonEnd = response.lastIndexOf('}');
      
      if (jsonStart != -1 && jsonEnd != -1) {
        jsonString = response.substring(jsonStart, jsonEnd + 1);
      }
      
      final courseData = json.decode(jsonString);
      
      // Parse lessons
      final List<MiniCourseLessonModel> lessons = [];
      if (courseData['lessons'] != null) {
        for (final lessonData in courseData['lessons']) {
          lessons.add(MiniCourseLessonModel(
            id: _uuid.v4(),
            title: lessonData['title'] ?? 'Lesson',
            content: lessonData['content'] ?? '',
            keyTakeaways: List<String>.from(lessonData['keyTakeaways'] ?? []),
            isCompleted: false,
          ));
        }
      }
      
      // Parse quiz
      final List<MiniCourseQuizQuestionModel> questions = [];
      if (courseData['quiz'] != null && courseData['quiz']['questions'] != null) {
        for (final questionData in courseData['quiz']['questions']) {
          questions.add(MiniCourseQuizQuestionModel(
            id: _uuid.v4(),
            text: questionData['text'] ?? '',
            options: List<String>.from(questionData['options'] ?? []),
            correctAnswerIndex: questionData['correctAnswerIndex'] ?? 0,
            selectedOptionIndex: null,
          ));
        }
      }
      
      final quiz = MiniCourseQuizModel(
        id: _uuid.v4(),
        title: courseData['quiz']?['title'] ?? 'Quiz',
        description: courseData['quiz']?['description'] ?? 'Test your knowledge!',
        questions: questions,
        isCompleted: false,
        score: null,
      );
      
      return MiniCourseModel(
        id: _uuid.v4(),
        title: courseData['title'] ?? '$topic Course',
        description: courseData['description'] ?? 'Learn about $topic',
        lessons: lessons,
        quiz: quiz,
        status: MiniCourseStatus.notStarted,
        currentLessonIndex: 0,
      );
      
    } catch (e) {
      debugPrint('Error parsing course response: $e');
      return _getFallbackCourse(topic);
    }
  }
  
  /// Get fallback course when AI generation fails
  MiniCourseModel _getFallbackCourse(String topic) {
    final lessons = [
      MiniCourseLessonModel(
        id: _uuid.v4(),
        title: 'Introduction to $topic',
        content: 'Welcome to this course on $topic! This is an essential leadership skill that will help you grow and succeed.',
        keyTakeaways: [
          '$topic is important for leaders',
          'Practice makes perfect',
          'Start with small steps'
        ],
        isCompleted: false,
      ),
      MiniCourseLessonModel(
        id: _uuid.v4(),
        title: 'Understanding $topic',
        content: 'Let\'s dive deeper into $topic and understand why it matters for young leaders like you.',
        keyTakeaways: [
          'Understanding is the first step',
          'Apply what you learn',
          'Share with others'
        ],
        isCompleted: false,
      ),
    ];
    
    final quiz = MiniCourseQuizModel(
      id: _uuid.v4(),
      title: '$topic Quiz',
      description: 'Test your knowledge about $topic!',
      questions: [
        MiniCourseQuizQuestionModel(
          id: _uuid.v4(),
          text: 'What is the most important aspect of $topic?',
          options: ['Practice', 'Understanding', 'Sharing', 'All of the above'],
          correctAnswerIndex: 3,
          selectedOptionIndex: null,
        ),
      ],
      isCompleted: false,
      score: null,
    );
    
    return MiniCourseModel(
      id: _uuid.v4(),
      title: '$topic for Young Leaders',
      description: 'Learn the fundamentals of $topic and how to apply them in your leadership journey.',
      lessons: lessons,
      quiz: quiz,
      status: MiniCourseStatus.notStarted,
      currentLessonIndex: 0,
    );
  }
  
  /// Get fallback courses when generation completely fails
  List<MiniCourseModel> _getFallbackCourses() {
    return [
      _getFallbackCourse('Goal Setting'),
      _getFallbackCourse('Leadership Skills'),
      _getFallbackCourse('Teamwork'),
      _getFallbackCourse('Communication'),
      _getFallbackCourse('Self-Confidence'),
    ];
  }
  
  /// Generate a community mini-course based on user description
  /// Returns a map with title, topic, summary, and content for community courses
  Future<Map<String, dynamic>?> generateCommunityMiniCourse({
    required String description,
    String? communityName,
    String? category,
  }) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      debugPrint('❌ AI Course Generator: API key is null or empty');
      return null;
    }
    
    try {
      final prompt = _buildCommunityCoursePrompt(description, communityName, category);
      final response = await _enqueue(() => _makeApiCall(prompt));
      
      if (response != null) {
        return _parseCommunityCourseFromResponse(response);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error generating community course: $e');
      return null;
    }
  }
  
  /// Build prompt for community course generation
  String _buildCommunityCoursePrompt(String description, String? communityName, String? category) {
    final communityContext = communityName != null 
        ? 'This course is for a community called "$communityName"${category != null ? ' (category: $category)' : ''}.'
        : '';
    
    return '''
Generate a mini-course for a community based on this description:
"$description"

$communityContext

Requirements:
- Create engaging, educational content
- Use clear, accessible language
- Focus on practical takeaways
- Keep content concise but valuable (suitable for a daily lesson)

Generate the course with this exact JSON structure:
{
  "title": "An engaging course title",
  "topic": "The main topic/theme",
  "summary": "A 1-2 sentence summary of what learners will gain",
  "content": [
    {
      "type": "text",
      "content": "First paragraph of the lesson content. Make it engaging and informative."
    },
    {
      "type": "text",
      "content": "Second paragraph with more details, examples, or practical tips."
    },
    {
      "type": "text",
      "content": "Third paragraph with key takeaways or action items."
    }
  ]
}

Generate the course now:
''';
  }
  
  /// Parse community course from AI response
  Map<String, dynamic>? _parseCommunityCourseFromResponse(String response) {
    try {
      String jsonString = response;
      final jsonStart = response.indexOf('{');
      final jsonEnd = response.lastIndexOf('}');
      
      if (jsonStart != -1 && jsonEnd != -1) {
        jsonString = response.substring(jsonStart, jsonEnd + 1);
      }
      
      final data = json.decode(jsonString) as Map<String, dynamic>;
      
      // Validate required fields
      if (data['title'] == null || data['content'] == null) {
        debugPrint('AI Course Generator: Missing required fields in response');
        return null;
      }
      
      return {
        'title': data['title'] as String,
        'topic': data['topic'] as String? ?? 'Community Lesson',
        'summary': data['summary'] as String?,
        'content': data['content'] as List<dynamic>,
      };
    } catch (e) {
      debugPrint('Error parsing community course response: $e');
      return null;
    }
  }
}
