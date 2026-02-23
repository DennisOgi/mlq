import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';

/// Sponsor Organization Management - For premium challenge sponsors
class SponsorOrganizationScreen extends StatefulWidget {
  const SponsorOrganizationScreen({super.key});

  @override
  State<SponsorOrganizationScreen> createState() => _SponsorOrganizationScreenState();
}

class _SponsorOrganizationScreenState extends State<SponsorOrganizationScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _domainsController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  bool _isCreating = false;
  String? _error;
  String? _organizationId;
  List<Map<String, dynamic>> _organizations = [];

  @override
  void initState() {
    super.initState();
    _loadOrganizations();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _domainsController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadOrganizations() async {
    // TODO: Implement loading existing organizations
    // This would require a new RPC function or direct table query
  }

  Future<void> _createOrganization() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _error = 'Organization name is required');
      return;
    }

    if (_emailController.text.trim().isEmpty) {
      setState(() => _error = 'Contact email is required');
      return;
    }

    setState(() {
      _isCreating = true;
      _error = null;
    });

    try {
      final domains = _domainsController.text.trim().isEmpty
          ? <String>[]
          : _domainsController.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();

      final result = await SupabaseService.instance.adminCreateSchoolOrg(
        name: _nameController.text.trim(),
        contactEmail: _emailController.text.trim(),
        planId: 'sponsor_premium', // Different plan for sponsors
        seatLimit: 0, // Sponsors don't have student seats
        domainAllowlist: domains,
      );

      if (result == null) {
        setState(() => _error = 'Failed to create organization');
        return;
      }

      setState(() {
        _organizationId = result['organization_id'] as String?;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Organization "${_nameController.text}" created successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }

      // Clear form
      _nameController.clear();
      _emailController.clear();
      _domainsController.clear();
      _descriptionController.clear();

      _loadOrganizations();
    } catch (e) {
      setState(() => _error = 'Error: $e');
    } finally {
      setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sponsor Organizations'),
        backgroundColor: Colors.purple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Instructions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.business, color: Colors.purple.shade700),
                      const SizedBox(width: 8),
                      const Text(
                        'About Sponsor Organizations',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Sponsor organizations can:\n'
                    '• Create premium challenges\n'
                    '• Display their logo on challenges\n'
                    '• Offer real-world prizes\n'
                    '• Track participant engagement',
                    style: TextStyle(height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Create Organization Form
            const Text(
              'Create New Sponsor Organization',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 16),

            // Organization Name
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Organization Name *',
                hintText: 'e.g., Acme Corporation',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
              ),
            ),
            const SizedBox(height: 16),

            // Contact Email
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Contact Email *',
                hintText: 'e.g., contact@acme.com',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 16),

            // Domain Allowlist
            TextField(
              controller: _domainsController,
              decoration: const InputDecoration(
                labelText: 'Domain Allowlist (Optional)',
                hintText: 'e.g., acme.com, acme.org',
                helperText: 'Comma-separated list of allowed email domains',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.domain),
              ),
            ),
            const SizedBox(height: 16),

            // Description
            TextField(
              controller: _descriptionController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Brief description of the organization...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),

            // Create Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isCreating ? null : _createOrganization,
                icon: _isCreating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.add_business),
                label: Text(_isCreating ? 'Creating...' : 'Create Organization'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            // Error Display
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.red.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Success Display
            if (_organizationId != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'Organization Created!',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      'Organization ID: $_organizationId',
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Next steps:\n'
                      '1. Upload organization logo in Organization Settings\n'
                      '2. Create premium challenges using this organization',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],

            // Existing Organizations List
            if (_organizations.isNotEmpty) ...[
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'Existing Sponsor Organizations',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 16),
              ..._organizations.map((org) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.purple.shade100,
                    child: Icon(Icons.business, color: Colors.purple.shade700),
                  ),
                  title: Text(org['name'] ?? ''),
                  subtitle: Text(org['contact_email'] ?? ''),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      // TODO: Implement edit functionality
                    },
                  ),
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }
}
