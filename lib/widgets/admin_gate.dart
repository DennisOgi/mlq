import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/admin_service.dart';

/// Wraps admin-only screens; redirects non-admins with an access denied message.
class AdminGate extends StatefulWidget {
  final Widget child;

  const AdminGate({super.key, required this.child});

  @override
  State<AdminGate> createState() => _AdminGateState();
}

class _AdminGateState extends State<AdminGate> {
  bool _isChecking = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final allowed = await AdminService.instance.isAdmin(userProvider: userProvider);
    if (!mounted) return;
    setState(() {
      _isAdmin = allowed;
      _isChecking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Access denied')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'Admin access required',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'You do not have permission to view this page.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Go back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}
