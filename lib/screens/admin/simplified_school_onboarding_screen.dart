import 'package:flutter/material.dart';
import 'dart:convert';
import '../../services/supabase_service.dart';

/// Simplified School Onboarding - Upload CSV, provision students, done!
class SimplifiedSchoolOnboardingScreen extends StatefulWidget {
  const SimplifiedSchoolOnboardingScreen({super.key});

  @override
  State<SimplifiedSchoolOnboardingScreen> createState() => _SimplifiedSchoolOnboardingScreenState();
}

class _SimplifiedSchoolOnboardingScreenState extends State<SimplifiedSchoolOnboardingScreen> {
  final _schoolNameController = TextEditingController();
  final _schoolEmailController = TextEditingController();
  final _rosterController = TextEditingController();
  
  bool _isProcessing = false;
  String? _error;
  String? _schoolId;
  String? _schoolName;
  List<Map<String, dynamic>> _results = [];

  @override
  void dispose() {
    _schoolNameController.dispose();
    _schoolEmailController.dispose();
    _rosterController.dispose();
    super.dispose();
  }

  Future<void> _processSchoolRoster() async {
    if (_schoolNameController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter school name');
      return;
    }

    if (_schoolEmailController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter school email');
      return;
    }

    if (_rosterController.text.trim().isEmpty) {
      setState(() => _error = 'Please paste student roster CSV');
      return;
    }

    setState(() {
      _isProcessing = true;
      _error = null;
      _results = [];
    });

    try {
      // Parse CSV to extract students only
      final students = _parseStudentCSV(_rosterController.text);
      
      if (students.isEmpty) {
        setState(() => _error = 'Invalid CSV format or no valid students found.');
        return;
      }

      final schoolName = _schoolNameController.text.trim();
      final schoolEmail = _schoolEmailController.text.trim();

      // Step 1: Create school organization
      final orgResult = await SupabaseService.instance.adminCreateSchoolOrg(
        name: schoolName,
        contactEmail: schoolEmail,
        planId: 'school_pro',
        seatLimit: students.length + 50, // Add buffer
        domainAllowlist: [],
      );

      if (orgResult == null) {
        setState(() => _error = 'Failed to create school organization');
        return;
      }

      final organizationId = orgResult['organization_id'] as String?;
      
      if (organizationId == null) {
        setState(() => _error = 'Organization created but no ID returned');
        return;
      }

      // Step 2: Provision all students
      final results = await SupabaseService.instance.adminBulkProvisionStudents(
        organizationId: organizationId,
        schoolId: organizationId, // Use org ID as school ID
        students: students,
        dryRun: false,
      );

      setState(() {
        _schoolId = organizationId;
        _schoolName = schoolName;
        _results = results;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ School "$schoolName" onboarded with ${results.length} students!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      setState(() => _error = 'Error: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  List<Map<String, dynamic>> _parseStudentCSV(String csvText) {
    try {
      final lines = csvText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      
      if (lines.isEmpty) return [];

      // Check if first line is header
      final firstLine = lines[0].toLowerCase();
      final hasHeader = firstLine.contains('email') || firstLine.contains('name') || firstLine.contains('grade');
      
      final dataLines = hasHeader ? lines.skip(1).toList() : lines;
      
      if (dataLines.isEmpty) return [];

      // Parse all students
      final students = <Map<String, dynamic>>[];
      
      for (final line in dataLines) {
        final cols = line.split(',').map((c) => c.trim()).toList();
        
        if (cols.length >= 2) {
          students.add({
            'email': cols[0],  // student email
            'name': cols[1],   // student name
            'grade': cols.length > 2 ? cols[2] : '',
          });
        }
      }

      return students;
    } catch (e) {
      debugPrint('CSV parse error: $e');
      return [];
    }
  }

  Future<void> _exportPasswordsToCSV() async {
    if (_results.isEmpty) return;

    final withPasswords = _results
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

    final buffer = StringBuffer();
    buffer.writeln('school_name,student_email,student_name,grade,temp_password,status');
    
    for (final r in withPasswords) {
      final email = r['email'] ?? '';
      final name = r['name'] ?? '';
      final grade = r['grade'] ?? '';
      final password = r['temp_password'] ?? '';
      final status = r['status'] ?? '';
      buffer.writeln('$_schoolName,$email,$name,$grade,$password,$status');
    }

    final csvContent = buffer.toString();
    
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$_schoolName - Student Credentials'),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('School Onboarding'),
        backgroundColor: Colors.blue,
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
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      const Text(
                        'How to Onboard a School',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '1. Prepare a CSV with school and student information\n'
                    '2. Paste the CSV below\n'
                    '3. Click "Onboard School"\n'
                    '4. Export student passwords and distribute to school',
                    style: TextStyle(height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // School Info Fields
            const Text(
              'School Information:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _schoolNameController,
              decoration: const InputDecoration(
                labelText: 'School Name *',
                hintText: 'e.g., Lincoln High School',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.school),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _schoolEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'School Contact Email *',
                hintText: 'e.g., admin@lincoln.edu',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 24),

            // CSV Format Example
            const Text(
              'Student Roster CSV Format:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const SelectableText(
                'student_email,student_name,grade\n'
                'alice@lincoln.edu,Alice Johnson,9\n'
                'bob@lincoln.edu,Bob Smith,10\n'
                'charlie@lincoln.edu,Charlie Brown,9',
                style: TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            const SizedBox(height: 24),

            // CSV Input
            const Text(
              'Paste Student Roster CSV:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _rosterController,
              minLines: 10,
              maxLines: 20,
              decoration: const InputDecoration(
                hintText: 'Paste your CSV here...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),

            // Process Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _processSchoolRoster,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.school),
                label: Text(_isProcessing ? 'Processing...' : 'Onboard School'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
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

            // Results Display
            if (_results.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Onboarding Complete!',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'School: $_schoolName',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      Text(
                        'Students: ${_results.length}',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _exportPasswordsToCSV,
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Export Passwords'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '⚠️ IMPORTANT: Export passwords NOW! They cannot be recovered later.',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ..._results.map((r) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r['name'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            r['email'] ?? '',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(r['status']),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        r['status'] ?? '',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    if ((r['temp_password'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(width: 8),
                      SelectableText(
                        'PW: ${r['temp_password']}',
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                      ),
                    ],
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'created':
        return Colors.green;
      case 'exists_attached':
        return Colors.blue;
      case 'skipped':
        return Colors.orange;
      case 'error':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
