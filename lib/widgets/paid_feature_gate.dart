import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../providers/user_provider.dart';
import '../utils/entitlements.dart';
import 'feature_lock_card.dart';

/// Shows [child] when [isAllowed] (default: paid/school/admin); otherwise a lock card.
class PaidFeatureGate extends StatelessWidget {
  final Widget child;
  final String title;
  final String description;
  final IconData icon;
  final bool compact;
  final bool Function(UserModel?)? isAllowed;

  const PaidFeatureGate({
    super.key,
    required this.child,
    required this.title,
    required this.description,
    this.icon = Icons.lock_rounded,
    this.compact = false,
    this.isAllowed,
  });

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    final allowed = (isAllowed ?? Entitlements.hasPaidAccess)(user);
    if (allowed) return child;

    return FeatureLockCard(
      title: title,
      description: description,
      icon: icon,
      compact: compact,
    );
  }
}

/// Blocks a tap and routes to plans when the user is not entitled.
bool guardPaidAction(
  BuildContext context, {
  String message = 'Subscribe to unlock this feature',
}) {
  final user = context.read<UserProvider>().user;
  if (Entitlements.hasPaidAccess(user)) return true;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
  Navigator.pushNamed(context, '/subscription-management');
  return false;
}
