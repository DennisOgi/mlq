import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../services/supabase_service.dart';

class SchoolOnboardingScreen extends StatefulWidget {
  const SchoolOnboardingScreen({super.key});

  @override
  State<SchoolOnboardingScreen> createState() => _SchoolOnboardingScreenState();
}

class _SchoolOnboardingScreenState extends State<SchoolOnboardingScreen> {
  final _orgName = TextEditingController();
  final _contactEmail = TextEditingController();
  final _planId = TextEditingController(text: 'school_pro');
  final _seatLimit = TextEditingController(text: '100');
  final _domains = TextEditingController();
  final _emails = TextEditingController();
  final _provisionRoster = TextEditingController();
  final _schoolId = TextEditingController();

  bool _creating = false;
  bool _provisioning = false;
  String? _organizationId;
  String? _subscriptionId;
  String? _error;
  List<Map<String, dynamic>> _invites = [];
  List<Map<String, dynamic>> _provisionResults = [];

  @override
  void dispose() {
    _orgName.dispose();
    _contactEmail.dispose();
    _planId.dispose();
    _seatLimit.dispose();
    _domains.dispose();
    _emails.dispose();
    _provisionRoster.dispose();
    _schoolId.dispose();
    super.dispose();
  }

  Future<void> _dryRunProvision() async {
    setState(() { _provisioning = true; _error = null; _provisionResults = []; });
    try {
      final svc = SupabaseService.instance;
      final results = await svc.adminBulkProvisionStudents(
        organizationId: _organizationId,
        schoolId: _schoolId.text.trim().isEmpty ? null : _schoolId.text.trim(),
        rosterText: _provisionRoster.text,
        dryRun: true,
      );
      setState(() { _provisionResults = results; });
    } catch (e) {
      setState(() { _error = 'Dry run failed: $e'; });
    } finally {
      setState(() { _provisioning = false; });
    }
  }

  Future<void> _provision() async {
    setState(() { _provisioning = true; _error = null; _provisionResults = []; });
    try {
      final svc = SupabaseService.instance;
      final results = await svc.adminBulkProvisionStudents(
        organizationId: _organizationId,
        schoolId: _schoolId.text.trim().isEmpty ? null : _schoolId.text.trim(),
        rosterText: _provisionRoster.text,
        dryRun: false,
      );
      setState(() { _provisionResults = results; });
    } catch (e) {
      setState(() { _error = 'Provisioning failed: $e'; });
    } finally {
      setState(() { _provisioning = false; });
    }
  }

