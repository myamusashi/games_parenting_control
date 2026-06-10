import 'package:flutter/material.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:usage_stats/usage_stats.dart';
import 'package:gamesbox_common/gamesbox_common.dart';
import 'app_selection_screen.dart';

class ParentDashboard extends StatefulWidget {
  final List<GameEntry> games;
  final int dailyLimitMinutes;
  final int totalPlayedToday; // minutes
  final ValueChanged<int> onLimitChanged;
  final VoidCallback onResetDay;
  final ValueChanged<GameEntry> onGameRemoved;
  final VoidCallback onGameAdded;

  const ParentDashboard({
    super.key,
    required this.games,
    required this.dailyLimitMinutes,
    required this.totalPlayedToday,
    required this.onLimitChanged,
    required this.onResetDay,
    required this.onGameRemoved,
    required this.onGameAdded,
  });

  @override
  State<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> {
  late int _tempLimit;
  List<GameEntry> _currentGames = [];

  @override
  void initState() {
    super.initState();
    _tempLimit = widget.dailyLimitMinutes;
    _currentGames = List.from(widget.games);
  }

  Future<void> _reloadGames() async {
    final games = await StorageService.getGames();
    final List<GameEntry> updatedGames = [];
    
    for (var game in games) {
      try {
        final app = await InstalledApps.getAppInfo(game.packageName);
        updatedGames.add(GameEntry(
          name: game.name,
          packageName: game.packageName,
          iconBytes: app?.icon,
          isLocked: game.isLocked,
          totalPlayedSecondsToday: await StorageService.getGamePlayed(game.name),
        ));
      } catch (e) {
        updatedGames.add(game);
      }
    }
    
    if (mounted) {
      setState(() {
        _currentGames = updatedGames;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0E17),
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.shield_rounded, color: Color(0xFF6C63FF), size: 20),
            SizedBox(width: 8),
            Text(
              'Parent Dashboard',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Summary Card ──
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF9C89FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Laporan Hari Ini',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.totalPlayedToday} / ${widget.dailyLimitMinutes} menit',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: _currentGames
                      .map(
                        (g) => Expanded(
                          child: Column(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: g.iconBytes != null
                                    ? Image.memory(g.iconBytes!)
                                    : const Icon(Icons.gamepad, color: Colors.white70, size: 18),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                g.totalPlayedSecondsToday < 60
                                    ? '${g.totalPlayedSecondsToday}s'
                                    : '${g.totalPlayedSecondsToday ~/ 60}m',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                g.name.length > 8 ? '${g.name.substring(0, 7)}...' : g.name,
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Daily Limit Setting ──
          SectionCard(
            title: 'Batas Waktu Harian',
            icon: Icons.timer_rounded,
            child: Column(
              children: [
                Text(
                  '$_tempLimit menit',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF6C63FF),
                  ),
                ),
                Slider(
                  value: _tempLimit.toDouble(),
                  min: 15,
                  max: 180,
                  divisions: 11,
                  activeColor: const Color(0xFF6C63FF),
                  inactiveColor: const Color(0xFF2A2A3E),
                  label: '$_tempLimit menit',
                  onChanged: (v) => setState(() => _tempLimit = v.round()),
                  onChangeEnd: (v) => widget.onLimitChanged(v.round()),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      '15m',
                      style: TextStyle(color: Color(0xFF666666), fontSize: 11),
                    ),
                    Text(
                      '3 jam',
                      style: TextStyle(color: Color(0xFF666666), fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Game List ──
          SectionCard(
            title: 'Daftar Game Diizinkan',
            icon: Icons.sports_esports_rounded,
            child: Column(
              children: _currentGames
                  .map(
                    (g) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: g.iconBytes != null
                            ? Image.memory(g.iconBytes!, width: 32, height: 32)
                            : const Icon(Icons.gamepad, color: Colors.white70, size: 20),
                      ),
                      title: Text(
                        g.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        g.totalPlayedSecondsToday < 60
                            ? '${g.totalPlayedSecondsToday} detik hari ini'
                            : '${g.totalPlayedSecondsToday ~/ 60} menit hari ini',
                        style: const TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 12,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.remove_circle_outline_rounded,
                          color: Color(0xFFFF5252),
                        ),
                        onPressed: () {
                          setState(() {
                            _currentGames.remove(g);
                          });
                          widget.onGameRemoved(g);
                        },
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),

          // ── App Lock Permission ──
          SectionCard(
            title: 'Izin Proteksi Keamanan',
            icon: Icons.security_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Izin ini diperlukan agar aplikasi bisa mendeteksi game yang dibuka di luar aplikasi dan menguncinya otomatis.',
                  style: TextStyle(color: Color(0xFF666666), fontSize: 12),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      bool hasPermission = await UsageStats.checkUsagePermission() ?? false;
                      if (!hasPermission) {
                        UsageStats.grantUsagePermission();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Izin sudah diberikan ✓')),
                        );
                      }
                    },
                    icon: const Icon(Icons.vpn_key_rounded),
                    label: const Text('Berikan Izin Akses Penggunaan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E1E2E),
                      foregroundColor: const Color(0xFF6C63FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Add Game Button ──
          FilledButton.icon(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AppSelectionScreen()),
              );
              if (result == true) {
                await _reloadGames();
                widget.onGameAdded();
              }
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Tambah Game Diizinkan'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Reset ──
          OutlinedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: const Color(0xFF1E1E2E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: const Text(
                    'Reset Data Hari Ini?',
                    style: TextStyle(color: Colors.white),
                  ),
                  content: const Text(
                    'Semua waktu bermain hari ini akan direset dan game yang terkunci akan dibuka kembali.',
                    style: TextStyle(color: Color(0xFFAAAAAA)),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onResetDay();
                        setState(() {
                          for (var g in _currentGames) {
                            g.totalPlayedSecondsToday = 0;
                            g.isLocked = false;
                          }
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Data hari ini telah direset ✓',
                            ),
                            backgroundColor: const Color(0xFF4CAF50),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5252),
                      ),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reset Data Hari Ini'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFFF5252),
              side: const BorderSide(color: Color(0xFFFF5252)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
