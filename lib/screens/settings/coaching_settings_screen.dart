import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/unified_autonomous_coach.dart';
import '../../theme/app_colors.dart';
import '../legal/legal_markdown_screen.dart';

/// Screen for managing autonomous coaching settings
class CoachingSettingsScreen extends StatefulWidget {
  const CoachingSettingsScreen({Key? key}) : super(key: key);

  @override
  State<CoachingSettingsScreen> createState() => _CoachingSettingsScreenState();
}

class _CoachingSettingsScreenState extends State<CoachingSettingsScreen> {
  bool _isCoachingEnabled = true;
  bool _isAdvancedModeEnabled = true;
  bool _isPredictiveCoachingEnabled = true;
  bool _isEmotionalIntelligenceEnabled = true;
  bool _isScheduledMessagesEnabled = true;
  
  // Notification preferences
  bool _morningBoostEnabled = true;
  bool _middayCheckEnabled = true;
  bool _eveningReflectionEnabled = true;
  
  // Advanced settings
  int _messagingFrequency = 3; // Messages per day
  bool _urgentNotificationsEnabled = true;
  bool _personalityAdaptationEnabled = true;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Widget _buildLegalCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ListTile(
              title: Text(
                'Legal',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Terms & Conditions'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TermsScreen()),
                );
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacy Policy'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                );
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Refund Policy'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RefundPolicyScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    setState(() {
      _isCoachingEnabled = prefs.getBool('coaching_enabled') ?? true;
      _isAdvancedModeEnabled = prefs.getBool('advanced_mode_enabled') ?? true;
      _isPredictiveCoachingEnabled = prefs.getBool('predictive_coaching_enabled') ?? true;
      _isEmotionalIntelligenceEnabled = prefs.getBool('emotional_intelligence_enabled') ?? true;
      _isScheduledMessagesEnabled = prefs.getBool('scheduled_messages_enabled') ?? true;
      
      _morningBoostEnabled = prefs.getBool('morning_boost_enabled') ?? true;
      _middayCheckEnabled = prefs.getBool('midday_check_enabled') ?? true;
      _eveningReflectionEnabled = prefs.getBool('evening_reflection_enabled') ?? true;
      
      _messagingFrequency = prefs.getInt('messaging_frequency') ?? 3;
      _urgentNotificationsEnabled = prefs.getBool('urgent_notifications_enabled') ?? true;
      _personalityAdaptationEnabled = prefs.getBool('personality_adaptation_enabled') ?? true;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setBool('coaching_enabled', _isCoachingEnabled);
    await prefs.setBool('advanced_mode_enabled', _isAdvancedModeEnabled);
    await prefs.setBool('predictive_coaching_enabled', _isPredictiveCoachingEnabled);
    await prefs.setBool('emotional_intelligence_enabled', _isEmotionalIntelligenceEnabled);
    await prefs.setBool('scheduled_messages_enabled', _isScheduledMessagesEnabled);
    
    await prefs.setBool('morning_boost_enabled', _morningBoostEnabled);
    await prefs.setBool('midday_check_enabled', _middayCheckEnabled);
    await prefs.setBool('evening_reflection_enabled', _eveningReflectionEnabled);
    
    await prefs.setInt('messaging_frequency', _messagingFrequency);
    await prefs.setBool('urgent_notifications_enabled', _urgentNotificationsEnabled);
    await prefs.setBool('personality_adaptation_enabled', _personalityAdaptationEnabled);
    
    // Apply settings to unified coach
    _applySettingsToCoach();
    
    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Coaching settings saved successfully! 🎯'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _applySettingsToCoach() {
    final unifiedCoach = UnifiedAutonomousCoach.instance;
    
    if (_isCoachingEnabled) {
      unifiedCoach.enable();
      unifiedCoach.setAdvancedMode(_isAdvancedModeEnabled);
    } else {
      unifiedCoach.disable();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Coaching Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Colors.white),
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 16),
            _buildBasicSettingsCard(),
            const SizedBox(height: 16),
            _buildAdvancedSettingsCard(),
            const SizedBox(height: 16),
            _buildScheduleSettingsCard(),
            const SizedBox(height: 16),
            _buildPrivacySettingsCard(),
            const SizedBox(height: 16),
            _buildLegalCard(),
            const SizedBox(height: 24),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.psychology,
              size: 48,
              color: Colors.white,
            ),
            const SizedBox(height: 12),
            const Text(
              'Questor AI Coach Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Customize your autonomous coaching experience',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.9),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicSettingsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Basic Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            _buildSwitchTile(
              title: 'Enable Autonomous Coaching',
              subtitle: 'Allow Questor to send proactive coaching messages',
              value: _isCoachingEnabled,
              onChanged: (value) => setState(() => _isCoachingEnabled = value),
              icon: Icons.smart_toy,
            ),
            _buildSwitchTile(
              title: 'Advanced AI Mode',
              subtitle: 'Enable predictive coaching and emotional intelligence',
              value: _isAdvancedModeEnabled,
              onChanged: _isCoachingEnabled 
                ? (value) => setState(() => _isAdvancedModeEnabled = value)
                : null,
              icon: Icons.psychology,
            ),
            _buildSwitchTile(
              title: 'Scheduled Messages',
              subtitle: 'Receive messages at set times throughout the day',
              value: _isScheduledMessagesEnabled,
              onChanged: _isCoachingEnabled 
                ? (value) => setState(() => _isScheduledMessagesEnabled = value)
                : null,
              icon: Icons.schedule,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedSettingsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Advanced Features',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            _buildSwitchTile(
              title: 'Predictive Coaching',
              subtitle: 'AI anticipates your needs and provides proactive support',
              value: _isPredictiveCoachingEnabled,
              onChanged: (_isCoachingEnabled && _isAdvancedModeEnabled) 
                ? (value) => setState(() => _isPredictiveCoachingEnabled = value)
                : null,
              icon: Icons.auto_awesome,
            ),
            _buildSwitchTile(
              title: 'Emotional Intelligence',
              subtitle: 'Questor adapts responses based on your emotional state',
              value: _isEmotionalIntelligenceEnabled,
              onChanged: (_isCoachingEnabled && _isAdvancedModeEnabled) 
                ? (value) => setState(() => _isEmotionalIntelligenceEnabled = value)
                : null,
              icon: Icons.favorite,
            ),
            _buildSwitchTile(
              title: 'Personality Adaptation',
              subtitle: 'Questor\'s personality evolves based on your interactions',
              value: _personalityAdaptationEnabled,
              onChanged: (_isCoachingEnabled && _isAdvancedModeEnabled) 
                ? (value) => setState(() => _personalityAdaptationEnabled = value)
                : null,
              icon: Icons.face,
            ),
            _buildSwitchTile(
              title: 'Urgent Notifications',
              subtitle: 'Receive immediate alerts for important insights',
              value: _urgentNotificationsEnabled,
              onChanged: (_isCoachingEnabled && _isAdvancedModeEnabled) 
                ? (value) => setState(() => _urgentNotificationsEnabled = value)
                : null,
              icon: Icons.priority_high,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleSettingsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Message Schedule',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            _buildSwitchTile(
              title: 'Morning Boost (9:00 AM)',
              subtitle: 'Start your day with motivation and goal reminders',
              value: _morningBoostEnabled,
              onChanged: (_isCoachingEnabled && _isScheduledMessagesEnabled) 
                ? (value) => setState(() => _morningBoostEnabled = value)
                : null,
              icon: Icons.wb_sunny,
            ),
            _buildSwitchTile(
              title: 'Midday Check-in (1:00 PM)',
              subtitle: 'Progress updates and afternoon encouragement',
              value: _middayCheckEnabled,
              onChanged: (_isCoachingEnabled && _isScheduledMessagesEnabled) 
                ? (value) => setState(() => _middayCheckEnabled = value)
                : null,
              icon: Icons.access_time,
            ),
            _buildSwitchTile(
              title: 'Evening Reflection (7:00 PM)',
              subtitle: 'Daily reflection and preparation for tomorrow',
              value: _eveningReflectionEnabled,
              onChanged: (_isCoachingEnabled && _isScheduledMessagesEnabled) 
                ? (value) => setState(() => _eveningReflectionEnabled = value)
                : null,
              icon: Icons.nightlight_round,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacySettingsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Privacy & Data',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.security, color: Colors.green.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Privacy is Protected',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'All data is anonymized before AI processing. Personal information stays on your device.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
    required IconData icon,
  }) {
    final isEnabled = onChanged != null;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SwitchListTile(
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isEnabled ? Colors.black87 : Colors.grey,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: isEnabled ? Colors.grey[600] : Colors.grey[400],
          ),
        ),
        secondary: Icon(
          icon,
          color: isEnabled ? AppColors.primary : Colors.grey,
        ),
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _saveSettings,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.save),
            SizedBox(width: 8),
            Text(
              'Save Settings',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
