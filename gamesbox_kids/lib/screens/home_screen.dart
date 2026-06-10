import 'dart:async';
import 'package:flutter/material.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:usage_stats/usage_stats.dart';
import 'package:gamesbox_common/gamesbox_common.dart';
import '../widgets/game_card.dart';
import 'game_session_screen.dart';
import 'parent_dashboard.dart';
import 'locked_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _dailyLimitMinutes = 60;
  int _totalPlayedSecondsToday = 0;
  bool _isLoading = true;
  String _kidName = 'Anak'; // UX-K-02

  List<GameEntry> _games = [];
  Timer? _monitorTimer;
  Timer? _refreshTimer; // UX-K-06: refresh remaining time every minute
  final bool _isLockingEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startMonitoring();
    _startLiveTimer(); // UX-K-06
  }

  @override
  void dispose() {
    _monitorTimer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  // ─── UX-K-06: live countdown ─────────────────────────────────────────────

  void _startLiveTimer() {
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      if (!mounted) return;
      final played = await StorageService.getTotalPlayed();
      if (mounted) setState(() => _totalPlayedSecondsToday = played);
    });
  }

  // ─── App monitoring (detect foreground game) ─────────────────────────────

  void _startMonitoring() {
    _monitorTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!_isLockingEnabled) return;

      final hasPermission =
          await UsageStats.checkUsagePermission() ?? false;
      if (!hasPermission) return;

      final now = DateTime.now();
      final stats = await UsageStats.queryUsageStats(
          now.subtract(const Duration(seconds: 60)), now);

      UsageInfo? foreground;
      for (final s in stats) {
        if (foreground == null ||
            int.parse(s.lastTimeUsed!) >
                int.parse(foreground.lastTimeUsed!)) {
          foreground = s;
        }
      }

      if (foreground == null) return;
      if (foreground.packageName ==
          'com.example.games_parenting_control') return;

      final idx = _games.indexWhere(
          (g) => g.packageName == foreground!.packageName);
      if (idx == -1) return;

      if (_remainingSeconds > 0) {
        setState(() {
          _games[idx].totalPlayedSecondsToday += 5;
          _totalPlayedSecondsToday += 5;
        });
        await StorageService.saveTotalPlayed(_totalPlayedSecondsToday);
        await StorageService.saveGamePlayed(
            _games[idx].name, _games[idx].totalPlayedSecondsToday);
      } else {
        _navigateToLockedScreen();
      }
    });
  }

  // ─── Data loading ─────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    final limit = await StorageService.getDailyLimit();
    final playedSeconds = await StorageService.getTotalPlayed();
    final storedGames = await StorageService.getGames();
    final name = await StorageService.getKidName(); // UX-K-02

    final List<GameEntry> updatedGames = [];
    for (final game in storedGames) {
      try {
        final app = await InstalledApps.getAppInfo(game.packageName);
        updatedGames.add(
          GameEntry(
            name: game.name,
            packageName: game.packageName,
            iconBytes: app?.icon,
            isLocked: game.isLocked || (playedSeconds >= limit * 60),
            totalPlayedSecondsToday:
                await StorageService.getGamePlayed(game.name),
          ),
        );
      } catch (_) {
        updatedGames.add(game);
      }
    }

    if (mounted) {
      setState(() {
        _games = updatedGames;
        _dailyLimitMinutes = limit;
        _totalPlayedSecondsToday = playedSeconds;
        _kidName = name; // UX-K-02
        _isLoading = false;
      });
    }
  }

  // ─── Computed props ───────────────────────────────────────────────────────

  int get _remainingSeconds =>
      (_dailyLimitMinutes * 60 - _totalPlayedSecondsToday)
          .clamp(0, _dailyLimitMinutes * 60);

  double get _usageRatio => _dailyLimitMinutes == 0
      ? 1.0
      : (_totalPlayedSecondsToday / (_dailyLimitMinutes * 60))
          .clamp(0.0, 1.0);

  // ─── Navigation ───────────────────────────────────────────────────────────

  void _launchGame(GameEntry game) async {
    if (game.isLocked || _remainingSeconds == 0) {
      _navigateToLockedScreen();
      return;
    }
    final playedSecondsResult = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => GameSessionScreen(
            game: game, remainingSeconds: _remainingSeconds),
      ),
    );
    if (playedSecondsResult != null && playedSecondsResult > 0) {
      setState(() {
        game.totalPlayedSecondsToday += playedSecondsResult;
        _totalPlayedSecondsToday += playedSecondsResult;
        if (_totalPlayedSecondsToday >= _dailyLimitMinutes * 60) {
          for (final g in _games) g.isLocked = true;
        }
      });
      await StorageService.saveTotalPlayed(_totalPlayedSecondsToday);
      await StorageService.saveGamePlayed(
          game.name, game.totalPlayedSecondsToday);

      // Check if we just ran out of time
      if (_remainingSeconds == 0 && mounted) {
        _navigateToLockedScreen();
      }
    }
  }

  Future<void> _navigateToLockedScreen() async {
    final extraMinutes = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => const LockedScreen(),
      ),
    );
    if (extraMinutes != null && extraMinutes > 0 && mounted) {
      // LockedScreen already saved the new limit; reload data
      await _loadData();
    }
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
                    for (final g in _games) {
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

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildGameList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final isLow = _remainingSeconds < 600; // < 10 minutes

    return Container(
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
              // UX-K-02: greeting with real name + initial avatar
              Row(
                children: [
                  // Avatar circle
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _kidName.isNotEmpty
                            ? _kidName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Halo, $_kidName! 👋',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              // Parent dashboard access
              GestureDetector(
                onTap: _openParentDashboard,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.face_rounded,
                      color: Colors.white, size: 24),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          // UX-K-06: TimerCard — updates every minute via _refreshTimer
          TimerCard(
            remainingMinutes: _remainingSeconds ~/ 60,
            dailyLimit: _dailyLimitMinutes,
            usageRatio: _usageRatio,
            totalPlayed: _totalPlayedSecondsToday ~/ 60,
          ),
          if (isLow && _remainingSeconds > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.red.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.orangeAccent, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Sisa waktu kurang dari 10 menit!',
                    style: TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGameList() {
    return ListView(
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

        // UX-K-05: skeleton loader while data is loading
        if (_isLoading)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.85,
            ),
            itemCount: 4,
            itemBuilder: (_, __) => const SkeletonGameCard(),
          )
        else if (_games.isEmpty)
          Center(
            child: Column(
              children: [
                const SizedBox(height: 40),
                Icon(Icons.sports_esports_outlined,
                    size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'Belum ada game yang diizinkan.\nMinta orang tuamu untuk menambahkan.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
              ],
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.85,
            ),
            itemCount: _games.length,
            itemBuilder: (_, i) => GameCard(
              game: _games[i],
              onTap: () => _launchGame(_games[i]),
              isAllLocked: _remainingSeconds == 0,
            ),
          ),
      ],
    );
  }
}
