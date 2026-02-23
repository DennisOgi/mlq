import 'package:flutter/foundation.dart';

enum MiniCourseStatus {
  notStarted,
  inProgress,
  completed,
}

class MiniCourseModel {
  final String id;
  final String title;
  final String description;
  final String topic; // Topic field for server-generated courses
  final List<MiniCourseLessonModel> lessons;
  final MiniCourseQuizModel quiz;
  final MiniCourseStatus status;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int currentLessonIndex;

  MiniCourseModel({
    required this.id,
    required this.title,
    required this.description,
    String? topic,
    required this.lessons,
    required this.quiz,
    this.status = MiniCourseStatus.notStarted,
    this.startedAt,
    this.completedAt,
    this.currentLessonIndex = 0,
  }) : topic = topic ?? title; // Default to title if topic not provided

  // Check if all lessons are completed
  bool get allLessonsCompleted {
    return lessons.every((lesson) => lesson.isCompleted);
  }

  MiniCourseModel copyWith({
    String? id,
    String? title,
    String? description,
    String? topic,
    List<MiniCourseLessonModel>? lessons,
    MiniCourseQuizModel? quiz,
    MiniCourseStatus? status,
    DateTime? startedAt,
    DateTime? completedAt,
    int? currentLessonIndex,
  }) {
    return MiniCourseModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      topic: topic ?? this.topic,
      lessons: lessons ?? this.lessons,
      quiz: quiz ?? this.quiz,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      currentLessonIndex: currentLessonIndex ?? this.currentLessonIndex,
    );
  }

  // Generate a random mini-course based on a topic
  static MiniCourseModel generateFromTopic(String topic) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final title = 'Mini-Course: $topic';
    final description = 'Learn the essentials of $topic in this short mini-course designed for young leaders.';
    
    // Generate 3 lessons based on the topic
    final lessons = <MiniCourseLessonModel>[];
    
    if (topic == 'Goal Setting') {
      lessons.add(MiniCourseLessonModel(
        id: '${id}_1',
        title: 'The SMART Goal Framework',
        content: 'SMART goals are Specific, Measurable, Achievable, Relevant, and Time-bound. This framework helps you create goals that are clear and reachable.\n\n'
            'Specific: Your goal should be clear and specific. Instead of "I want to be a better leader," try "I want to improve my communication skills by practicing active listening."\n\n'
            'Measurable: You should be able to track your progress. For example, "I will practice active listening in three conversations per day."\n\n'
            'Achievable: Your goal should be realistic. Make sure it\'s something you can actually accomplish.\n\n'
            'Relevant: The goal should matter to you and align with your other goals.\n\n'
            'Time-bound: Set a deadline. "I will practice active listening for the next two weeks."',
      ));
      
      lessons.add(MiniCourseLessonModel(
        id: '${id}_2',
        title: 'Breaking Down Big Goals',
        content: 'Big goals can feel overwhelming. Breaking them down into smaller steps makes them more manageable.\n\n'
            '1. Start with your big goal\n'
            '2. Identify the major steps needed to achieve it\n'
            '3. Break each major step into smaller tasks\n'
            '4. Arrange these tasks in order\n'
            '5. Set deadlines for each task\n\n'
            'For example, if your goal is to give a presentation to your class:\n'
            '- Step 1: Choose a topic (by Monday)\n'
            '- Step 2: Research the topic (by Wednesday)\n'
            '- Step 3: Create an outline (by Friday)\n'
            '- Step 4: Make visual aids (by next Monday)\n'
            '- Step 5: Practice your presentation (by next Wednesday)\n'
            '- Step 6: Give your presentation (next Friday)',
      ));
      
      lessons.add(MiniCourseLessonModel(
        id: '${id}_3',
        title: 'Tracking Your Progress',
        content: 'Tracking your progress helps you stay motivated and make adjustments if needed.\n\n'
            'Ways to track progress:\n'
            '- Keep a journal\n'
            '- Use a calendar or chart\n'
            '- Take photos of your work\n'
            '- Share updates with a friend\n'
            '- Use the My Leadership Quest app!\n\n'
            'Remember to celebrate small wins along the way. Each completed task brings you closer to your goal!',
      ));
    } else if (topic == 'Leadership Skills') {
      lessons.add(MiniCourseLessonModel(
        id: '${id}_1',
        title: 'Communication Skills',
        content: 'Good leaders are great communicators. They know how to express their ideas clearly and listen to others.\n\n'
            'Key communication skills:\n'
            '- Active listening: Pay full attention to the speaker, ask questions, and avoid interrupting\n'
            '- Clear speaking: Use simple language and check that others understand you\n'
            '- Body language: Make eye contact, use appropriate gestures, and stand tall\n'
            '- Empathy: Try to understand how others feel\n\n'
            'Practice: The next time you talk with a friend, focus on listening more than speaking. Ask questions to show you\'re interested in what they\'re saying.',
      ));
      
      lessons.add(MiniCourseLessonModel(
        id: '${id}_2',
        title: 'Decision Making',
        content: 'Leaders make decisions every day. Good decision-making involves gathering information, considering options, and taking action.\n\n'
            'Steps for making good decisions:\n'
            '1. Define the problem or opportunity\n'
            '2. Gather information\n'
            '3. Identify possible solutions\n'
            '4. Evaluate each option (pros and cons)\n'
            '5. Choose the best option\n'
            '6. Take action\n'
            '7. Reflect on the results\n\n'
            'Remember, not making a decision is actually making a decision to do nothing!',
      ));
      
      lessons.add(MiniCourseLessonModel(
        id: '${id}_3',
        title: 'Leading by Example',
        content: 'Great leaders don\'t just tell others what to do—they show them through their own actions.\n\n'
            'Ways to lead by example:\n'
            '- Be honest and keep your promises\n'
            '- Take responsibility for your mistakes\n'
            '- Show respect to everyone\n'
            '- Work hard and do your best\n'
            '- Be positive and enthusiastic\n'
            '- Help others when they need it\n\n'
            'Remember: People are more likely to follow what you do than what you say.',
      ));
    } else if (topic == 'Teamwork') {
      lessons.add(MiniCourseLessonModel(
        id: '${id}_1',
        title: 'Understanding Team Roles',
        content: 'Every team member brings different strengths to the group. Understanding these roles helps teams work better together.\n\n'
            'Common team roles:\n'
            '- Leader: Guides the team and keeps everyone focused on goals\n'
            '- Idea person: Comes up with creative solutions and new approaches\n'
            '- Organizer: Keeps track of tasks and makes sure things get done\n'
            '- Encourager: Supports team members and keeps spirits high\n'
            '- Questioner: Asks important questions and helps the team think critically\n\n'
            'You might be good at more than one role, and your role might change depending on the team or project.',
      ));
      
      lessons.add(MiniCourseLessonModel(
        id: '${id}_2',
        title: 'Effective Communication in Teams',
        content: 'Clear communication is essential for teamwork. It helps prevent misunderstandings and keeps everyone on the same page.\n\n'
            'Tips for team communication:\n'
            '- Listen to everyone\'s ideas\n'
            '- Share information openly\n'
            '- Be clear about who is doing what\n'
            '- Give constructive feedback\n'
            '- Address conflicts early\n'
            '- Celebrate successes together\n\n'
            'Remember: Good communication involves both talking AND listening.',
      ));
      
      lessons.add(MiniCourseLessonModel(
        id: '${id}_3',
        title: 'Resolving Team Conflicts',
        content: 'Conflicts are normal in any team. How you handle them can make your team stronger.\n\n'
            'Steps to resolve conflicts:\n'
            '1. Stay calm and respectful\n'
            '2. Listen to understand each person\'s perspective\n'
            '3. Focus on the problem, not the person\n'
            '4. Look for common ground\n'
            '5. Brainstorm solutions together\n'
            '6. Agree on a solution and follow through\n\n'
            'Remember: Conflicts can lead to better ideas and stronger relationships when handled well.',
      ));
    } else {
      // Default generic lessons for any other topic
      lessons.add(MiniCourseLessonModel(
        id: '${id}_1',
        title: 'Introduction to $topic',
        content: 'Welcome to this mini-course on $topic! In this first lesson, we\'ll explore the basics of $topic and why it\'s important for young leaders.\n\n'
            '$topic is a key skill that can help you become more effective in school, with friends, and in future careers. By understanding the fundamentals, you\'ll be better prepared to tackle challenges and achieve your goals.\n\n'
            'In the following lessons, we\'ll dive deeper into specific aspects of $topic and provide practical tips you can start using right away.',
      ));
      
      lessons.add(MiniCourseLessonModel(
        id: '${id}_2',
        title: 'Key Principles of $topic',
        content: 'Now that you understand the basics of $topic, let\'s explore some key principles that will help you master this skill.\n\n'
            'Principle 1: Practice regularly\n'
            'Like any skill, $topic improves with practice. Set aside time each day to work on this skill.\n\n'
            'Principle 2: Learn from others\n'
            'Find role models who excel at $topic and observe how they approach challenges.\n\n'
            'Principle 3: Reflect on your progress\n'
            'Take time to think about what\'s working and what could be improved in your approach to $topic.',
      ));
      
      lessons.add(MiniCourseLessonModel(
        id: '${id}_3',
        title: 'Applying $topic in Real Life',
        content: 'In this final lesson, we\'ll explore how to apply $topic in everyday situations.\n\n'
            'At school:\n'
            '- Use $topic when working on group projects\n'
            '- Apply $topic principles when facing challenges in class\n\n'
            'With friends:\n'
            '- Practice $topic when resolving conflicts\n'
            '- Use $topic to build stronger relationships\n\n'
            'At home:\n'
            '- Demonstrate $topic when helping with family responsibilities\n'
            '- Share what you\'ve learned about $topic with family members\n\n'
            'Remember, the best way to master $topic is to use it consistently in different situations!',
      ));
    }
    
    // Generate a quiz based on the topic
    final quiz = _generateQuizForTopic(id, topic, lessons);
    
    return MiniCourseModel(
      id: id,
      title: title,
      description: description,
      lessons: lessons,
      quiz: quiz,
    );
  }
  
  // Helper method to generate a quiz based on the topic
  static MiniCourseQuizModel _generateQuizForTopic(String courseId, String topic, List<MiniCourseLessonModel> lessons) {
    final quizId = '${courseId}_quiz';
    final questions = <MiniCourseQuizQuestionModel>[];
    
    if (topic == 'Goal Setting') {
      questions.add(MiniCourseQuizQuestionModel(
        id: '${quizId}_1',
        text: 'What does the "M" in SMART goals stand for?',
        options: ['Meaningful', 'Measurable', 'Manageable', 'Motivational'],
        correctAnswerIndex: 1,
      ));
      
      questions.add(MiniCourseQuizQuestionModel(
        id: '${quizId}_2',
        text: 'Why is it helpful to break down big goals into smaller steps?',
        options: [
          'It makes the goal less important',
          'It makes the goal more manageable',
          'It means you can skip some steps',
          'It takes less time overall'
        ],
        correctAnswerIndex: 1,
      ));
      
      questions.add(MiniCourseQuizQuestionModel(
        id: '${quizId}_3',
        text: 'Which of these is NOT a good way to track your progress?',
        options: [
          'Keeping a journal',
          'Using a calendar',
          'Waiting until the end to see if you succeeded',
          'Sharing updates with a friend'
        ],
        correctAnswerIndex: 2,
      ));
      
      questions.add(MiniCourseQuizQuestionModel(
        id: '${quizId}_4',
        text: 'Which of these is an example of a specific goal?',
        options: [
          'I want to be better at math',
          'I want to improve my grades',
          'I will practice multiplication tables for 15 minutes each day',
          'I will try harder in school'
        ],
        correctAnswerIndex: 2,
      ));
      
      questions.add(MiniCourseQuizQuestionModel(
        id: '${quizId}_5',
        text: 'Why is it important to celebrate small wins?',
        options: [
          'It helps keep you motivated',
          'It means you can stop working on your goal',
          'It impresses other people',
          'It makes the goal easier'
        ],
        correctAnswerIndex: 0,
      ));
    } else if (topic == 'Leadership Skills') {
      questions.add(MiniCourseQuizQuestionModel(
        id: '${quizId}_1',
        text: 'Which of these is an example of active listening?',
        options: [
          'Thinking about what you\'ll say next while someone is talking',
          'Interrupting to share your own story',
          'Looking at your phone while nodding',
          'Asking questions to better understand what someone is saying'
        ],
        correctAnswerIndex: 3,
      ));
      
      questions.add(MiniCourseQuizQuestionModel(
        id: '${quizId}_2',
        text: 'What is the first step in good decision-making?',
        options: [
          'Taking action',
          'Defining the problem or opportunity',
          'Evaluating options',
          'Gathering information'
        ],
        correctAnswerIndex: 1,
      ));
      
      questions.add(MiniCourseQuizQuestionModel(
        id: '${quizId}_3',
        text: 'What does it mean to "lead by example"?',
        options: [
          'Telling others what to do',
          'Being the oldest person in the group',
          'Showing others what to do through your own actions',
          'Being in charge of a project'
        ],
        correctAnswerIndex: 2,
      ));
      
      questions.add(MiniCourseQuizQuestionModel(
        id: '${quizId}_4',
        text: 'Which of these is NOT mentioned as a key communication skill for leaders?',
        options: [
          'Active listening',
          'Clear speaking',
          'Talking loudly',
          'Body language'
        ],
        correctAnswerIndex: 2,
      ));
      
      questions.add(MiniCourseQuizQuestionModel(
        id: '${quizId}_5',
        text: 'According to the lesson, what happens if you don\'t make a decision?',
        options: [
          'Someone else will make it for you',
          'You\'re actually deciding to do nothing',
          'The problem will solve itself',
          'You\'ll have more time to think'
        ],
        correctAnswerIndex: 1,
      ));
    } else if (topic == 'Teamwork') {
      questions.add(MiniCourseQuizQuestionModel(
        id: '${quizId}_1',
        text: 'Which team role focuses on supporting others and keeping spirits high?',
        options: ['Leader', 'Organizer', 'Encourager', 'Questioner'],
        correctAnswerIndex: 2,
      ));
      
      questions.add(MiniCourseQuizQuestionModel(
        id: '${quizId}_2',
        text: 'What is an important part of team communication?',
        options: [
          'Only the leader should speak',
          'Keep information to yourself until asked',
          'Avoid giving feedback',
          'Listen to everyone\'s ideas'
        ],
        correctAnswerIndex: 3,
      ));
      
      questions.add(MiniCourseQuizQuestionModel(
        id: '${quizId}_3',
        text: 'When resolving team conflicts, you should focus on:',
        options: [
          'The problem, not the person',
          'Finding someone to blame',
          'Winning the argument',
          'Avoiding the conflict entirely'
        ],
        correctAnswerIndex: 0,
      ));
      
      questions.add(MiniCourseQuizQuestionModel(
        id: '${quizId}_4',
        text: 'Which statement about team roles is true?',
        options: [
          'You can only have one role in a team',
          'Your role never changes',
          'You might be good at more than one role',
          'The leader is the only important role'
        ],
        correctAnswerIndex: 2,
      ));
      
      questions.add(MiniCourseQuizQuestionModel(
        id: '${quizId}_5',
        text: 'According to the lesson, conflicts in a team:',
        options: [
          'Should always be avoided',
          'Mean the team is failing',
          'Can lead to better ideas when handled well',
          'Should be resolved by the leader alone'
        ],
        correctAnswerIndex: 2,
      ));
    } else {
      // Generic questions for any other topic
      questions.add(MiniCourseQuizQuestionModel(
        id: '${quizId}_1',
        text: 'Why is $topic important for young leaders?',
        options: [
          'It\'s only important for adults',
          'It helps you become more effective in various situations',
          'It\'s only useful at school',
          'It\'s only needed for group projects'
        ],
        correctAnswerIndex: 1,
      ));
      
      questions.add(MiniCourseQuizQuestionModel(
        id: '${quizId}_2',
        text: 'According to the course, how can you improve your $topic skills?',
        options: [
          'You\'re born with these skills and can\'t improve them',
          'Read about it once and you\'ll master it',
          'Practice regularly',
          'Watch TV shows about $topic'
        ],
        correctAnswerIndex: 2,
      ));
      
      questions.add(MiniCourseQuizQuestionModel(
        id: '${quizId}_3',
        text: 'Where can you apply $topic skills?',
        options: [
          'Only at school',
          'Only with friends',
          'Only at home',
          'In multiple areas of your life'
        ],
        correctAnswerIndex: 3,
      ));
      
      questions.add(MiniCourseQuizQuestionModel(
        id: '${quizId}_4',
        text: 'What is one way to learn about $topic from others?',
        options: [
          'Ignore what others do',
          'Find role models and observe their approach',
          'Copy exactly what others do without thinking',
          'Assume everyone else is wrong'
        ],
        correctAnswerIndex: 1,
      ));
      
      questions.add(MiniCourseQuizQuestionModel(
        id: '${quizId}_5',
        text: 'Why is reflection important when developing $topic skills?',
        options: [
          'It isn\'t important at all',
          'It helps you think about what\'s working and what could be improved',
          'It\'s only important for adults',
          'It takes the place of actual practice'
        ],
        correctAnswerIndex: 1,
      ));
    }
    
    return MiniCourseQuizModel(
      id: quizId,
      title: '$topic Quiz',
      description: 'Test your knowledge of $topic',
      questions: questions,
    );
  }
  
  // Generate a brand-sponsored mini-course
  static MiniCourseModel generateBrandSponsoredCourse(String topic, String brandName, String brandLogoPath) {
    final id = DateTime.now().millisecondsSinceEpoch.toString() + '_$brandName';
    final title = '$brandName Mini-Course: $topic';
    final description = 'Learn about $topic with $brandName in this special mini-course designed for young leaders.';
    
    // Generate 3 lessons based on the topic and brand
    final lessons = <MiniCourseLessonModel>[];
    
    if (topic == 'Teamwork') {
      lessons.add(MiniCourseLessonModel(
        id: '${id}_1',
        title: 'Teamwork Essentials with $brandName',
        content: 'Just like how $brandName brings people together around delicious meals, teamwork brings people together around shared goals!\n\n'
            'Teamwork is about combining everyone\'s strengths to achieve something great. When you work as a team:\n\n'
            '• Everyone contributes their unique skills\n'
            '• You can accomplish more than you could alone\n'
            '• You learn from others and grow\n\n'
            'Think about how $brandName products bring ingredients together to create something delicious - teamwork is the same way!',
        keyTakeaways: [
          'Teamwork combines individual strengths',
          'Teams accomplish more than individuals',
          'Everyone has something valuable to contribute'
        ],
      ));
      
      lessons.add(MiniCourseLessonModel(
        id: '${id}_2',
        title: 'Communication in Teams',
        content: 'Good communication is the secret ingredient in both $brandName recipes and successful teams!\n\n'
            'When working in a team, clear communication helps:\n\n'
            '• Share ideas effectively\n'
            '• Prevent misunderstandings\n'
            '• Build trust between team members\n\n'
            'Just like $brandName carefully lists ingredients and instructions on their packages, team members should be clear about their ideas, needs, and progress.',
        keyTakeaways: [
          'Clear communication prevents misunderstandings',
          'Listening is as important as speaking',
          'Regular updates keep everyone informed'
        ],
      ));
      
      lessons.add(MiniCourseLessonModel(
        id: '${id}_3',
        title: 'Solving Problems Together',
        content: 'When challenges arise, teams can find creative solutions - just like how $brandName creates innovative recipes!\n\n'
            'Problem-solving as a team involves:\n\n'
            '• Brainstorming multiple solutions\n'
            '• Building on each other\'s ideas\n'
            '• Testing solutions and learning from results\n\n'
            '$brandName is known for bringing people together through food. Similarly, teams bring together different perspectives to solve problems in ways individuals couldn\'t do alone.',
        keyTakeaways: [
          'Teams generate more creative solutions',
          'Different perspectives lead to better outcomes',
          'Learning from mistakes helps teams grow'
        ],
      ));
    } else if (topic == 'Leadership Skills') {
      lessons.add(MiniCourseLessonModel(
        id: '${id}_1',
        title: 'Leadership Fundamentals with $brandName',
        content: 'Just as $brandName has been a leader in providing nutritious breakfast options, you can develop leadership skills to guide others!\n\n'
            'Leadership is about:\n\n'
            '• Setting a positive example for others\n'
            '• Making decisions that benefit the group\n'
            '• Inspiring others to do their best\n\n'
            '$brandName has led the way in nutrition for over 100 years. Great leaders, like great brands, build trust through consistency and quality.',
        keyTakeaways: [
          'Leaders set the example through their actions',
          'Good decisions consider everyone\'s needs',
          'Leadership is about serving others'
        ],
      ));
      
      lessons.add(MiniCourseLessonModel(
        id: '${id}_2',
        title: 'Building Your Leadership Style',
        content: 'Just like $brandName offers different cereals for different tastes, there are many effective leadership styles!\n\n'
            'Finding your leadership style means:\n\n'
            '• Understanding your strengths and values\n'
            '• Adapting your approach to different situations\n'
            '• Being authentic while continuing to grow\n\n'
            '$brandName has evolved over time while staying true to its core values of nutrition and quality. Good leaders also stay true to their values while adapting to new challenges.',
        keyTakeaways: [
          'Authentic leadership builds on your strengths',
          'Different situations may require different approaches',
          'Great leaders continue learning and growing'
        ],
      ));
      
      lessons.add(MiniCourseLessonModel(
        id: '${id}_3',
        title: 'Empowering Your Team',
        content: 'Great leaders empower others - just like how $brandName empowers people to start their day with energy and nutrition!\n\n'
            'Empowering your team involves:\n\n'
            '• Delegating responsibilities appropriately\n'
            '• Providing support and resources\n'
            '• Celebrating successes and learning from challenges\n\n'
            '$brandName believes in providing the nutrition people need to achieve their best. Similarly, great leaders provide team members with what they need to succeed.',
        keyTakeaways: [
          'Delegation shows trust in team members',
          'Support helps people overcome obstacles',
          'Recognition motivates continued growth'
        ],
      ));
    } else {
      // For other topics, generate generic brand-sponsored content
      lessons.add(MiniCourseLessonModel(
        id: '${id}_1',
        title: 'Introduction to $topic with $brandName',
        content: '$brandName presents this special lesson on $topic for young leaders!\n\n'
            'In this lesson, we\'ll explore the fundamentals of $topic and how it relates to everyday life - including enjoying $brandName products with friends and family.\n\n'
            'Learning about $topic helps you develop important skills that will serve you throughout your life, just like how $brandName has been serving families for generations.',
      ));
      
      lessons.add(MiniCourseLessonModel(
        id: '${id}_2',
        title: 'Developing Your $topic Skills',
        content: 'With $brandName as your partner, let\'s explore how to develop your $topic skills!\n\n'
            'Just as $brandName carefully selects quality ingredients, developing skills requires attention and practice.\n\n'
            'Remember that becoming better at $topic takes time and effort - but the results are worth it, just like taking the time to enjoy a delicious $brandName meal or snack.',
      ));
      
      lessons.add(MiniCourseLessonModel(
        id: '${id}_3',
        title: '$topic in Action',
        content: 'Now it\'s time to put your $topic skills into action with $brandName!\n\n'
            'When you apply what you\'ve learned about $topic in real situations, you\'ll see how valuable these skills are.\n\n'
            '$brandName believes in bringing out the best in people, just like this course aims to bring out the best in your $topic abilities.',
      ));
    }
    
    // Generate quiz for the topic
    final quiz = _generateQuizForTopic(id, topic, lessons);
    
    return MiniCourseModel(
      id: id,
      title: title,
      description: description,
      lessons: lessons,
      quiz: quiz,
      status: MiniCourseStatus.notStarted,
    );
  }

  // Mock data for development
  static List<MiniCourseModel> getMockMiniCourses() {
    return [
      generateFromTopic('Goal Setting'),
      generateFromTopic('Leadership Skills'),
      generateFromTopic('Teamwork'),
      generateFromTopic('Communication'),
      generateFromTopic('Problem Solving'),
    ];
  }
}

