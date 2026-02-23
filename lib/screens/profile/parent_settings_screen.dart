import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../../providers/providers.dart';
import '../../services/push_notification_service.dart';

class ParentSettingsScreen extends StatefulWidget {
  const ParentSettingsScreen({super.key});

  @override
  State<ParentSettingsScreen> createState() => _ParentSettingsScreenState();
}

class _ParentSettingsScreenState extends State<ParentSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _weeklyReportsEnabled = false;
  bool _isLoading = false;
  String? _selectedTimezone;
  int? _selectedDow; // 0-6 Sunday-Saturday
  TimeOfDay? _selectedTime;

  // Curated list of common IANA timezones
  static const List<String> _timezones = [
    'UTC',
    'Europe/London',
    'Europe/Paris',
    'America/New_York',
    'America/Chicago',
    'America/Denver',
    'America/Los_Angeles',
    'America/Toronto',
    'America/Sao_Paulo',
    'Africa/Lagos',
    'Africa/Johannesburg',
    'Asia/Dubai',
    'Asia/Kolkata',
    'Asia/Singapore',
    'Asia/Tokyo',
    'Australia/Sydney',
    'Pacific/Auckland',
  ];

  @override
  void initState() {
    super.initState();
    // Load current settings
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentSettings();
    });
  }

  // Trigger a single test weekly report via Edge Function for the current user
  Future<void> _sendTestReportNow() async {
    debugPrint('[ParentSettings] 🧪 Test report button clicked');
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final user = userProvider.user;
      
      debugPrint('[ParentSettings] User: ${user?.name} (${user?.id})');
      
      if (user == null) {
        debugPrint('[ParentSettings] ❌ No user signed in');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Please sign in to send a test report.'), backgroundColor: Colors.red),
        );
        return;
      }

      // Require parent email configured
      final email = _emailController.text.trim();
      debugPrint('[ParentSettings] Parent email from field: $email');
      
      if (email.isEmpty) {
        debugPrint('[ParentSettings] ❌ No parent email entered');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Enter a parent email first, then try again.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      setState(() => _isLoading = true);

      // Use Functions endpoint (verify_jwt=true requires Authorization header)
      const functionsBase = 'https://hcvyumbkonrisrxbjnst.functions.supabase.co';
      // Append force=true so testing is possible even if weekly reports toggle is off
      final uri = Uri.parse('$functionsBase/send-weekly-report?user_id=${user.id}&force=true');

      debugPrint('[ParentSettings] Calling Edge Function: $uri');

      final accessToken = Supabase.instance.client.auth.currentSession?.accessToken;
      final headers = <String, String>{
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      };

      debugPrint('[ParentSettings] Has access token: ${accessToken != null}');

      final resp = await http.get(uri, headers: headers);
      
      debugPrint('[ParentSettings] Response status: ${resp.statusCode}');
      debugPrint('[ParentSettings] Response body: ${resp.body}');
      
      if (!mounted) return;

      if (resp.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Test report sent to $email!\n${resp.body.length < 180 ? resp.body : 'Check your inbox (and spam folder).'}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to send test report (${resp.statusCode}).\n${resp.body}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('[ParentSettings] ❌ Error sending test report: $e');
      debugPrint('[ParentSettings] Stack trace: $stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _loadCurrentSettings() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.user;
    if (user != null) {
      setState(() {
        _emailController.text = user.parentEmail ?? '';
        _weeklyReportsEnabled = user.weeklyReportsEnabled;
        _selectedTimezone = user.timezone;
        _selectedDow = user.preferredSendDow;
        if (user.preferredSendHour != null && user.preferredSendMinute != null) {
          _selectedTime = TimeOfDay(
            hour: user.preferredSendHour!,
            minute: user.preferredSendMinute!,
          );
        }
      });
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // When weekly reports are enabled, require email, timezone, day and time
    if (_weeklyReportsEnabled) {
      final email = _emailController.text.trim();
      if (email.isEmpty || _selectedTimezone == null || _selectedDow == null || _selectedTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please provide parent email, timezone, day and time.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      
      debugPrint('[ParentSettings] Saving settings...');
      debugPrint('[ParentSettings] Email: ${_emailController.text.trim()}');
      debugPrint('[ParentSettings] Enabled: $_weeklyReportsEnabled');
      debugPrint('[ParentSettings] Timezone: $_selectedTimezone');
      debugPrint('[ParentSettings] Day: $_selectedDow');
      debugPrint('[ParentSettings] Time: ${_selectedTime?.hour}:${_selectedTime?.minute}');
      
      // Update user with new parent email settings (AWAIT the call)
      await userProvider.updateUserProfile(
        parentEmail: _emailController.text.trim(),
        weeklyReportsEnabled: _weeklyReportsEnabled,
        timezone: _selectedTimezone,
        preferredSendDow: _selectedDow,
        preferredSendHour: _selectedTime?.hour,
        preferredSendMinute: _selectedTime?.minute,
      );

      debugPrint('[ParentSettings] Profile updated successfully');

      // Schedule daily local goal reminder using the chosen time/timezone (if provided)
      // Cancel previous schedule first
      try {
        await PushNotificationService.instance.cancelDailyGoalReminder();
        if (_selectedTime != null) {
          await PushNotificationService.instance.scheduleDailyGoalReminder(
            time: _selectedTime!,
            timezone: _selectedTimezone,
          );
        }
        debugPrint('[ParentSettings] Notifications scheduled');
      } catch (notifError) {
        debugPrint('[ParentSettings] Notification scheduling failed (non-critical): $notifError');
        // Don't fail the whole save if notification scheduling fails
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Settings saved!\nEmail: ${_emailController.text.trim()}\nReports: ${_weeklyReportsEnabled ? "Enabled" : "Disabled"}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e, stackTrace) {
      // Show error message with details
      debugPrint('[ParentSettings] ERROR saving settings: $e');
      debugPrint('[ParentSettings] Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error updating settings: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent Settings'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Parent Email Settings',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Configure parent email for weekly progress reports',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Email input
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Parent Email',
                  hintText: 'Enter parent email address',
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return null; // Email is optional
                  }
                  
                  // Simple email validation
                  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                  if (!emailRegex.hasMatch(value)) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 24),
              
              // Weekly reports toggle
              SwitchListTile(
                title: const Text('Weekly Progress Reports'),
                subtitle: const Text(
                  'Send weekly goal progress reports to the parent email',
                ),
                value: _weeklyReportsEnabled,
                onChanged: (value) {
                  setState(() {
                    _weeklyReportsEnabled = value;
                  });
                },
                secondary: Icon(
                  Icons.assessment_rounded,
                  color: theme.colorScheme.secondary,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.5),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              // Scheduling options when enabled
              if (_weeklyReportsEnabled) ...[
                // Timezone selector
                DropdownButtonFormField<String>(
                  value: _selectedTimezone,
                  decoration: InputDecoration(
                    labelText: 'Timezone',
                    prefixIcon: const Icon(Icons.public),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: _timezones
                      .map((tz) => DropdownMenuItem(
                            value: tz,
                            child: Text(tz),
                          ))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedTimezone = val),
                  validator: (val) {
                    if (_weeklyReportsEnabled && (val == null || val.isEmpty)) {
                      return 'Please select a timezone';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Day of week selector
                DropdownButtonFormField<int>(
                  value: _selectedDow,
                  decoration: InputDecoration(
                    labelText: 'Preferred Day of Week',
                    prefixIcon: const Icon(Icons.event),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: List.generate(7, (i) => i)
                      .map((i) => DropdownMenuItem(
                            value: i,
                            child: Text(_dowLabel(i)),
                          ))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedDow = val),
                  validator: (val) {
                    if (_weeklyReportsEnabled && val == null) {
                      return 'Please choose a day';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Time selector
                _TimePickerField(
                  label: 'Preferred Time',
                  value: _selectedTime,
                  onPick: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _selectedTime ?? const TimeOfDay(hour: 9, minute: 0),
                    );
                    if (picked != null) {
                      setState(() => _selectedTime = picked);
                    }
                  },
                  validator: () {
                    if (_weeklyReportsEnabled && _selectedTime == null) {
                      return 'Please pick a time';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Report preview
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.tertiary.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weekly Report Preview',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_selectedTimezone != null && _selectedDow != null && _selectedTime != null)
                        Text(
                          'Scheduled: ${_dowLabel(_selectedDow!)} at ${_selectedTime!.format(context)} ($_selectedTimezone)',
                          style: theme.textTheme.bodyMedium,
                        ),
                      const SizedBox(height: 8),
                      const Text(
                        'Reports include:',
                      ),
                      const SizedBox(height: 4),
                      _buildReportFeature(
                        context, 
                        'Goal completion statistics',
                        Icons.check_circle_outline,
                      ),
                      _buildReportFeature(
                        context, 
                        'Progress on main goals',
                        Icons.trending_up,
                      ),
                      _buildReportFeature(
                        context, 
                        'Strengths and areas for improvement',
                        Icons.psychology,
                      ),
                      _buildReportFeature(
                        context, 
                        'Weekly activity summary',
                        Icons.calendar_today,
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 32),
              
              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Save Settings'),
                ),
              ),

              const SizedBox(height: 12),
              // Send test report now
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _sendTestReportNow,
                  icon: const Icon(Icons.send),
                  label: const Text('Send test report now'),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Privacy note
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.privacy_tip_outlined,
                      color: Colors.grey[600],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Email is only used for sending progress reports and will not be shared with third parties.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildReportFeature(BuildContext context, String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Theme.of(context).colorScheme.tertiary,
          ),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }

  // Helper: Convert 0-6 to weekday label (Sunday-Saturday)
  String _dowLabel(int dow) {
    switch (dow) {
      case 0:
        return 'Sunday';
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      default:
        return 'Sunday';
    }
  }
}

// Reusable time picker form field with validation support
class _TimePickerField extends StatelessWidget {
  final String label;
  final TimeOfDay? value;
  final VoidCallback onPick;
  final String? Function()? validator;

  const _TimePickerField({
    required this.label,
    required this.value,
    required this.onPick,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final display = value != null ? value!.format(context) : '';
    return TextFormField(
      readOnly: true,
      controller: TextEditingController(text: display),
      decoration: InputDecoration(
        labelText: label,
        hintText: 'Select time',
        prefixIcon: const Icon(Icons.access_time),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onTap: onPick,
      validator: (_) => validator?.call(),
    );
  }
}
