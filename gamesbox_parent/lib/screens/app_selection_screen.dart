import 'package:flutter/material.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'package:gamesbox_common/gamesbox_common.dart';
import 'package:gamesbox_common/services/game_sync_service.dart';

/// App-selection screen in the parent app.
///
/// Key change:
///   OLD → StorageService.saveGames()  (local SharedPreferences only)
///   NEW → GameSyncService.addGame()   (local + Firebase /allowed_games)
///
/// After saving, the game is immediately visible in the kids HomeScreen via
/// the Firebase real-time stream — no manual refresh required on the kids
/// device.
class AppSelectionScreen extends StatefulWidget {
  const AppSelectionScreen({super.key});

  @override
  State<AppSelectionScreen> createState() => _AppSelectionScreenState();
}

class _AppSelectionScreenState extends State<AppSelectionScreen> {
  List<AppInfo> _installedApps = [];
  List<AppInfo> _filteredApps = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    final apps = await InstalledApps.getInstalledApps();
    if (mounted) {
      setState(() {
        _installedApps = apps;
        _filteredApps = apps;
        _isLoading = false;
      });
    }
  }

  void _filterApps(String query) {
    setState(() {
      _filteredApps = _installedApps
          .where(
            (app) =>
                (app.name?.toLowerCase().contains(query.toLowerCase()) ??
                    false) ||
                (app.packageName?.toLowerCase().contains(query.toLowerCase()) ??
                    false),
          )
          .toList();
    });
  }

  Future<void> _addGame(AppInfo app) async {
    if (_isSaving) return;
    final packageName = app.packageName ?? '';
    final name = app.name ?? 'Unknown';
    if (packageName.isEmpty) return;

    // Check duplicate against local cache
    final existing = await StorageService.getGames();
    if (existing.any((g) => g.packageName == packageName)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aplikasi sudah ada di daftar')),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Resolve parentUid for audit trail
      final parentUid =
          FirebaseService.getCurrentUser()?.uid ?? 'parent_unknown';

      await GameSyncService.addGame(
        name: name,
        packageName: packageName,
        iconBytes: app.icon,
        addedBy: parentUid,
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menambahkan: $e'),
            backgroundColor: const Color(0xFFFF5252),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
            padding: const EdgeInsets.all(16),
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

          // Sync indicator
          if (_isSaving)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF6C63FF),
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Menyimpan ke semua perangkat...',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),

          // Sync notice banner
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.sync_rounded, color: Colors.green, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Game yang ditambahkan langsung tersinkron ke perangkat anak',
                    style: TextStyle(
                      color: Colors.green.withValues(alpha: 0.85),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
                  )
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          app.packageName ?? '',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.add_circle_outline,
                          color: Color(0xFF6C63FF),
                        ),
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
