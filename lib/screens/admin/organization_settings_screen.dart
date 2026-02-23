import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_constants.dart';
import '../../providers/organization_settings_provider.dart';
import '../../widgets/widgets.dart';

class OrganizationSettingsScreen extends StatefulWidget {
  const OrganizationSettingsScreen({super.key});

  @override
  State<OrganizationSettingsScreen> createState() => _OrganizationSettingsScreenState();
}

class _OrganizationSettingsScreenState extends State<OrganizationSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _organizationNameController = TextEditingController();
  final _welcomeMessageController = TextEditingController();
  final _primaryColorController = TextEditingController();
  final _secondaryColorController = TextEditingController();
  
  bool _isLoading = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  @override
  void dispose() {
    _organizationNameController.dispose();
    _welcomeMessageController.dispose();
    _primaryColorController.dispose();
    _secondaryColorController.dispose();
    super.dispose();
  }

  void _loadCurrentSettings() {
    final provider = Provider.of<OrganizationSettingsProvider>(context, listen: false);
    
    _organizationNameController.text = provider.organizationName;
    _welcomeMessageController.text = provider.welcomeMessage;
    _primaryColorController.text = provider.primaryColor;
    _secondaryColorController.text = provider.secondaryColor;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Organization Settings'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer<OrganizationSettingsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    'Customize Your Organization',
                    style: AppTextStyles.heading1,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Update your organization\'s branding and settings.',
                    style: AppTextStyles.body.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Logo Section
                  _buildLogoSection(provider),
                  const SizedBox(height: 24),

                  // Organization Name
                  _buildTextField(
                    controller: _organizationNameController,
                    label: 'Organization Name',
                    hint: 'Enter your organization name',
                    icon: Icons.business,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Organization name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Welcome Message
                  _buildTextField(
                    controller: _welcomeMessageController,
                    label: 'Welcome Message',
                    hint: 'Enter welcome message for new users',
                    icon: Icons.message,
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Welcome message is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Color Settings
                  Row(
                    children: [
                      Expanded(
                        child: _buildColorField(
                          controller: _primaryColorController,
                          label: 'Primary Color',
                          hint: '#2196F3',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildColorField(
                          controller: _secondaryColorController,
                          label: 'Secondary Color',
                          hint: '#FF9800',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: QuestButton(
                      text: _isLoading ? 'Saving...' : 'Save Changes',
                      onPressed: _isLoading ? null : _saveSettings,
                      type: QuestButtonType.primary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Reset Button
                  SizedBox(
                    width: double.infinity,
                    child: QuestButton(
                      text: 'Reset to Defaults',
                      onPressed: _resetToDefaults,
                      type: QuestButtonType.outline,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLogoSection(OrganizationSettingsProvider provider) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.image,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Organization Logo',
                  style: AppTextStyles.heading3,
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Current Logo Preview
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: OrganizationLogo(
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Upload Button
            Center(
              child: QuestButton(
                text: _isUploading ? 'Uploading...' : 'Upload New Logo',
                onPressed: _isUploading ? null : _uploadLogo,
                type: QuestButtonType.outline,
                icon: Icons.upload,
              ),
            ),
            const SizedBox(height: 8),
            
            Text(
              'Recommended: PNG or JPG, max 5MB, square aspect ratio',
              style: AppTextStyles.caption.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildColorField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Container(
          margin: const EdgeInsets.all(8),
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: _parseColor(controller.text),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey[300]!),
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Color is required';
        }
        if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value)) {
          return 'Invalid color format (use #RRGGBB)';
        }
        return null;
      },
      onChanged: (value) {
        setState(() {}); // Rebuild to update color preview
      },
    );
  }

  Color _parseColor(String colorString) {
    try {
      if (colorString.startsWith('#') && colorString.length == 7) {
        return Color(int.parse(colorString.substring(1), radix: 16) + 0xFF000000);
      }
    } catch (e) {
      // Ignore parsing errors
    }
    return Colors.grey;
  }

  Future<void> _uploadLogo() async {
    // TODO: Implement image picker functionality
    // For now, show a placeholder message
    _showErrorSnackBar('Logo upload feature will be implemented in the next update.');
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final provider = Provider.of<OrganizationSettingsProvider>(context, listen: false);

      final results = await Future.wait([
        provider.updateOrganizationName(_organizationNameController.text.trim()),
        provider.updateWelcomeMessage(_welcomeMessageController.text.trim()),
        provider.updatePrimaryColor(_primaryColorController.text.trim()),
        provider.updateSecondaryColor(_secondaryColorController.text.trim()),
      ]);

      if (results.every((result) => result)) {
        _showSuccessSnackBar('Settings saved successfully!');
      } else {
        _showErrorSnackBar('Some settings failed to save. Please try again.');
      }
    } catch (e) {
      _showErrorSnackBar('Error saving settings: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Defaults'),
        content: const Text(
          'Are you sure you want to reset all settings to their default values? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _organizationNameController.text = 'My Leadership Quest';
        _welcomeMessageController.text = 'Welcome to your leadership journey!';
        _primaryColorController.text = '#2196F3';
        _secondaryColorController.text = '#FF9800';
      });

      await _saveSettings();
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: AppColors.error,
      ),
    );
  }
}
