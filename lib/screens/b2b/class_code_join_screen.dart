import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';

class ClassCodeJoinScreen extends StatefulWidget {
  const ClassCodeJoinScreen({super.key});

  @override
  State<ClassCodeJoinScreen> createState() => _ClassCodeJoinScreenState();
}

class _ClassCodeJoinScreenState extends State<ClassCodeJoinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final ok = await Provider.of<UserProvider>(context, listen: false)
          .joinWithClassCode(_codeController.text.trim());
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Joined school successfully. Premium enabled.'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      } else {
        setState(() => _error = 'Invalid or expired class code.');
      }
    } catch (e) {
      setState(() => _error = 'Failed to join: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enter Class Code')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Enter the class code you received to join your school.'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'Class Code',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.done,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter your class code';
                  if (v.trim().length < 6) return 'Code looks too short';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.school_rounded),
                label: const Text('Join School'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