class MiniCourseLessonModel {
  final String id;
  final String title;
  final String content;
  final bool isCompleted;
  final List<String> keyTakeaways;

  MiniCourseLessonModel({
    required this.id,
    required this.title,
    required this.content,
    this.isCompleted = false,
    this.keyTakeaways = const [],
  });

  MiniCourseLessonModel copyWith({
    String? id,
    String? title,
    String? content,
    bool? isCompleted,
    List<String>? keyTakeaways,
  }) {
    return MiniCourseLessonModel(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      isCompleted: isCompleted ?? this.isCompleted,
      keyTakeaways: keyTakeaways ?? this.keyTakeaways,
    );
  }
}

class MiniCourseQuizModel {
  final String id;
  final String title;
  final String description;
  final List<MiniCourseQuizQuestionModel> questions;
  final bool isCompleted;
  final int? score;

  MiniCourseQuizModel({
    required this.id,
    required this.title,
    required this.description,
    required this.questions,
    this.isCompleted = false,
    this.score,
  });

  MiniCourseQuizModel copyWith({
    String? id,
    String? title,
    String? description,
    List<MiniCourseQuizQuestionModel>? questions,
    bool? isCompleted,
    int? score,
  }) {
    return MiniCourseQuizModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      questions: questions ?? this.questions,
      isCompleted: isCompleted ?? this.isCompleted,
      score: score ?? this.score,
    );
  }
}

class MiniCourseQuizQuestionModel {
  final String id;
  final String text; // Renamed from 'question' to match UI
  final List<String> options;
  final int correctAnswerIndex; // Renamed from 'correctOptionIndex' to match UI
  final int? selectedOptionIndex;

  MiniCourseQuizQuestionModel({
    required this.id,
    required this.text,
    required this.options,
    required this.correctAnswerIndex,
    this.selectedOptionIndex,
  });

  MiniCourseQuizQuestionModel copyWith({
    String? id,
    String? text,
    List<String>? options,
    int? correctAnswerIndex,
    int? selectedOptionIndex,
  }) {
    return MiniCourseQuizQuestionModel(
      id: id ?? this.id,
      text: text ?? this.text,
      options: options ?? this.options,
      correctAnswerIndex: correctAnswerIndex ?? this.correctAnswerIndex,
      selectedOptionIndex: selectedOptionIndex ?? this.selectedOptionIndex,
    );
  }

  bool get isCorrect => selectedOptionIndex == correctAnswerIndex;
}
