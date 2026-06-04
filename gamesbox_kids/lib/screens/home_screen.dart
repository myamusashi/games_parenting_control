import 'package:flutter/material.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:usage_stats/usage_stats.dart';
import 'dart:async';
import 'package:gamesbox_common/gamesbox_common.dart';
import '../widgets/timer_card.dart';
import '../widgets/game_card.dart';
import '../widgets/password_dialog.dart';
import 'game_session_screen.dart';
import 'parent_dashboard.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _dailyLimitMinutes = 60;
  int _totalPlayedSecondsToday = 0;
  bool _isLoading = true;

  List<GameEntry> _games = [];
  Timer? _monitorTimer;
  final bool _isLockingEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startMonitoring();
  }

  @override
  void dispose() {
    _monitorTimer?.cancel();
    super.dispose();
  }

  void _startMonitoring() {
    _monitorTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!_isLockingEnabled) return;

      bool hasPermission = await UsageStats.checkUsagePermission() ?? false;
      if (!hasPermission) return;

      DateTime now = DateTime.now();
      DateTime start = now.subtract(const Duration(seconds: 60));
      List<UsageInfo> stats = await UsageStats.queryUsageStats(start, now);

      UsageInfo? foregroundApp;
      for (var s in stats) {
        if (foregroundApp == null ||
            int.parse(s.lastTimeUsed!) >
                int.parse(foregroundApp.lastTimeUsed!)) {
          foregroundApp = s;
        }
      }

      if (foregroundApp != null &&
          foregroundApp.packageName != 'com.example.games_parenting_control') {
        final pkg = foregroundApp.packageName;
        int index = _games.indexWhere((g) => g.packageName == pkg);

        if (index != -1) {
          // Allowed app is running. Track time (approx 5 seconds since last check)
          if (_remainingSeconds > 0) {
            setState(() {
              _games[index].totalPlayedSecondsToday += 5;
              _totalPlayedSecondsToday += 5;
            });
            // Save periodically
            StorageService.saveTotalPlayed(_totalPlayedSecondsToday);
            StorageService.saveGamePlayed(
              _games[index].name,
              _games[index].totalPlayedSecondsToday,
            );
          } else {
            // Time is up, block it
            _bringToForeground();
          }
        }
      }
    });
  }

  void _bringToForeground() {
    // This is hard to do reliably on Android 10+ without SYSTEM_ALERT_WINDOW
    // But we can show a persistent notification or a lock overlay if we had one.
    // For "simple", we will just show the LockedDialog if the user returns to our app.
    // To actually "lock" it, we'd need more complex setup.
    _showLockedDialog();
  }

  Future<void> _loadData() async {
    final limit = await StorageService.getDailyLimit();
    final playedSeconds = await StorageService.getTotalPlayed();
    final storedGames = await StorageService.getGames();

    final List<GameEntry> updatedGames = [];
    for (var game in storedGames) {
      try {
        final app = await InstalledApps.getAppInfo(game.packageName);
        updatedGames.add(
          GameEntry(
            name: game.name,
            packageName: game.packageName,
            iconBytes: app?.icon,
            isLocked: game.isLocked || (playedSeconds >= limit * 60),
            totalPlayedSecondsToday: await StorageService.getGamePlayed(
              game.name,
            ),
          ),
        );
      } catch (e) {
        // App might have been uninstalled, keep it but without icon or maybe skip
        updatedGames.add(game);
      }
    }

    if (mounted) {
      setState(() {
        _games = updatedGames;
        _dailyLimitMinutes = limit;
        _totalPlayedSecondsToday = playedSeconds;
        _isLoading = false;
      });
    }
  }

  int get _remainingSeconds =>
      (_dailyLimitMinutes * 60 - _totalPlayedSecondsToday).clamp(
        0,
        _dailyLimitMinutes * 60,
      );

  double get _usageRatio => _dailyLimitMinutes == 0
      ? 1.0
      : (_totalPlayedSecondsToday / (_dailyLimitMinutes * 60)).clamp(0.0, 1.0);

  void _launchGame(GameEntry game) async {
    if (game.isLocked || _remainingSeconds == 0) {
      _showLockedDialog();
      return;
    }
    final playedSecondsResult = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            GameSessionScreen(game: game, remainingSeconds: _remainingSeconds),
      ),
    );
    if (playedSecondsResult != null && playedSecondsResult > 0) {
      setState(() {
        game.totalPlayedSecondsToday += playedSecondsResult;
        _totalPlayedSecondsToday += playedSecondsResult;
        if (_totalPlayedSecondsToday >= _dailyLimitMinutes * 60) {
          for (var g in _games) {
            g.isLocked = true;
          }
        }
      });
      // Save to local storage
      await StorageService.saveTotalPlayed(_totalPlayedSecondsToday);
      await StorageService.saveGamePlayed(
        game.name,
        game.totalPlayedSecondsToday,
      );
    }
  }

  void _showLockedDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Waktu Habis!'),
        content: const Text(
          'Kamu sudah mencapai batas waktu hari ini. Istirahat dulu ya!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _openParentDashboard() {
    showDialog(
      context: context,
      builder: (_) => PasswordDialog(
        onSuccess: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ParentDashboard(
                games: _games,
                dailyLimitMinutes: _dailyLimitMinutes,
                totalPlayedToday: _totalPlayedSecondsToday ~/ 60,
                onLimitChanged: (val) async {
                  setState(() => _dailyLimitMinutes = val);
                  await StorageService.saveDailyLimit(val);
                },
                onResetDay: () async {
                  await StorageService.resetDailyData();
                  setState(() {
                    _totalPlayedSecondsToday = 0;
                    for (var g in _games) {
                      g.totalPlayedSecondsToday = 0;
                      g.isLocked = false;
                    }
                  });
                },
                onGameRemoved: (game) async {
                  setState(() => _games.remove(game));
                  await StorageService.saveGames(_games);
                },
                onGameAdded: () => _loadData(),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: Column(
        children: [
          // Header section with gradient
          Container(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF3F4E96), Color(0xFF5E6BC4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Halo, Andi! 👋',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    GestureDetector(
                      onTap: _openParentDashboard,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.face_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                TimerCard(
                  remainingMinutes: _remainingSeconds ~/ 60,
                  dailyLimit: _dailyLimitMinutes,
                  usageRatio: _usageRatio,
                  totalPlayed: _totalPlayedSecondsToday ~/ 60,
                ),
              ],
            ),
          ),

          // Main content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  'Game Tersedia',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3142),
                  ),
                ),
                const SizedBox(height: 20),
                _games.isEmpty
                    ? Center(
                        child: Column(
                          children: [
                            const SizedBox(height: 40),
                            Icon(
                              Icons.sports_esports_outlined,
                              size: 64,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Belum ada game yang diizinkan.\nMinta orang tuamu untuk menambahkan.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              childAspectRatio: 0.85,
                            ),
                        itemCount: _games.length,
                        itemBuilder: (context, index) {
                          return GameCard(
                            game: _games[index],
                            onTap: () => _launchGame(_games[index]),
                            isAllLocked: _remainingSeconds == 0,
                          );
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
