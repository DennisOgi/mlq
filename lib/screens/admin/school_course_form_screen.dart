import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants/app_constants.dart';
import '../../models/school_course_model.dart';
import '../../providers/school_course_provider.dart';
import '../../theme/app_theme.dart';

/// Form screen for creating/editing school mini courses
class SchoolCourseFormScreen extends StatefulWidget {
  final SchoolCourse? course;

  const SchoolCourseFormScreen({super.key, this.course});

  @override
  State<SchoolCourseFormScreen> createState() => _SchoolCourseFormScreenState();
}

class _SchoolCourseFormScreenState extends State<SchoolCourseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

  // Form controllers
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _topicController;
  late TextEditingController _summaryController;

  // Form state
  String _difficulty = 'beginner';
  int _xpReward = 20;
  double _coinReward = 5.0;
  int _estimatedDuration = 10;
  String? _selectedCategoryId;
  String? _thumbnailUrl;
  List<String> _selectedGradeLevels = [];
  String? _subject;

  // Content blocks
  List<CourseContentBlock> _contentBlocks = [];

  // Quiz questions
  List<QuizQuestion> _quizQuestions = [];

  bool _isLoading = false;
  bool get _isEditing => widget.course != null;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    if (_isEditing) {
      final course = widget.course!;
      _titleController = TextEditingController(text: course.title);
      _descriptionController = TextEditingController(text: course.description);
      _topicController = TextEditingController(text: course.topic);
      _summaryController = TextEditingController(text: course.summary ?? '');
      _difficulty = course.difficulty;
      _xpReward = course.xpReward;
      _coinReward = course.coinReward;
      _estimatedDuration = course.estimatedDuration;
      _selectedCategoryId = course.categoryId;
      _thumbnailUrl = course.thumbnailUrl;
      _selectedGradeLevels = List.from(course.gradeLevels);
      _subject = course.subject;
      _contentBlocks = List.from(course.content);
      _quizQuestions = List.from(course.quizQuestions);
    } else {
      _titleController = TextEditingController();
      _descriptionController = TextEditingController();
      _topicController = TextEditingController();
      _summaryController = TextEditingController();
      // Add default content block
      _contentBlocks = [
        CourseContentBlock(type: 'heading', content: ''),
        CourseContentBlock(type: 'text', content: ''),
      ];
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _topicController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Course' : 'Create Course'),
        actions: [
          if (_isEditing)
            TextButton(
              onPressed: _isLoading ? null : _saveDraft,
              child: const Text('Save Draft'),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Basic Info Section
              _buildSectionHeader('Basic Information', Icons.info_outline),
              _buildBasicInfoSection(),
              const SizedBox(height: 24),

              // Category & Targeting Section
              _buildSectionHeader('Category & Targeting', Icons.category),
              _buildCategorySection(),
              const SizedBox(height: 24),

              // Content Section
              _buildSectionHeader('Course Content', Icons.article),
              _buildContentSection(),
              const SizedBox(height: 24),

              // Quiz Section
              _buildSectionHeader('Quiz Questions', Icons.quiz),
              _buildQuizSection(),
              const SizedBox(height: 24),

              // Rewards Section
              _buildSectionHeader('Rewards & Settings', Icons.emoji_events),
              _buildRewardsSection(),
              const SizedBox(height: 32),

              // Action Buttons
              _buildActionButtons(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // BASIC INFO SECTION
  // =====================================================

  Widget _buildBasicInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.getNeumorphicDecoration(),
      child: Column(
        children: [
          // Thumbnail
          GestureDetector(
            onTap: _pickThumbnail,
            child: Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: _thumbnailUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        _thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildThumbnailPlaceholder(),
                      ),
                    )
                  : _buildThumbnailPlaceholder(),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Course Title *',
              hintText: 'e.g., Introduction to Algebra',
              prefixIcon: Icon(Icons.title),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a title';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Topic
          TextFormField(
            controller: _topicController,
            decoration: const InputDecoration(
              labelText: 'Topic *',
              hintText: 'e.g., Mathematics, Science, Leadership',
              prefixIcon: Icon(Icons.topic),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a topic';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Description
          TextFormField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Description *',
              hintText: 'Describe what students will learn...',
              prefixIcon: Icon(Icons.description),
              alignLabelWithHint: true,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a description';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Summary
          TextFormField(
            controller: _summaryController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Summary (optional)',
              hintText: 'Brief summary for course cards...',
              prefixIcon: Icon(Icons.short_text),
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnailPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey[400]),
        const SizedBox(height: 8),
        Text(
          'Tap to add thumbnail',
          style: TextStyle(color: Colors.grey[500]),
        ),
      ],
    );
  }

  // =====================================================
  // CATEGORY SECTION
  // =====================================================

  Widget _buildCategorySection() {
    return Consumer<SchoolCourseProvider>(
      builder: (context, provider, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.getNeumorphicDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category dropdown
              DropdownButtonFormField<String>(
                value: _selectedCategoryId,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('No Category'),
                  ),
                  ...provider.categories.map((cat) => DropdownMenuItem(
                        value: cat.id,
                        child: Text(cat.name),
                      )),
                ],
                onChanged: (value) {
                  setState(() => _selectedCategoryId = value);
                },
              ),
              const SizedBox(height: 16),

              // Subject
              TextFormField(
                initialValue: _subject,
                decoration: const InputDecoration(
                  labelText: 'Subject (optional)',
                  hintText: 'e.g., Physics, English Literature',
                  prefixIcon: Icon(Icons.subject),
                ),
                onChanged: (value) => _subject = value,
              ),
              const SizedBox(height: 16),

              // Grade levels
              const Text(
                'Target Grade Levels',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  'Grade 7',
                  'Grade 8',
                  'Grade 9',
                  'Grade 10',
                  'Grade 11',
                  'Grade 12',
                ].map((grade) {
                  final isSelected = _selectedGradeLevels.contains(grade);
                  return FilterChip(
                    label: Text(grade),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedGradeLevels.add(grade);
                        } else {
                          _selectedGradeLevels.remove(grade);
                        }
                      });
                    },
                    selectedColor: AppColors.primary.withOpacity(0.2),
                    checkmarkColor: AppColors.primary,
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Text(
                'Leave empty to show to all grades',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        );
      },
    );
  }

  // =====================================================
  // CONTENT SECTION
  // =====================================================

  Widget _buildContentSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.getNeumorphicDecoration(),
      child: Column(
        children: [
          // Content blocks list
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _contentBlocks.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final item = _contentBlocks.removeAt(oldIndex);
                _contentBlocks.insert(newIndex, item);
              });
            },
            itemBuilder: (context, index) {
              return _buildContentBlockItem(index, key: ValueKey('content_$index'));
            },
          ),
          const SizedBox(height: 16),

          // Add content block buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildAddBlockButton('Heading', Icons.title, () {
                setState(() {
                  _contentBlocks.add(CourseContentBlock(type: 'heading', content: ''));
                });
              }),
              _buildAddBlockButton('Text', Icons.notes, () {
                setState(() {
                  _contentBlocks.add(CourseContentBlock(type: 'text', content: ''));
                });
              }),
              _buildAddBlockButton('Bullet List', Icons.format_list_bulleted, () {
                setState(() {
                  _contentBlocks.add(CourseContentBlock(type: 'bullet_list', content: ''));
                });
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContentBlockItem(int index, {Key? key}) {
    final block = _contentBlocks[index];
    final controller = TextEditingController(text: block.content);

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getBlockIcon(block.type),
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                _getBlockLabel(block.type),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                onPressed: () {
                  setState(() => _contentBlocks.removeAt(index));
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            maxLines: block.type == 'text' || block.type == 'bullet_list' ? 4 : 1,
            decoration: InputDecoration(
              hintText: _getBlockHint(block.type),
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.all(12),
            ),
            style: TextStyle(
              fontSize: block.type == 'heading' ? 16 : 14,
              fontWeight: block.type == 'heading' ? FontWeight.bold : FontWeight.normal,
            ),
            onChanged: (value) {
              _contentBlocks[index] = CourseContentBlock(
                type: block.type,
                content: value,
                metadata: block.metadata,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAddBlockButton(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getBlockIcon(String type) {
    switch (type) {
      case 'heading':
        return Icons.title;
      case 'text':
        return Icons.notes;
      case 'bullet_list':
        return Icons.format_list_bulleted;
      case 'image':
        return Icons.image;
      default:
        return Icons.text_fields;
    }
  }

  String _getBlockLabel(String type) {
    switch (type) {
      case 'heading':
        return 'HEADING';
      case 'text':
        return 'PARAGRAPH';
      case 'bullet_list':
        return 'BULLET LIST';
      case 'image':
        return 'IMAGE';
      default:
        return type.toUpperCase();
    }
  }

  String _getBlockHint(String type) {
    switch (type) {
      case 'heading':
        return 'Enter section heading...';
      case 'text':
        return 'Enter paragraph content...';
      case 'bullet_list':
        return 'Enter items (one per line)...';
      default:
        return 'Enter content...';
    }
  }

  // =====================================================
  // QUIZ SECTION
  // =====================================================

  Widget _buildQuizSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.getNeumorphicDecoration(),
      child: Column(
        children: [
          if (_quizQuestions.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.quiz_outlined, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(
                    'No quiz questions yet',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add questions to test student understanding',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _quizQuestions.length,
              itemBuilder: (context, index) {
                return _buildQuizQuestionItem(index);
              },
            ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _addQuizQuestion,
            icon: const Icon(Icons.add),
            label: const Text('Add Question'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizQuestionItem(int index) {
    final question = _quizQuestions[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: AppColors.primary,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  question.question.isEmpty ? 'New Question' : question.question,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 18),
                onPressed: () => _editQuizQuestion(index),
              ),
              IconButton(
                icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                onPressed: () {
                  setState(() => _quizQuestions.removeAt(index));
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...question.options.asMap().entries.map((entry) {
            final isCorrect = entry.key == question.correctIndex;
            return Padding(
              padding: const EdgeInsets.only(left: 32, bottom: 4),
              child: Row(
                children: [
                  Icon(
                    isCorrect ? Icons.check_circle : Icons.circle_outlined,
                    size: 16,
                    color: isCorrect ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        color: isCorrect ? Colors.green : Colors.grey[700],
                        fontWeight: isCorrect ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  void _addQuizQuestion() {
    _showQuizQuestionDialog(null);
  }

  void _editQuizQuestion(int index) {
    _showQuizQuestionDialog(index);
  }

  void _showQuizQuestionDialog(int? editIndex) {
    final isEditing = editIndex != null;
    final existingQuestion = isEditing ? _quizQuestions[editIndex] : null;

    final questionController = TextEditingController(text: existingQuestion?.question ?? '');
    final optionControllers = List.generate(
      4,
      (i) => TextEditingController(
        text: existingQuestion != null && i < existingQuestion.options.length
            ? existingQuestion.options[i]
            : '',
      ),
    );
    final explanationController = TextEditingController(text: existingQuestion?.explanation ?? '');
    int correctIndex = existingQuestion?.correctIndex ?? 0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Edit Question' : 'Add Question'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: questionController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Question *',
                    hintText: 'Enter your question...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Options (select correct answer):'),
                const SizedBox(height: 8),
                ...List.generate(4, (i) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Radio<int>(
                          value: i,
                          groupValue: correctIndex,
                          onChanged: (value) {
                            setDialogState(() => correctIndex = value!);
                          },
                        ),
                        Expanded(
                          child: TextField(
                            controller: optionControllers[i],
                            decoration: InputDecoration(
                              hintText: 'Option ${i + 1}',
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
                TextField(
                  controller: explanationController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Explanation (optional)',
                    hintText: 'Explain the correct answer...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final options = optionControllers
                    .map((c) => c.text)
                    .where((t) => t.isNotEmpty)
                    .toList();

                if (questionController.text.isEmpty || options.length < 2) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a question and at least 2 options'),
                    ),
                  );
                  return;
                }

                final newQuestion = QuizQuestion(
                  question: questionController.text,
                  options: options,
                  correctIndex: correctIndex.clamp(0, options.length - 1),
                  explanation: explanationController.text.isEmpty
                      ? null
                      : explanationController.text,
                );

                setState(() {
                  if (isEditing) {
                    _quizQuestions[editIndex] = newQuestion;
                  } else {
                    _quizQuestions.add(newQuestion);
                  }
                });

                Navigator.pop(context);
              },
              child: Text(isEditing ? 'Save' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // REWARDS SECTION
  // =====================================================

  Widget _buildRewardsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.getNeumorphicDecoration(),
      child: Column(
        children: [
          // Difficulty
          DropdownButtonFormField<String>(
            value: _difficulty,
            decoration: const InputDecoration(
              labelText: 'Difficulty Level',
              prefixIcon: Icon(Icons.signal_cellular_alt),
            ),
            items: const [
              DropdownMenuItem(value: 'beginner', child: Text('Beginner')),
              DropdownMenuItem(value: 'intermediate', child: Text('Intermediate')),
              DropdownMenuItem(value: 'advanced', child: Text('Advanced')),
            ],
            onChanged: (value) {
              setState(() => _difficulty = value!);
            },
          ),
          const SizedBox(height: 16),

          // Estimated duration
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Estimated Duration'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: _estimatedDuration.toDouble(),
                            min: 5,
                            max: 60,
                            divisions: 11,
                            label: '$_estimatedDuration min',
                            onChanged: (value) {
                              setState(() => _estimatedDuration = value.round());
                            },
                          ),
                        ),
                        Text(
                          '$_estimatedDuration min',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // XP Reward
          Row(
            children: [
              const Icon(Icons.star, color: Colors.amber),
              const SizedBox(width: 8),
              const Text('XP Reward:'),
              const Spacer(),
              SizedBox(
                width: 80,
                child: TextFormField(
                  initialValue: _xpReward.toString(),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  onChanged: (value) {
                    _xpReward = int.tryParse(value) ?? 20;
                  },
                ),
              ),
              const Text(' XP'),
            ],
          ),
          const SizedBox(height: 16),

          // Coin Reward
          Row(
            children: [
              const Icon(Icons.monetization_on, color: Colors.orange),
              const SizedBox(width: 8),
              const Text('Coin Reward:'),
              const Spacer(),
              SizedBox(
                width: 80,
                child: TextFormField(
                  initialValue: _coinReward.toString(),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  onChanged: (value) {
                    _coinReward = double.tryParse(value) ?? 5.0;
                  },
                ),
              ),
              const Text(' coins'),
            ],
          ),
        ],
      ),
    );
  }

  // =====================================================
  // ACTION BUTTONS
  // =====================================================

  Widget _buildActionButtons() {
    final provider = context.read<SchoolCourseProvider>();
    final isAdmin = provider.isSchoolAdmin;

    return Column(
      children: [
        // Save as draft
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : _saveDraft,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save as Draft'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Publish or Submit for approval
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : (isAdmin ? _publishCourse : _submitForApproval),
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(isAdmin ? Icons.publish : Icons.send),
            label: Text(isAdmin ? 'Publish Course' : 'Submit for Approval'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  // =====================================================
  // ACTIONS
  // =====================================================

  Future<void> _pickThumbnail() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 600,
        imageQuality: 85,
      );

      if (image != null) {
        final provider = context.read<SchoolCourseProvider>();
        final bytes = await image.readAsBytes();
        final url = await provider.uploadCourseThumbnail(bytes, image.name);

        if (url != null) {
          setState(() => _thumbnailUrl = url);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload thumbnail: $e')),
        );
      }
    }
  }

  Future<void> _saveDraft() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final provider = context.read<SchoolCourseProvider>();
      final contentMaps = _contentBlocks.map((b) => b.toJson()).toList();
      final quizMaps = _quizQuestions.map((q) => q.toJson()).toList();

      if (_isEditing) {
        await provider.updateCourse(
          courseId: widget.course!.id,
          title: _titleController.text,
          description: _descriptionController.text,
          topic: _topicController.text,
          summary: _summaryController.text.isEmpty ? null : _summaryController.text,
          content: contentMaps,
          quizQuestions: quizMaps,
          gradeLevels: _selectedGradeLevels,
          subject: _subject,
          categoryId: _selectedCategoryId,
          xpReward: _xpReward,
          coinReward: _coinReward,
          difficulty: _difficulty,
          estimatedDuration: _estimatedDuration,
          thumbnailUrl: _thumbnailUrl,
        );
      } else {
        await provider.createCourse(
          title: _titleController.text,
          description: _descriptionController.text,
          topic: _topicController.text,
          summary: _summaryController.text.isEmpty ? null : _summaryController.text,
          content: contentMaps,
          quizQuestions: quizMaps,
          gradeLevels: _selectedGradeLevels,
          subject: _subject,
          categoryId: _selectedCategoryId,
          xpReward: _xpReward,
          coinReward: _coinReward,
          difficulty: _difficulty,
          estimatedDuration: _estimatedDuration,
          thumbnailUrl: _thumbnailUrl,
          submitForApproval: false,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Course saved as draft')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _publishCourse() async {
    if (!_formKey.currentState!.validate()) return;

    if (_contentBlocks.isEmpty || _contentBlocks.every((b) => b.content.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add some content to the course')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final provider = context.read<SchoolCourseProvider>();
      final contentMaps = _contentBlocks.map((b) => b.toJson()).toList();
      final quizMaps = _quizQuestions.map((q) => q.toJson()).toList();

      SchoolCourse? course;

      if (_isEditing) {
        await provider.updateCourse(
          courseId: widget.course!.id,
          title: _titleController.text,
          description: _descriptionController.text,
          topic: _topicController.text,
          summary: _summaryController.text.isEmpty ? null : _summaryController.text,
          content: contentMaps,
          quizQuestions: quizMaps,
          gradeLevels: _selectedGradeLevels,
          subject: _subject,
          categoryId: _selectedCategoryId,
          xpReward: _xpReward,
          coinReward: _coinReward,
          difficulty: _difficulty,
          estimatedDuration: _estimatedDuration,
          thumbnailUrl: _thumbnailUrl,
        );
        await provider.publishCourse(widget.course!.id);
      } else {
        course = await provider.createCourse(
          title: _titleController.text,
          description: _descriptionController.text,
          topic: _topicController.text,
          summary: _summaryController.text.isEmpty ? null : _summaryController.text,
          content: contentMaps,
          quizQuestions: quizMaps,
          gradeLevels: _selectedGradeLevels,
          subject: _subject,
          categoryId: _selectedCategoryId,
          xpReward: _xpReward,
          coinReward: _coinReward,
          difficulty: _difficulty,
          estimatedDuration: _estimatedDuration,
          thumbnailUrl: _thumbnailUrl,
          submitForApproval: false,
        );

        if (course != null) {
          await provider.publishCourse(course.id);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Course published successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to publish: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitForApproval() async {
    if (!_formKey.currentState!.validate()) return;

    if (_contentBlocks.isEmpty || _contentBlocks.every((b) => b.content.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add some content to the course')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final provider = context.read<SchoolCourseProvider>();
      final contentMaps = _contentBlocks.map((b) => b.toJson()).toList();
      final quizMaps = _quizQuestions.map((q) => q.toJson()).toList();

      if (_isEditing) {
        await provider.updateCourse(
          courseId: widget.course!.id,
          title: _titleController.text,
          description: _descriptionController.text,
          topic: _topicController.text,
          summary: _summaryController.text.isEmpty ? null : _summaryController.text,
          content: contentMaps,
          quizQuestions: quizMaps,
          gradeLevels: _selectedGradeLevels,
          subject: _subject,
          categoryId: _selectedCategoryId,
          xpReward: _xpReward,
          coinReward: _coinReward,
          difficulty: _difficulty,
          estimatedDuration: _estimatedDuration,
          thumbnailUrl: _thumbnailUrl,
        );
        await provider.submitCourseForApproval(widget.course!.id);
      } else {
        await provider.createCourse(
          title: _titleController.text,
          description: _descriptionController.text,
          topic: _topicController.text,
          summary: _summaryController.text.isEmpty ? null : _summaryController.text,
          content: contentMaps,
          quizQuestions: quizMaps,
          gradeLevels: _selectedGradeLevels,
          subject: _subject,
          categoryId: _selectedCategoryId,
          xpReward: _xpReward,
          coinReward: _coinReward,
          difficulty: _difficulty,
          estimatedDuration: _estimatedDuration,
          thumbnailUrl: _thumbnailUrl,
          submitForApproval: true,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Course submitted for approval!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