  Future<void> _exportPasswordsToCSV() async {
    if (_provisionResults.isEmpty) return;

    // Filter results that have temp passwords
    final withPasswords = _provisionResults
        .where((r) => (r['temp_password'] ?? '').toString().isNotEmpty)
        .toList();

    if (withPasswords.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No temporary passwords to export.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Create CSV content
    final buffer = StringBuffer();
    buffer.writeln('email,name,grade,temp_password,status');
    
    for (final r in withPasswords) {
      final email = r['email'] ?? '';
      final name = r['name'] ?? '';
      final grade = r['grade'] ?? '';
      final password = r['temp_password'] ?? '';
      final status = r['status'] ?? '';
      buffer.writeln('$email,$name,$grade,$password,$status');
    }

    final csvContent = buffer.toString();
    
    // For now, just copy to clipboard and show message
    // In a full implementation, you'd use a file picker package
    try {
      // Show dialog with CSV content for manual copy
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Student Passwords CSV'),
          content: SingleChildScrollView(
            child: SelectableText(
              csvContent,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _createOrg() async {
    setState(() { _creating = true; _error = null; });
    try {
      final svc = SupabaseService.instance;
      final domains = _domains.text.trim().isEmpty
          ? <String>[]
          : _domains.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      final res = await svc.adminCreateSchoolOrg(
        name: _orgName.text.trim(),
        contactEmail: _contactEmail.text.trim(),
        planId: _planId.text.trim(),
        seatLimit: int.tryParse(_seatLimit.text.trim()) ?? 0,
        domainAllowlist: domains,
      );
      if (res == null) {
        setState(() => _error = 'Failed to create organization. Are you an admin?');
      } else {
        setState(() {
          _organizationId = res['organization_id'] as String?;
          _subscriptionId = res['subscription_id'] as String?;
        });
      }
    } catch (e) {
      setState(() => _error = 'Create org failed: $e');
    } finally {
      setState(() { _creating = false; });
    }
  }

  Future<void> _invite() async {
    if (_organizationId == null) {
      setState(() => _error = 'Create the organization first.');
      return;
    }
    setState(() { _creating = true; _error = null; _invites = []; });
    try {
      final svc = SupabaseService.instance;
      // Extract emails from free text or CSV using a robust regex
      final text = _emails.text;
      final regex = RegExp(r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}', caseSensitive: false);
      final matches = regex.allMatches(text);
      final set = <String>{};
      for (final m in matches) {
        final email = m.group(0)!.trim().toLowerCase();
        if (email.isNotEmpty) set.add(email);
      }
      final emails = set.toList();
      final res = await svc.adminBulkInvite(
        organizationId: _organizationId!,
        emails: emails,
      );
      setState(() => _invites = res);
    } catch (e) {
      setState(() => _error = 'Invites failed: $e');
    } finally {
      setState(() { _creating = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('School Onboarding (Admin)')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Step 1: Create School Organization', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(controller: _orgName, decoration: const InputDecoration(labelText: 'School Name', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: _contactEmail, decoration: const InputDecoration(labelText: 'Billing/Contact Email', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: _planId, decoration: const InputDecoration(labelText: 'Plan ID', border: OutlineInputBorder()))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _seatLimit, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Seat Limit', border: OutlineInputBorder()))),
            ]),
            const SizedBox(height: 8),
            TextField(controller: _domains, decoration: const InputDecoration(labelText: 'Domain Allowlist (comma separated, optional)', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _creating ? null : _createOrg,
              icon: _creating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.apartment_rounded),
              label: const Text('Create Organization'),
            ),
            const Divider(height: 32),
            const Text('Step 2: Register Students', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _schoolId,
              decoration: const InputDecoration(
                labelText: 'Optional School ID (UUID) to attach students',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _provisionRoster,
              minLines: 6,
              maxLines: 14,
              decoration: const InputDecoration(
                labelText: 'Roster (CSV or list)\nAccepted headers: email,name,grade,username\nExamples:\nemail,name,grade\nstudent1@school.edu,Alex,8\nstudent2@school.edu,Sam,7',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _provisioning ? null : _dryRunProvision,
                  icon: _provisioning
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.playlist_add_check_rounded),
                  label: const Text('Dry Run (Validate Only)'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _provisioning ? null : _provision,
                  icon: _provisioning
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Provision Accounts'),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            if (_provisionResults.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Results:', style: TextStyle(fontWeight: FontWeight.bold)),
                  if (_provisionResults.any((r) => (r['temp_password'] ?? '').toString().isNotEmpty))
                    ElevatedButton.icon(
                      onPressed: _exportPasswordsToCSV,
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Export Passwords CSV'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '⚠️ Important: Copy or export passwords immediately! They cannot be recovered later.',
                        style: TextStyle(color: Colors.blue.shade900, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ..._provisionResults.map((r) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(color: Color(0x22000000), blurRadius: 4, offset: Offset(0,2))
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(child: Text('${r['email'] ?? ''}  •  ${r['name'] ?? ''}  •  ${r['grade'] ?? ''}')),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('${r['status'] ?? ''}')
                    ),
                    if ((r['temp_password'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(width: 8),
                      SelectableText('Temp: ${r['temp_password']}'),
                    ]
                  ],
                ),
              )),
            ],
            const Divider(),
            const Text('Step 3: Leaderboard Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _creating ? null : () async {
                setState(() { _creating = true; _error = null; });
                try {
                  final res = await SupabaseService.instance.adminRunLeaderboardNotifications();
                  final enq = (res?['enqueued'] as List?)?.length ?? 0;
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Leaderboard notifications enqueued for top users: $enq')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to run job: $e')),
                  );
                } finally {
                  if (mounted) setState(() { _creating = false; });
                }
              },
              icon: _creating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.leaderboard),
              label: const Text('Run Leaderboard Notifications Now'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            if (_organizationId != null) ...[
              const SizedBox(height: 12),
              Text('Organization ID: $_organizationId'),
              if (_subscriptionId != null) Text('Subscription ID: $_subscriptionId'),
            ],
            if (_invites.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Generated Invites (Codes):', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ..._invites.map((i) => SelectableText('Code: ${i['code'] ?? ''}')).toList(),
            ]
          ],
        ),
      ),
    );
  }
}
