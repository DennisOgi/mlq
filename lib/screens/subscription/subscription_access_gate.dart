import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_constants.dart';
import '../../providers/user_provider.dart';
import '../../utils/entitlements.dart';
import '../../widgets/quest_button.dart';
import 'subscription_management_screen.dart';

/// Blocks AI chat, wallet, and other paid-only routes when the user has
/// no paid plan or school seat. Free-tier Goals / Gratitude stay available.
class SubscriptionAccessGate extends StatefulWidget {
  const SubscriptionAccessGate({super.key, required this.child});

  final Widget child;

  @override
  State<SubscriptionAccessGate> createState() => _SubscriptionAccessGateState();
}

class _SubscriptionAccessGateState extends State<SubscriptionAccessGate>
    with WidgetsBindingObserver {
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _checking = true);
    try {
      await Provider.of<UserProvider>(context, listen: false)
          .refreshEntitlements();
    } catch (_) {}
    if (mounted) setState(() => _checking = false);
  }

  bool _hasAccess(UserProvider up) => Entitlements.hasPaidAccess(up.user);

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, _) {
        if (_checking && userProvider.user != null) {
          // Prefer cached premium so we don't flash lock for paid users
          if (_hasAccess(userProvider)) {
            return widget.child;
          }
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (_hasAccess(userProvider)) {
          return widget.child;
        }

        return const SubscriptionLockScreen();
      },
    );
  }
}

class SubscriptionLockScreen extends StatelessWidget {
  const SubscriptionLockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0820),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () async {
                      await Provider.of<UserProvider>(context, listen: false)
                          .logout();
                    },
                    child: const Text(
                      'Log out',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.lock_clock_rounded,
                  size: 64,
                  color: Color(0xFFFFD700),
                ),
                const SizedBox(height: 20),
                Text(
                  'Subscription required',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.heading2.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your trial or plan has ended. School students already have access — pull to refresh or log out and back in. Everyone else can subscribe to Monthly or Quarterly.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 32),
                QuestButton(
                  text: 'View plans & subscribe',
                  type: QuestButtonType.primary,
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SubscriptionManagementScreen(),
                      ),
                    );
                    if (context.mounted) {
                      await Provider.of<UserProvider>(context, listen: false)
                          .refreshEntitlements();
                    }
                  },
                ),
                const SizedBox(height: 12),
                QuestButton(
                  text: 'Enter school class code',
                  type: QuestButtonType.outline,
                  onPressed: () async {
                    await Navigator.of(context).pushNamed('/class-code');
                    if (context.mounted) {
                      await Provider.of<UserProvider>(context, listen: false)
                          .refreshEntitlements();
                    }
                  },
                ),
                const Spacer(),
                Text(
                  'School seats and active trials still unlock the app automatically.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(color: Colors.white54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
