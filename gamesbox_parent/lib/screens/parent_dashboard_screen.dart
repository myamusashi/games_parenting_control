import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'games_list_screen.dart';
import 'pairing_setup_screen.dart';
import 'time_limit_screen.dart';
import 'store_share_handler.dart';

class ParentDashboardScreen extends StatelessWidget {
  const ParentDashboardScreen({super.key});

  void _logout(BuildContext context) async {
    await AuthService.signOut();
    if (Navigator.canPop(context)) Navigator.popUntil(context, (route) => route.isFirst);
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent Dashboard'),
        actions: [
          IconButton(onPressed: () => _logout(context), icon: const Icon(Icons.logout)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PairingSetupScreen())), icon: const Icon(Icons.qr_code), label: const Text('Pair Device')),
            const SizedBox(height: 8),
            ElevatedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GamesListScreen())), icon: const Icon(Icons.videogame_asset), label: const Text('Manage Games')),
            const SizedBox(height: 8),
            ElevatedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StoreShareHandler())), icon: const Icon(Icons.share), label: const Text('Add Game from Store')),
            const SizedBox(height: 8),
            ElevatedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TimeLimitScreen())), icon: const Icon(Icons.timer), label: const Text('Daily Time Limits')),
            const SizedBox(height: 16),
            const Text('Quick Actions', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(child: Center(child: Text('Welcome, Parent!'))),
          ],
        ),
      ),
    );
  }
}
