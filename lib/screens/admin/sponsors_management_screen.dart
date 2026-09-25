import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../constants/app_constants.dart';
import '../../models/sponsor_model.dart';
import '../../services/sponsor_service.dart';
import '../../services/supabase_service.dart';

class SponsorsManagementScreen extends StatefulWidget {
  const SponsorsManagementScreen({super.key});

  @override
  State<SponsorsManagementScreen> createState() => _SponsorsManagementScreenState();
}

class _SponsorsManagementScreenState extends State<SponsorsManagementScreen> {
  final SponsorService _sponsorService = SponsorService();
  final _supabaseService = SupabaseService.instance;
  List<SponsorModel> _sponsors = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSponsors();
  }

  Future<void> _loadSponsors() async {
    setState(() => _isLoading = true);
    try {
      _sponsors = await _sponsorService.getAllSponsors();
    } catch (e) {
      debugPrint('Error loading sponsors: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading sponsors: $e')),
        );
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sponsors Management'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showSponsorForm(null),
            tooltip: 'Add Sponsor',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sponsors.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.business, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'No sponsors yet',
                        style: AppTextStyles.heading2.copyWith(color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add your first sponsor to get started',
                        style: AppTextStyles.body.copyWith(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => _showSponsorForm(null),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Sponsor'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadSponsors,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _sponsors.length,
                    itemBuilder: (context, index) {
                      final sponsor = _sponsors[index];
                      return _buildSponsorCard(sponsor, index);
                    },
                  ),
                ),
    );
  }

  Widget _buildSponsorCard(SponsorModel sponsor, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _showSponsorForm(sponsor),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Logo
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: sponsor.logoUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          sponsor.logoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.business, size: 30),
                        ),
                      )
                    : const Icon(Icons.business, size: 30, color: Colors.grey),
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sponsor.name,
                      style: AppTextStyles.bodyBold.copyWith(fontSize: 16),
                    ),
                    if (sponsor.contactEmail != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.email, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              sponsor.contactEmail!,
                              style: AppTextStyles.caption.copyWith(color: Colors.grey.shade600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (sponsor.website != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.language, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              sponsor.website!,
                              style: AppTextStyles.caption.copyWith(color: Colors.grey.shade600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.person_add_alt_1, color: Colors.teal),
                    onPressed: () => _showAssignSponsorUserDialog(sponsor),
                    tooltip: 'Onboard Sponsor User',
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: AppColors.primary),
                    onPressed: () => _showSponsorForm(sponsor),
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteSponsor(sponsor),
                    tooltip: 'Delete',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms, delay: (index * 50).ms);
  }

  void _showAssignSponsorUserDialog(SponsorModel sponsor) {
    final emailController = TextEditingController();
    String role = 'manager';
    bool loading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Onboard Sponsor User • ${sponsor.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'User email',
                  hintText: 'someone@example.com',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'owner', child: Text('Owner')),
                  DropdownMenuItem(value: 'manager', child: Text('Manager')),
                ],
                onChanged: (v) => setState(() => role = v ?? 'manager'),
              ),
              const SizedBox(height: 8),
              Text(
                'The user must already have an account in MLQ.',
                style: AppTextStyles.caption.copyWith(color: Colors.grey.shade700),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
                      final email = emailController.text.trim();
                      if (email.isEmpty) return;
                      setState(() => loading = true);
                      try {
                        final res = await _supabaseService.adminAssignSponsorUser(
                          sponsorId: sponsor.id,
                          email: email,
                          role: role,
                        );
                        if (!mounted) return;
                        final ok = res['ok'] == true;
                        if (ok) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Sponsor user onboarded'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          final err = (res['error'] ?? 'unknown_error').toString();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed: $err'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      } finally {
                        if (mounted) setState(() => loading = false);
                      }
                    },
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Onboard'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSponsorForm(SponsorModel? sponsor) {
    final nameController = TextEditingController(text: sponsor?.name);
    final logoUrlController = TextEditingController(text: sponsor?.logoUrl);
    final bannerUrlController = TextEditingController(text: sponsor?.bannerUrl);
    final themePrimaryController =
        TextEditingController(text: sponsor?.themePrimaryColor);
    final themeSecondaryController =
        TextEditingController(text: sponsor?.themeSecondaryColor);
    final emailController = TextEditingController(text: sponsor?.contactEmail);
    final phoneController = TextEditingController(text: sponsor?.contactPhone);
    final websiteController = TextEditingController(text: sponsor?.website);
    final descriptionController = TextEditingController(text: sponsor?.description);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(sponsor == null ? 'Add Sponsor' : 'Edit Sponsor'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Sponsor Name *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.business),
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Name is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: logoUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Logo URL',
                    hintText: 'https://... or upload via Sponsor Dashboard',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.image),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: bannerUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Banner URL',
                    hintText: 'Storefront header image',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.panorama),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: themePrimaryController,
                  decoration: const InputDecoration(
                    labelText: 'Theme primary color',
                    hintText: '#6B21A8',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.palette),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: themeSecondaryController,
                  decoration: const InputDecoration(
                    labelText: 'Theme secondary color',
                    hintText: '#9333EA',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.palette_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Contact Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Contact Phone',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: websiteController,
                  decoration: const InputDecoration(
                    labelText: 'Website',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.language),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                await _saveSponsor(
                  sponsor,
                  nameController.text,
                  logoUrlController.text.isEmpty ? null : logoUrlController.text,
                  bannerUrlController.text.isEmpty ? null : bannerUrlController.text,
                  themePrimaryController.text.isEmpty ? null : themePrimaryController.text,
                  themeSecondaryController.text.isEmpty ? null : themeSecondaryController.text,
                  emailController.text.isEmpty ? null : emailController.text,
                  phoneController.text.isEmpty ? null : phoneController.text,
                  websiteController.text.isEmpty ? null : websiteController.text,
                  descriptionController.text.isEmpty ? null : descriptionController.text,
                );
              }
            },
            child: Text(sponsor == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSponsor(
    SponsorModel? existingSponsor,
    String name,
    String? logoUrl,
    String? bannerUrl,
    String? themePrimaryColor,
    String? themeSecondaryColor,
    String? email,
    String? phone,
    String? website,
    String? description,
  ) async {
    try {
      if (existingSponsor == null) {
        // Create new sponsor
        final newSponsor = SponsorModel(
          id: '', // Will be generated by database
          name: name,
          logoUrl: logoUrl,
          bannerUrl: bannerUrl,
          themePrimaryColor: themePrimaryColor,
          themeSecondaryColor: themeSecondaryColor,
          contactEmail: email,
          contactPhone: phone,
          website: website,
          description: description,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _sponsorService.createSponsor(newSponsor);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sponsor created successfully')),
          );
        }
      } else {
        // Update existing sponsor
        final updatedSponsor = existingSponsor.copyWith(
          name: name,
          logoUrl: logoUrl,
          bannerUrl: bannerUrl,
          themePrimaryColor: themePrimaryColor,
          themeSecondaryColor: themeSecondaryColor,
          contactEmail: email,
          contactPhone: phone,
          website: website,
          description: description,
          updatedAt: DateTime.now(),
        );
        await _sponsorService.updateSponsor(existingSponsor.id, updatedSponsor);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sponsor updated successfully')),
          );
        }
      }
      _loadSponsors();
    } catch (e) {
      debugPrint('Error saving sponsor: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _deleteSponsor(SponsorModel sponsor) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Sponsor?'),
        content: Text(
          'Are you sure you want to delete "${sponsor.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _sponsorService.deleteSponsor(sponsor.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sponsor deleted successfully')),
          );
        }
        _loadSponsors();
      } catch (e) {
        debugPrint('Error deleting sponsor: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }
}
