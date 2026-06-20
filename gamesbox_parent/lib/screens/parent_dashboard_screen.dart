import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import 'pairing_setup_screen.dart';
import 'child_management_screen.dart';
import 'package:gamesbox_common/gamesbox_common.dart';

class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  /// Phase 4: initialise FCM + start threshold watchers for all children.
  Future<void> _initNotifications() async {
    try {
      await NotificationService.init();
      final user = FirebaseService.getCurrentUser();
      if (user != null) {
        NotificationService.startWatching(user.uid);
      }
    } catch (_) {
      // Non-critical — app still works without notifications
    }
  }

  void _logout(BuildContext context) async {
    NotificationService.stopWatching();
    await AuthService.signOut();
    if (!context.mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent Dashboard'),
        actions: [
          IconButton(
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PairingSetupScreen()),
              ),
              icon: const Icon(Icons.qr_code),
              label: const Text('Pair Device'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ChildrenManagementScreen(),
                ),
              ),
              icon: const Icon(Icons.people_rounded),
              label: const Text('Kelola Anak'),
            ),
            const SizedBox(height: 16),
            const Expanded(child: Center(child: Text('Welcome, Parent!'))),
          ],
        ),
      ),
    );
  }
}
