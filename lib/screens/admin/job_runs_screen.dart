import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

class JobRunsScreen extends StatefulWidget {
  const JobRunsScreen({super.key});

  @override
  State<JobRunsScreen> createState() => _JobRunsScreenState();
}

class _JobRunsScreenState extends State<JobRunsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final rows = await Supabase.instance.client
          .from('job_run_logs')
          .select('*')
          .order('run_at', ascending: false)
          .limit(200);
      setState(() {
        _logs = List<Map<String, dynamic>>.from(rows as List);
      });
    } catch (e) {
      setState(() { _error = 'Failed to load logs: $e'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Runs (Admin)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    final jobName = (log['job_name'] ?? '') as String;
                    final runAt = (log['run_at'] ?? '') as String;
                    final enqueued = (log['enqueued_count'] ?? 0) as int;
                    final details = log['details'];
                    return ListTile(
                      leading: const Icon(Icons.event_note),
                      title: Text(jobName),
                      subtitle: Text(runAt),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('Enqueued: $enqueued'),
                      ),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: Text(jobName),
                            content: SingleChildScrollView(
                              child: Text(JsonEncoder.withIndent('  ').convert(details)),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close'),
                              )
                            ],
                          ),
                        );
                      },
                    );
                  },
                  separatorBuilder: (_, __) => const Divider(),
                  itemCount: _logs.length,
                ),
    );
  }
}
