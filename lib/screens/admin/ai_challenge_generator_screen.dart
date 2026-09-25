import 'package:flutter/material.dart';
import '../../services/ai_challenge_generator_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/quest_button.dart';

/// Admin screen for AI-powered challenge generation
class AIChallengeGeneratorScreen extends StatefulWidget {
  const AIChallengeGeneratorScreen({super.key});

  @override
  State<AIChallengeGeneratorScreen> createState() => _AIChallengeGeneratorScreenState();
}

class _AIChallengeGeneratorScreenState extends State<AIChallengeGeneratorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _themeController = TextEditingController();
  final _audienceController = TextEditingController(text: '10-15 year olds');
  final _contextController = TextEditingController();
  final _durationController = TextEditingController(text: '7');
  
  String _difficulty = 'medium';
  bool _isGenerating = false;
  bool _isSaving = false;
  GeneratedChallenge? _generatedChallenge;
  String? _savedChallengeId;
  
  final _generator = AIChallengeGeneratorService.instance;

  @override
  void dispose() {
    _themeController.dispose();
    _audienceController.dispose();
    _contextController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _generateChallenge() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isGenerating = true;
      _generatedChallenge = null;
      _savedChallengeId = null;
    });

    try {
      final challenge = await _generator.generateChallenge(
        theme: _themeController.text.trim(),
        difficulty: _difficulty,
        targetAudience: _audienceController.text.trim(),
        durationDays: int.parse(_durationController.text),
        additionalContext: _contextController.text.trim().isEmpty 
            ? null 
            : _contextController.text.trim(),
      );

      setState(() {
        _generatedChallenge = challenge;
        _isGenerating = false;
      });

      if (challenge == null) {
        _showError('Failed to generate challenge. Please try again.');
      } else if (challenge.qualityScore < 7.0) {
        _showWarning('Challenge generated but quality score is low (${challenge.qualityScore.toStringAsFixed(1)}/10). Consider regenerating.');
      }
    } catch (e) {
      setState(() => _isGenerating = false);
      _showError('Error: $e');
    }
  }

  Future<void> _saveChallenge() async {
    if (_generatedChallenge == null) return;

    setState(() => _isSaving = true);

    try {
      final challengeId = await _generator.saveChallenge(_generatedChallenge!);
      
      setState(() {
        _isSaving = false;
        _savedChallengeId = challengeId;
      });

      if (challengeId != null) {
        _showSuccess('Challenge saved successfully!');
      } else {
        _showError('Failed to save challenge. It may already exist.');
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _showError('Error saving: $e');
    }
  }

  Future<void> _generateBatch() async {
    if (!_formKey.currentState!.validate()) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate Batch'),
        content: const Text(
          'This will generate 5 variations of the challenge with different difficulty levels. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Generate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isGenerating = true);

    try {
      final requests = [
        ChallengeGenerationRequest(
          theme: _themeController.text.trim(),
          difficulty: 'easy',
          targetAudience: _audienceController.text.trim(),
          durationDays: int.parse(_durationController.text),
        ),
        ChallengeGenerationRequest(
          theme: _themeController.text.trim(),
          difficulty: 'medium',
          targetAudience: _audienceController.text.trim(),
          durationDays: int.parse(_durationController.text),
        ),
        ChallengeGenerationRequest(
          theme: _themeController.text.trim(),
          difficulty: 'hard',
          targetAudience: _audienceController.text.trim(),
          durationDays: int.parse(_durationController.text),
        ),
      ];

      final challenges = await _generator.generateBatch(requests: requests);

      setState(() => _isGenerating = false);

      if (challenges.isEmpty) {
        _showError('Failed to generate any challenges');
        return;
      }

      // Show batch results
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BatchResultsScreen(challenges: challenges),
          ),
        );
      }
    } catch (e) {
      setState(() => _isGenerating = false);
      _showError('Error: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showWarning(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Challenge Generator'),
        backgroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(Icons.auto_awesome, size: 48, color: AppColors.primary),
                    const SizedBox(height: 8),
                    const Text(
                      'AI-Powered Challenge Generator',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Generate trackable, validated challenges using Gemini AI',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),

              // Theme
              TextFormField(
                controller: _themeController,
                decoration: const InputDecoration(
                  labelText: 'Theme *',
                  hintText: 'e.g., Consistency, Learning, Gratitude',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lightbulb_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Theme is required';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Difficulty
              DropdownButtonFormField<String>(
                value: _difficulty,
                decoration: const InputDecoration(
                  labelText: 'Difficulty *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.trending_up),
                ),
                items: const [
                  DropdownMenuItem(value: 'easy', child: Text('Easy (1-2 rules)')),
                  DropdownMenuItem(value: 'medium', child: Text('Medium (2-3 rules)')),
                  DropdownMenuItem(value: 'hard', child: Text('Hard (3+ rules)')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _difficulty = value);
                  }
                },
              ),

              const SizedBox(height: 16),

              // Target Audience
              TextFormField(
                controller: _audienceController,
                decoration: const InputDecoration(
                  labelText: 'Target Audience *',
                  hintText: 'e.g., 10-15 year olds',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.people_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Target audience is required';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Duration
              TextFormField(
                controller: _durationController,
                decoration: const InputDecoration(
                  labelText: 'Duration (days) *',
                  hintText: '7, 14, 30',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Duration is required';
                  }
                  final days = int.tryParse(value);
                  if (days == null || days < 1 || days > 90) {
                    return 'Duration must be 1-90 days';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Additional Context
              TextFormField(
                controller: _contextController,
                decoration: const InputDecoration(
                  labelText: 'Additional Context (optional)',
                  hintText: 'Any specific requirements or focus areas',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes),
                ),
                maxLines: 3,
              ),

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: QuestButton(
                      text: 'Generate',
                      onPressed: _isGenerating ? null : _generateChallenge,
                      icon: Icons.auto_awesome,
                      isLoading: _isGenerating,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isGenerating ? null : _generateBatch,
                      icon: const Icon(Icons.auto_awesome_mosaic),
                      label: const Text('Batch (5x)'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),

              // Generated Challenge Preview
              if (_generatedChallenge != null) ...[
                const SizedBox(height: 32),
                _buildChallengePreview(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChallengePreview() {
    final challenge = _generatedChallenge!;
    
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getQualityColor(challenge.qualityScore).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: _getQualityColor(challenge.qualityScore),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Generated Challenge',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Quality Score: ${challenge.qualityScore.toStringAsFixed(1)}/10',
                        style: TextStyle(
                          fontSize: 14,
                          color: _getQualityColor(challenge.qualityScore),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  challenge.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // Description
                Text(
                  challenge.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 16),

                // Reward & Duration
                Row(
                  children: [
                    _buildInfoChip(
                      Icons.monetization_on,
                      '${challenge.coinReward} coins',
                      Colors.amber,
                    ),
                    const SizedBox(width: 8),
                    _buildInfoChip(
                      Icons.calendar_today,
                      '${challenge.durationDays} days',
                      Colors.blue,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Criteria
                const Text(
                  'Criteria:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...challenge.criteria.map((criterion) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontSize: 16)),
                      Expanded(child: Text(criterion)),
                    ],
                  ),
                )),
                const SizedBox(height: 16),

                // Rules
                const Text(
                  'Rules:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...challenge.rules.map((rule) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rule.ruleType,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Target: ${rule.targetValue}'),
                      Text('Window: ${rule.windowType}${rule.windowValueDays != null ? " (${rule.windowValueDays} days)" : ""}'),
                    ],
                  ),
                )),
              ],
            ),
          ),

          // Actions
          if (_savedChallengeId == null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _generateChallenge,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Regenerate'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: QuestButton(
                      text: 'Save to Database',
                      onPressed: _isSaving ? null : _saveChallenge,
                      icon: Icons.save,
                      isLoading: _isSaving,
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Challenge Saved!',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          Text(
                            'ID: $_savedChallengeId',
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getQualityColor(double score) {
    if (score >= 8.0) return Colors.green;
    if (score >= 7.0) return Colors.orange;
    return Colors.red;
  }
}

/// Batch results screen
class BatchResultsScreen extends StatelessWidget {
  final List<GeneratedChallenge> challenges;

  const BatchResultsScreen({super.key, required this.challenges});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch Generation Results'),
        backgroundColor: AppColors.primary,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: challenges.length,
        itemBuilder: (context, index) {
          final challenge = challenges[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _getQualityColor(challenge.qualityScore),
                child: Text(
                  challenge.qualityScore.toStringAsFixed(1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(challenge.title),
              subtitle: Text(
                '${challenge.coinReward} coins • ${challenge.rules.length} rules',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.save),
                onPressed: () async {
                  final id = await AIChallengeGeneratorService.instance
                      .saveChallenge(challenge);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          id != null
                              ? 'Challenge saved!'
                              : 'Failed to save challenge',
                        ),
                        backgroundColor: id != null ? Colors.green : Colors.red,
                      ),
                    );
                  }
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getQualityColor(double score) {
    if (score >= 8.0) return Colors.green;
    if (score >= 7.0) return Colors.orange;
    return Colors.red;
  }
}
