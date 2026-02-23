import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_leadership_quest/constants/app_constants.dart' hide AppColors;
import '../../models/challenge_model.dart';
import '../../services/admin_service.dart';
import '../../theme/app_colors.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/organization_settings_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class ChallengeFormScreen extends StatefulWidget {
  final ChallengeModel? challenge;

  const ChallengeFormScreen({Key? key, this.challenge}) : super(key: key);

  @override
  State<ChallengeFormScreen> createState() => _ChallengeFormScreenState();
}

class _ChallengeFormScreenState extends State<ChallengeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isUploadingLogo = false;
  String? _logoPreviewUrl; // network URL after upload
  bool _loadingOrganizations = false;
  List<Map<String, dynamic>> _organizations = const [];
  
  // Form controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _organizationIdController = TextEditingController();
  final _organizationNameController = TextEditingController();
  final _organizationLogoController = TextEditingController();
  final _timelineController = TextEditingController();
  final _realWorldPrizeController = TextEditingController();
  final _coinRewardController = TextEditingController();
  final _coinCostController = TextEditingController();
  final _externalUrlController = TextEditingController();
  String _validationMode = 'in_app'; // 'in_app' | 'external'
  
  // Form values
  ChallengeType _type = ChallengeType.basic;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  bool _isTeamChallenge = false;
  bool _isActive = true;
  String _challengeMode = 'scheduled'; // 'scheduled' (fixed dates) or 'evergreen' (self-paced)
  List<String> _criteria = [''];
  // Structured basic challenge rules (client-side model as maps matching DB columns)
  // Start empty — admin must select a template explicitly.
  List<Map<String, dynamic>> _rules = [];

  @override
  void initState() {
    super.initState();
    if (widget.challenge != null) {
      // Populate form with challenge data
      _titleController.text = widget.challenge!.title;
      _descriptionController.text = widget.challenge!.description;
      _organizationIdController.text = widget.challenge!.organizationId;
      _organizationNameController.text = widget.challenge!.organizationName;
      _organizationLogoController.text = widget.challenge!.organizationLogo;
      if (widget.challenge!.organizationLogo.startsWith('http')) {
        _logoPreviewUrl = widget.challenge!.organizationLogo;
      }
 
      _timelineController.text = widget.challenge!.timeline;
      _realWorldPrizeController.text = widget.challenge!.realWorldPrize ?? '';
      _coinRewardController.text = widget.challenge!.coinReward.toString();
      _coinCostController.text = widget.challenge!.coinCost.toString();
      _externalUrlController.text = widget.challenge!.externalJoinUrl ?? '';
      _validationMode = widget.challenge!.validationMode;
      _type = widget.challenge!.type;
      _startDate = widget.challenge!.startDate;
      _endDate = widget.challenge!.endDate;
      _isTeamChallenge = widget.challenge!.isTeamChallenge;
      _criteria = List<String>.from(widget.challenge!.criteria);
      // Load existing rules from Supabase for editing
      _loadExistingRules(widget.challenge!.id);
    } else {
      // Initialize new basic challenge with MLQ defaults from service
      _loadMlqDefaults();
    }
    // Preload organizations list for selector (non-blocking)
    _loadOrganizations();
  }

  Future<void> _loadMlqDefaults() async {
    try {
      final mlqId = await OrganizationSettingsService().getMlqOrganizationId();
      setState(() {
        _organizationIdController.text = mlqId;
        _organizationNameController.text = 'My Leadership Quest';
        _organizationLogoController.text = 'assets/images/questor.png';
      });
    } catch (e) {
      debugPrint('Failed to load MLQ defaults: $e');
      // Fallback to hardcoded values
      setState(() {
        _organizationIdController.text = '215d53ce-8500-4d7a-b280-e54e820b014a';
        _organizationNameController.text = 'My Leadership Quest';
        _organizationLogoController.text = 'assets/images/questor.png';
      });
    }
  }

  Future<void> _loadExistingRules(String challengeId) async {
    try {
      final rows = await Supabase.instance.client
          .from('challenge_rules')
          .select('*')
          .eq('challenge_id', challengeId)
          .order('created_at');
      setState(() {
        _rules = List<Map<String, dynamic>>.from(rows as List);
        // Detect mode from first rule
        if (_rules.isNotEmpty) {
          final wType = _rules.first['window_type'];
          if (wType == 'per_user_enrollment') {
            _challengeMode = 'evergreen';
          } else {
            _challengeMode = 'scheduled';
          }
        }
      });
    } catch (e) {
      debugPrint('Failed to load rules: $e');
    }
  }

  // Normalize a rule map to the expected DB payload shape (class-scope)
  Map<String, dynamic> _normalizedRuleMap(Map<String, dynamic> r) {
    final m = Map<String, dynamic>.from(r);
    // Coerce types and defaults
    m['rule_type'] = (m['rule_type'] ?? 'gratitude_streak_days').toString();
    m['target_value'] = int.tryParse('${m['target_value']}') ?? 1;
    m['consecutive_required'] = (m['consecutive_required'] ?? false) == true;
    m['window_type'] = (m['window_type'] ?? 'fixed_window').toString();
    m['window_value_days'] = m['window_type'] == 'rolling_days'
        ? (int.tryParse('${m['window_value_days']}') ?? 7)
        : null;
    m['max_gap_days'] = int.tryParse('${m['max_gap_days']}') ?? 0;
    final op = (m['group_operator'] ?? 'all').toString();
    m['group_operator'] = (op == 'any') ? 'any' : 'all';
    // Required by DB: metric_scope must be non-null. Derive sensible default from rule_type
    final ruleType = m['rule_type'] as String;
    switch (ruleType) {
      case 'daily_goal_streak_days':
      case 'daily_goal_count_in_window':
        m['metric_scope'] = 'daily_goals';
        break;
      case 'main_goals_completed':
      case 'main_goal_count_in_window':
        m['metric_scope'] = 'main_goals';
        break;
      case 'any_goals_completed':
        m['metric_scope'] = 'any_goals';
        break;
      case 'gratitude_streak_days':
        m['metric_scope'] = 'gratitude_entries';
        break;
      case 'gratitude_count_in_window':
        m['metric_scope'] = 'gratitude_entries';
        break;
      case 'mini_courses_completed':
        m['metric_scope'] = 'mini_courses';
        break;
      default:
        m['metric_scope'] = 'any_goals';
    }
    // Optional fields: set explicit defaults (the DB allows these columns)
    m['allow_backfill'] = (m['allow_backfill'] ?? false) == true;
    // category_filter can be null or string (e.g., 'health', 'social') depending on future templates
    if (m['category_filter'] != null) {
      m['category_filter'] = m['category_filter'].toString();
    }
    // group_id reserved for multi-rule challenges; keep null for single-rule templates
    if (m['group_id'] != null) {
      m['group_id'] = m['group_id'].toString();
    }
    // Do not remove metric_scope/allow_backfill/category_filter/group_id; they are valid DB columns
    return m;
  }

  // Rules editor UI for basic challenges: Template-based
  Widget _buildRulesEditor() {
    final templates = [
      {
        'title': 'Daily Goal Streak',
        'desc': 'Keep a streak of completing daily goals',
        'rule_type': 'daily_goal_streak_days',
        'supports_consecutive': true,
        'default_target': 3,
      },
      {
        'title': 'Daily Goals Count',
        'desc': 'Complete a number of daily goals',
        'rule_type': 'daily_goal_count_in_window',
        'supports_consecutive': false,
        'default_target': 10,
      },
      {
        'title': 'Gratitude Streak',
        'desc': 'Keep a daily gratitude streak',
        'rule_type': 'gratitude_streak_days',
        'supports_consecutive': true,
        'default_target': 3,
      },
      {
        'title': 'Gratitude Entries Count',
        'desc': 'Make a number of gratitude posts',
        'rule_type': 'gratitude_count_in_window',
        'supports_consecutive': false,
        'default_target': 3,
      },
      {
        'title': 'Main Goals Completed',
        'desc': 'Complete main goals during the challenge',
        'rule_type': 'main_goals_completed',
        'supports_consecutive': false,
        'default_target': 1,
      },
      {
        'title': 'Any Goals Completed',
        'desc': 'Complete daily or main goals',
        'rule_type': 'any_goals_completed',
        'supports_consecutive': false,
        'default_target': 5,
      },
      {
        'title': 'Mini-courses Completed',
        'desc': 'Finish mini-courses during the challenge',
        'rule_type': 'mini_courses_completed',
        'supports_consecutive': false,
        'default_target': 1,
      },
    ];

    // Helpers
    bool _matchesTemplateType(Map<String, dynamic> r, String type) {
      try {
        if ((r['rule_type'] as String?) != type) return false;
        // Allow DB-saved extra keys; only require core keys to be present
        final requiredCore = {'rule_type','target_value','window_type','group_operator'};
        for (final k in requiredCore) {
          if (!r.containsKey(k)) return false;
        }
        return true;
      } catch (_) { return false; }
    }

    // Derive current selection from first rule if compatible
    final current = _rules.isNotEmpty ? _rules.first : null;
    String? currentType;
    bool isCustom = false;
    if (current == null) {
      currentType = null;
    } else {
      // Single rule and matches one of our templates
      final types = templates.map((t) => t['rule_type'] as String).toList();
      final matchesAny = types.any((t) => _matchesTemplateType(current, t));
      if (!matchesAny || _rules.length != 1) {
        isCustom = true;
        currentType = null;
      } else {
        currentType = current['rule_type'] as String?;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Select a template', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (isCustom) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Custom rules detected',
                        style: AppTextStyles.bodyBold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'This challenge has rules that don\'t match any of our templates or contains multiple rules. You can keep them as-is, or replace with a template to simplify.',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Current: ${_rules.length} rule(s). Example: ${_humanSummary(_rules.first)}',
                        style: AppTextStyles.caption,
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        // Clear selection to force admin to choose a template
                        setState(() { _rules = []; });
                      },
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('Replace with Template'),
                    ),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: templates.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final t = templates[i];
            final isSelected = currentType == t['rule_type'];
            final controller = TextEditingController(text: '${isSelected ? (current?['target_value'] ?? t['default_target']) : t['default_target']}');
            bool supportsConsecutive = t['supports_consecutive'] == true;
            bool consecutive = supportsConsecutive && (isSelected ? (current?['consecutive_required'] == true) : true);

            return StatefulBuilder(
              builder: (ctx, setSt) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSelected ? AppColors.secondary : Colors.black12, width: isSelected ? 2 : 1),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(t['title'] as String, style: AppTextStyles.bodyBold),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle, color: AppColors.secondary),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(t['desc'] as String, style: AppTextStyles.caption),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: 120,
                            child: TextField(
                              controller: controller,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Target',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (val) {
                                final v = int.tryParse(val.trim());
                                if (isSelected && v != null) {
                                  setState(() {
                                    // keep current selected rule but update target_value
                                    final currentRule = Map<String, dynamic>.from(_rules.first);
                                    currentRule['target_value'] = v;
                                    _rules = [currentRule];
                                  });
                                }
                              },
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Text('Window: Challenge Period'),
                          ),
                          if (supportsConsecutive)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Consecutive'),
                                Switch(
                                  value: consecutive,
                                  onChanged: (v) {
                                    setSt(() => consecutive = v);
                                    if (isSelected) {
                                      setState(() {
                                        final currentRule = Map<String, dynamic>.from(_rules.first);
                                        currentRule['consecutive_required'] = v;
                                        _rules = [currentRule];
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check),
                          label: Text(isSelected ? 'Selected' : 'Use Template'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            final target = int.tryParse(controller.text.trim()) ?? (t['default_target'] as int);
                            final rule = {
                              'rule_type': t['rule_type'],
                              'target_value': target,
                              'consecutive_required': supportsConsecutive ? consecutive : false,
                              'window_type': _challengeMode == 'evergreen' ? 'per_user_enrollment' : 'fixed_window',
                              'window_value_days': null,
                              'max_gap_days': supportsConsecutive ? 0 : 0,
                              'group_operator': 'all',
                            };
                            setState(() {
                              _rules = [rule];
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 12),
        if (_rules.isNotEmpty)
          Text('Current rule: ${_humanSummary(_rules.first)}', style: AppTextStyles.caption),
      ],
    );
  }

  // Human-readable summary for a rule card
  String _humanSummary(Map<String, dynamic> r) {
    final type = (r['rule_type'] ?? '').toString();
    final target = (r['target_value'] ?? 0).toString();
    final windowType = (r['window_type'] ?? 'fixed_window').toString();
    final days = (r['window_value_days']?.toString() ?? '');
    switch (type) {
      case 'gratitude_streak_days':
        return 'Keep a $target-day gratitude streak' + _windowSuffix(windowType, days);
      case 'gratitude_count_in_window':
        return 'Make $target gratitude post(s)' + _windowSuffix(windowType, days);
      case 'daily_goal_streak_days':
        return 'Keep a $target-day streak of completing daily goals' + _windowSuffix(windowType, days);
      case 'main_goals_completed':
        return 'Complete $target main goals' + _windowSuffix(windowType, days);
      case 'any_goals_completed':
        return 'Complete $target goals (daily or main)' + _windowSuffix(windowType, days);
      case 'mini_courses_completed':
        return 'Complete $target mini-course(s)' + _windowSuffix(windowType, days);
      case 'daily_goal_count_in_window':
        return 'Complete $target daily goals' + _windowSuffix(windowType, days);
      case 'main_goal_count_in_window':
        return 'Complete $target main goals' + _windowSuffix(windowType, days);
      default:
        return 'Configure a rule';
    }
  }

  String _windowSuffix(String windowType, String days) {
    if (windowType == 'rolling_days') {
      return ' in the last ${days.isEmpty ? '?' : days} days';
    }
    if (windowType == 'per_user_enrollment') {
      return ' from when a user joins this challenge';
    }
    return ' during the challenge period';
  }

  Future<void> _loadOrganizations() async {
    try {
      setState(() => _loadingOrganizations = true);
      final rows = await Supabase.instance.client
          .from('organizations')
          .select('id, name, logo_url')
          .order('name');
      setState(() {
        _organizations = List<Map<String, dynamic>>.from(rows as List);
      });
    } catch (e) {
      debugPrint('Error loading organizations: $e');
    } finally {
      if (mounted) setState(() => _loadingOrganizations = false);
    }
  }

  void _openSelectOrganization() async {
    if (_organizations.isEmpty && !_loadingOrganizations) {
      await _loadOrganizations();
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.apartment, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Text('Select Organization', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 8),
              if (_loadingOrganizations)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                )
              else if (_organizations.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No organizations yet. Use "Register new" to add one.'),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _organizations.length,
                    itemBuilder: (c, i) {
                      final org = _organizations[i];
                      return ListTile(
                        leading: (org['logo_url'] != null && (org['logo_url'] as String).isNotEmpty)
                            ? CircleAvatar(backgroundImage: NetworkImage(org['logo_url']))
                            : const CircleAvatar(child: Icon(Icons.business)),
                        title: Text(org['name'] ?? 'Unnamed'),
                        subtitle: Text(org['id'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () {
                          _organizationIdController.text = org['id'] ?? '';
                          _organizationNameController.text = org['name'] ?? '';
                          final logoUrl = (org['logo_url'] ?? '') as String;
                          if (logoUrl.isNotEmpty) {
                            _logoPreviewUrl = logoUrl;
                            _organizationLogoController.text = logoUrl;
                          }
                          Navigator.pop(ctx);
                          setState(() {});
                        },
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _openRegisterOrganization();
                  },
                  icon: const Icon(Icons.add_business),
                  label: const Text('Register new'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openRegisterOrganization() {
    final nameCtrl = TextEditingController();
    String? previewUrl;
    bool uploading = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSt) {
            Future<void> pickLogo() async {
              final picker = ImagePicker();
              final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
              if (x != null) {
                setSt(() => uploading = true);
                final bytes = await x.readAsBytes();
                final url = await OrganizationSettingsService.instance.uploadPublicAsset(bytes, x.name, folder: 'logos/organizations');
                if (url != null) previewUrl = url;
                setSt(() => uploading = false);
              }
            }

            Future<void> saveOrg() async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter organization name'), backgroundColor: Colors.red),
                );
                return;
              }
              try {
                final id = const Uuid().v4();
                final insert = {
                  'id': id,
                  'name': name,
                  'logo_url': previewUrl,
                  'created_at': DateTime.now().toIso8601String(),
                };
                await Supabase.instance.client.from('organizations').insert(insert);
                await _loadOrganizations();
                _organizationIdController.text = id;
                _organizationNameController.text = name;
                if (previewUrl != null) {
                  _logoPreviewUrl = previewUrl;
                  _organizationLogoController.text = previewUrl!;
                }
                if (mounted) Navigator.pop(ctx);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to register organization: $e'), backgroundColor: Colors.red),
                );
              }
            }

            return AlertDialog(
              title: const Text('Register Organization'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Organization Name', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 48, height: 48, clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.white, border: Border.all(color: Colors.black12)),
                        child: previewUrl != null
                            ? Image.network(previewUrl!, fit: BoxFit.cover)
                            : const Icon(Icons.image, color: Colors.grey),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: uploading ? null : pickLogo,
                          icon: uploading
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.upload_file),
                          label: Text(uploading ? 'Uploading...' : 'Upload Logo'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary, foregroundColor: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(onPressed: uploading ? null : saveOrg, child: const Text('Save')),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _organizationIdController.dispose();
    _organizationNameController.dispose();
    _organizationLogoController.dispose();
    _timelineController.dispose();
    _realWorldPrizeController.dispose();
    _coinRewardController.dispose();
    _coinCostController.dispose();
    _externalUrlController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: isStartDate ? DateTime.now() : _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          // Ensure end date is not before start date
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate.add(const Duration(days: 1));
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _addCriterion() {
    setState(() {
      _criteria.add('');
    });
  }

  void _removeCriterion(int index) {
    setState(() {
      _criteria.removeAt(index);
    });
  }

  void _updateCriterion(int index, String value) {
    setState(() {
      _criteria[index] = value;
    });
  }

  Future<void> _pickAndUploadLogo() async {
    try {
      setState(() => _isUploadingLogo = true);
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (picked == null) {
        setState(() => _isUploadingLogo = false);
        return;
      }
      final bytes = await picked.readAsBytes();
      final url = await OrganizationSettingsService.instance
          .uploadPublicAsset(bytes, picked.name, folder: 'logos/sponsors');
      if (url == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to upload logo. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        setState(() {
          _logoPreviewUrl = url;
          _organizationLogoController.text = url;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logo uploaded successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logo upload error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploadingLogo = false);
    }
  }

  Future<void> _saveChallenge() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Production safety: basic challenges must have a selected template rule
    if (_type == ChallengeType.basic && _rules.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a Basic Challenge template and set a target before saving.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Create challenge model from form data
      final challenge = ChallengeModel(
        id: widget.challenge?.id ?? const Uuid().v4(),
        title: _titleController.text,
        description: _descriptionController.text,
        type: _type,
        realWorldPrize: _realWorldPrizeController.text.isEmpty ? null : _realWorldPrizeController.text,
        startDate: _startDate,
        endDate: _endDate,
        participantsCount: widget.challenge?.participantsCount ?? 0,
        organizationId: _organizationIdController.text,
        organizationName: _organizationNameController.text,
        organizationLogo: _organizationLogoController.text,
        // For basic challenges, criteria is determined by the template rules; avoid free-form criteria.
        criteria: _type == ChallengeType.basic ? [] : _criteria.where((c) => c.isNotEmpty).toList(),
        timeline: _timelineController.text,
        isTeamChallenge: _isTeamChallenge,
        coinReward: int.tryParse(_coinRewardController.text) ?? 0,
        validationMode: _type == ChallengeType.premium ? _validationMode : 'in_app',
        coinCost: _type == ChallengeType.premium ? (double.tryParse(_coinCostController.text) ?? 0.0) : 0.0,
        externalJoinUrl: (_type == ChallengeType.premium && _validationMode == 'external')
            ? (_externalUrlController.text.trim().isEmpty ? null : _externalUrlController.text.trim())
            : null,
      );

      bool success;
      if (widget.challenge == null) {
        // Create new challenge
        success = await AdminService.instance.createChallenge(challenge);
      } else {
        // Update existing challenge
        success = await AdminService.instance.updateChallenge(widget.challenge!.id, challenge);
      }
      if (success && mounted) {
        // Persist structured rules for basic challenges
        if (_type == ChallengeType.basic) {
          final mappedRules = _rules.map((r) => _normalizedRuleMap(r)).toList();
          
          // Validate rules before sending to DB
          const allowedWindows = {'fixed_window','rolling_days','per_user_enrollment'};
          for (final r in mappedRules) {
            final tgt = (r['target_value'] as int?) ?? 0;
            final wtype = (r['window_type'] as String?) ?? 'fixed_window';
            final scope = r['metric_scope'];
            
            // Validate target range (1-1000)
            if (tgt < 1 || tgt > 1000) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Target must be between 1 and 1000.'),
                  backgroundColor: Colors.red,
                ),
              );
              setState(() { _isLoading = false; });
              return;
            }
            
            if (!allowedWindows.contains(wtype)) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Invalid window type: $wtype'),
                  backgroundColor: Colors.red,
                ),
              );
              setState(() { _isLoading = false; });
              return;
            }
            
            if (scope == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Internal error: metric_scope not set. Please reselect the template.'),
                  backgroundColor: Colors.red,
                ),
              );
              setState(() { _isLoading = false; });
              return;
            }
          }
          
          // Save rules to database
          final ok = await AdminService.instance.replaceChallengeRules(challenge.id, mappedRules);
          if (!ok) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to save structured rules. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
            setState(() { _isLoading = false; });
            return;
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.challenge == null
                ? 'Challenge created successfully'
                : 'Challenge updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.challenge == null
                ? 'Failed to create challenge'
                : 'Failed to update challenge'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.challenge == null ? 'Create Challenge' : 'Edit Challenge'),
        backgroundColor: AppColors.primary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Basic Information Section
                    _buildSectionHeader('Basic Information'),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Challenge Title',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 4,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a description';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<ChallengeType>(
                      value: _type,
                      decoration: const InputDecoration(
                        labelText: 'Challenge Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: ChallengeType.basic,
                          child: Text('Basic Challenge'),
                        ),
                        DropdownMenuItem(
                          value: ChallengeType.premium,
                          child: Text('Premium Challenge'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _type = value!;
                          // Auto-set organization details based on challenge type
                          if (_type == ChallengeType.basic) {
                            _organizationIdController.text = '215d53ce-8500-4d7a-b280-e54e820b014a'; // MLQ UUID
                            _organizationNameController.text = 'My Leadership Quest';
                            _organizationLogoController.text = 'assets/images/questor.png';
                          } else {
                            // Clear fields for premium challenges to allow custom input
                            if (_organizationIdController.text == '215d53ce-8500-4d7a-b280-e54e820b014a') {
                              _organizationIdController.clear();
                              _organizationNameController.clear();
                              _organizationLogoController.clear();
                            }
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    // Challenge Mode Selection (Scheduled vs Evergreen)
                    if (_type == ChallengeType.basic) ...[
                      DropdownButtonFormField<String>(
                        value: _challengeMode,
                        decoration: const InputDecoration(
                          labelText: 'Challenge Mode',
                          border: OutlineInputBorder(),
                          helperText: 'Scheduled: Fixed start/end dates for everyone.\nEvergreen: Users start when they join (self-paced).',
                          helperMaxLines: 2,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'scheduled',
                            child: Text('Scheduled (Fixed Dates)'),
                          ),
                          DropdownMenuItem(
                            value: 'evergreen',
                            child: Text('Evergreen (Self-Paced)'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _challengeMode = value!;
                            // Update existing rules if any to match new mode
                            if (_rules.isNotEmpty) {
                              final updatedRules = _rules.map((r) {
                                final m = Map<String, dynamic>.from(r);
                                m['window_type'] = _challengeMode == 'evergreen' 
                                    ? 'per_user_enrollment' 
                                    : 'fixed_window';
                                return m;
                              }).toList();
                              _rules = updatedRules;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _timelineController,
                            decoration: const InputDecoration(
                              labelText: 'Timeline (e.g., "2 weeks")',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a timeline';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: SwitchListTile(
                            title: const Text('Team Challenge'),
                            value: _isTeamChallenge,
                            onChanged: (value) {
                              setState(() {
                                _isTeamChallenge = value;
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),

                    // Basic Challenge Rules (structured)
                    if (_type == ChallengeType.basic) ...[
                      const SizedBox(height: 24),
                      _buildSectionHeader('Basic Challenge Rules (Structured)'),
                      const SizedBox(height: 8),
                      _buildRulesEditor(),
                    ],

                    // Dates Section
                    const SizedBox(height: 24),
                    _buildSectionHeader('Challenge Dates'),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDate(context, true),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Start Date',
                                border: OutlineInputBorder(),
                              ),
                              child: Text(
                                DateFormat('MMM dd, yyyy').format(_startDate),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDate(context, false),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'End Date',
                                border: OutlineInputBorder(),
                              ),
                              child: Text(
                                DateFormat('MMM dd, yyyy').format(_endDate),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Organization Section
                    const SizedBox(height: 24),
                    _buildSectionHeader('Organization Information'),
                    // Organization fields - auto-filled for basic challenges, editable for premium
                    // Organization selection with read-only ID and actions
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Organization',
                        border: OutlineInputBorder(),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _organizationNameController.text.isNotEmpty
                                ? _organizationNameController.text
                                : (_type == ChallengeType.basic ? 'My Leadership Quest' : 'No organization selected'),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          SelectableText(
                            _organizationIdController.text.isNotEmpty ? _organizationIdController.text : '—',
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                          const SizedBox(height: 8),
                          if (_type == ChallengeType.premium)
                            Wrap(
                              spacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _openSelectOrganization,
                                  icon: const Icon(Icons.apartment),
                                  label: const Text('Select existing'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _openRegisterOrganization,
                                  icon: const Icon(Icons.add_business),
                                  label: const Text('Register new'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _organizationNameController,
                      enabled: _type == ChallengeType.premium,
                      decoration: InputDecoration(
                        labelText: 'Organization Name',
                        border: const OutlineInputBorder(),
                        helperText: _type == ChallengeType.basic 
                            ? 'Auto-set for basic challenges (My Leadership Quest)' 
                            : 'Enter sponsor organization name',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an organization name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Organization Logo Picker (Premium only)
                    if (_type == ChallengeType.premium) ...[
                      Text(
                        'Organization Logo',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // Preview
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white,
                              border: Border.all(color: Colors.black12),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _logoPreviewUrl != null && _logoPreviewUrl!.startsWith('http')
                                ? Image.network(_logoPreviewUrl!, fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) => const Icon(Icons.broken_image))
                                : (_organizationLogoController.text.isNotEmpty && _organizationLogoController.text.startsWith('assets/')
                                    ? Image.asset(_organizationLogoController.text, fit: BoxFit.cover,
                                        errorBuilder: (c, e, s) => const Icon(Icons.image_not_supported))
                                    : const Icon(Icons.image, color: Colors.grey)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _logoPreviewUrl ?? (_organizationLogoController.text.isNotEmpty
                                      ? _organizationLogoController.text
                                      : 'No logo selected'),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                                ),
                                const SizedBox(height: 6),
                                ElevatedButton.icon(
                                  onPressed: _isUploadingLogo ? null : _pickAndUploadLogo,
                                  icon: _isUploadingLogo
                                      ? const SizedBox(
                                          width: 16, height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Icon(Icons.upload_file),
                                  label: Text(_isUploadingLogo ? 'Uploading...' : 'Upload from Gallery'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.secondary,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Hidden validator to ensure we have a logo value
                      Builder(
                        builder: (_) => TextFormField(
                          controller: _organizationLogoController,
                          readOnly: true,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Logo URL (auto-filled after upload)',
                          ),
                          validator: (value) {
                            if (_type == ChallengeType.premium && (value == null || value.isEmpty)) {
                              return 'Please upload a sponsor logo';
                            }
                            return null;
                          },
                        ),
                      ),
                    ] else ...[
                      // Basic challenge: show read-only default
                      TextFormField(
                        controller: _organizationLogoController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Organization Logo',
                          border: OutlineInputBorder(),
                          helperText: 'Basic challenges use the MLQ/Questor logo automatically',
                        ),
                      ),
                    ],

                    // Rewards Section
                    const SizedBox(height: 24),
                    _buildSectionHeader('Rewards & Requirements'),
                    TextFormField(
                      controller: _coinRewardController,
                      decoration: const InputDecoration(
                        labelText: 'Coin Reward',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a coin reward';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_type == ChallengeType.premium) ...[
                      // Premium-only settings (DB-aligned)
                      _buildSectionHeader('Premium Settings'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _validationMode,
                        decoration: const InputDecoration(
                          labelText: 'Validation Mode',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'in_app', child: Text('In-app (coin-gated)')),
                          DropdownMenuItem(value: 'external', child: Text('External (redirect URL)')),
                        ],
                        onChanged: (v) => setState(() => _validationMode = v ?? 'in_app'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _coinCostController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Coin Cost (to join)',
                          border: OutlineInputBorder(),
                          hintText: 'e.g. 100',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Please enter a coin cost';
                          final d = double.tryParse(v);
                          if (d == null || d < 0) return 'Enter a valid non-negative number';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      if (_validationMode == 'external')
                        TextFormField(
                          controller: _externalUrlController,
                          decoration: const InputDecoration(
                            labelText: 'External Join URL',
                            border: OutlineInputBorder(),
                            hintText: 'https://sponsor-site.com/offer/unique-path',
                          ),
                          validator: (v) {
                            if (_validationMode == 'external') {
                              if (v == null || v.trim().isEmpty) return 'External URL is required for external validation';
                            }
                            return null;
                          },
                        ),
                    ],
                    TextFormField(
                      controller: _realWorldPrizeController,
                      decoration: const InputDecoration(
                        labelText: 'Real World Prize (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    // Criteria Section
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionHeader('Completion Criteria'),
                        TextButton.icon(
                          onPressed: _addCriterion,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Criterion'),
                        ),
                      ],
                    ),
                    ..._criteria.asMap().entries.map((entry) {
                      final index = entry.key;
                      final criterion = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                initialValue: criterion,
                                decoration: InputDecoration(
                                  labelText: 'Criterion ${index + 1}',
                                  border: const OutlineInputBorder(),
                                ),
                                onChanged: (value) => _updateCriterion(index, value),
                                validator: (value) {
                                  if (index == 0 && (value == null || value.isEmpty)) {
                                    return 'Please enter at least one criterion';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            if (_criteria.length > 1)
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _removeCriterion(index),
                              ),
                          ],
                        ),
                      );
                    }).toList(),

                    // Submit Button
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _saveChallenge,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          widget.challenge == null ? 'Create Challenge' : 'Update Challenge',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
