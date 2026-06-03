import 'package:flutter/material.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import '../models/game_entry.dart';
import '../services/storage_service.dart';

class AppSelectionScreen extends StatefulWidget {
  const AppSelectionScreen({super.key});

  @override
  State<AppSelectionScreen> createState() => _AppSelectionScreenState();
}

class _AppSelectionScreenState extends State<AppSelectionScreen> {
  List<AppInfo> _installedApps = [];
  List<AppInfo> _filteredApps = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    final apps = await InstalledApps.getInstalledApps(
      excludeSystemApps: true,
      withIcon: true,
    );
    setState(() {
      _installedApps = apps;
      _filteredApps = apps;
      _isLoading = false;
    });
  }

  void _filterApps(String query) {
    setState(() {
      _searchQuery = query;
      _filteredApps = _installedApps
          .where((app) =>
              (app.name?.toLowerCase().contains(query.toLowerCase()) ?? false) ||
              (app.packageName?.toLowerCase().contains(query.toLowerCase()) ?? false))
          .toList();
    });
  }

  Future<void> _addGame(AppInfo app) async {
    final games = await StorageService.getGames();
    if (games.any((g) => g.packageName == app.packageName)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aplikasi sudah ada di daftar')),
        );
      }
      return;
    }

    final newGame = GameEntry(
      name: app.name ?? 'Unknown',
      packageName: app.packageName ?? '',
      iconBytes: app.icon,
    );

    games.add(newGame);
    await StorageService.saveGames(games);
    
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0E17),
        foregroundColor: Colors.white,
        title: const Text('Tambah Aplikasi'),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Cari aplikasi...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF6C63FF)),
                filled: true,
                fillColor: const Color(0xFF1E1E2E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _filterApps,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
                : ListView.builder(
                    itemCount: _filteredApps.length,
                    itemBuilder: (context, index) {
                      final app = _filteredApps[index];
                      return ListTile(
                        leading: app.icon != null
                            ? Image.memory(app.icon!, width: 40, height: 40)
                            : const Icon(Icons.android, color: Colors.green),
                        title: Text(
                          app.name ?? '',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          app.packageName ?? '',
                          style: const TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                        trailing: const Icon(Icons.add_circle_outline, color: Color(0xFF6C63FF)),
                        onTap: () => _addGame(app),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
