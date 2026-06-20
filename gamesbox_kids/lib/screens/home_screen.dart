import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:usage_stats/usage_stats.dart';
import 'package:gamesbox_common/gamesbox_common.dart';
import '../services/kid_sync_service.dart';
import '../widgets/game_card.dart';
import 'game_session_screen.dart';
import 'locked_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ── Time state ──────────────────────────────────────────────────────────
  int _dailyLimitMinutes = 60;
  int _totalPlayedSecondsToday = 0;

  // ── Game list state ──────────────────────────────────────────────────────
  List<GameEntry> _games = [];
  bool _isLoading = true;

  // ── User ────────────────────────────────────────────────────────────────
  String _kidName = 'Anak';

  // ── Subscriptions / timers ───────────────────────────────────────────────
  StreamSubscription<List<AllowedGame>>? _gamesSub;
  Timer? _monitorTimer;
  Timer? _refreshTimer; // UX-K-06: live countdown

  final bool _isLockingEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadTimeAndUser();
    _subscribeToGames(); // ← replaces one-shot _loadData for games
    _startPresenceSync();
    _startMonitoring();
    _startLiveTimer();
  }

  @override
  void dispose() {
    _gamesSub?.cancel();
    _monitorTimer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  // ── Load non-game data (limit, played, name) ─────────────────────────────

  Future<void> _loadTimeAndUser() async {
    final limit = await StorageService.getDailyLimit();
    final played = await StorageService.getTotalPlayed();
    final name = await StorageService.getKidName();
    if (mounted) {
      setState(() {
        _dailyLimitMinutes = limit;
        _totalPlayedSecondsToday = played;
        _kidName = name;
      });
    }
  }

  // ── Firebase real-time game stream ────────────────────────────────────────

  Future<void> _startPresenceSync() async {
    final kidId = await StorageService.getKidId();
    if (kidId != null && kidId.isNotEmpty) {
      KidSyncService.startPeriodicSync(kidId);
    }
  }

  Future<void> _subscribeToGames() async {
    final kidId = await StorageService.getKidId();
    if (kidId == null || kidId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    _gamesSub = AllowedGamesService.streamGames(kidId).listen(
      (allowedGames) async {
        if (!mounted) return;

        final played = await StorageService.getTotalPlayed();
        final limit = await StorageService.getDailyLimit();
        final allLocked = played >= limit * 60;

        final List<GameEntry> enriched = [];
        for (final game in allowedGames) {
          Uint8List? icon;

          try {
            final appInfo = await InstalledApps.getAppInfo(game.packageName);
            icon = appInfo?.icon;
          } catch (_) {
            // The parent can allow a game before it is installed on this device.
          }

          final playedForGame =
              await StorageService.getGamePlayed(game.name);

          enriched.add(GameEntry(
            name: game.name,
            packageName: game.packageName,
            iconBytes: icon,
            isLocked: allLocked,
            totalPlayedSecondsToday: playedForGame,
          ));
        }

        if (mounted) {
          setState(() {
            _games = enriched;
            _isLoading = false;
            _totalPlayedSecondsToday = played;
            _dailyLimitMinutes = limit;
          });
        }
      },
      onError: (_) async {
        if (!mounted) return;
        final played = await StorageService.getTotalPlayed();
        final limit = await StorageService.getDailyLimit();
        if (mounted) {
          setState(() {
            _games = [];
            _isLoading = false;
            _totalPlayedSecondsToday = played;
            _dailyLimitMinutes = limit;
          });
        }
      },
    );
  }

  // ── UX-K-06: live countdown ──────────────────────────────────────────────

  void _startLiveTimer() {
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      if (!mounted) return;
      final played = await StorageService.getTotalPlayed();
      if (mounted) setState(() => _totalPlayedSecondsToday = played);
    });
  }

  // ── App monitoring ───────────────────────────────────────────────────────

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

  // ── Computed ─────────────────────────────────────────────────────────────

  int get _remainingSeconds =>
      (_dailyLimitMinutes * 60 - _totalPlayedSecondsToday)
          .clamp(0, _dailyLimitMinutes * 60);

  double get _usageRatio => _dailyLimitMinutes == 0
      ? 1.0
      : (_totalPlayedSecondsToday / (_dailyLimitMinutes * 60))
          .clamp(0.0, 1.0);

  // ── Navigation ────────────────────────────────────────────────────────────

  void _launchGame(GameEntry game) async {
    if (game.isLocked || _remainingSeconds == 0) {
      _navigateToLockedScreen();
      return;
    }
    final playedResult = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => GameSessionScreen(
          game: game,
          remainingSeconds: _remainingSeconds,
        ),
      ),
    );
    if (playedResult != null && playedResult > 0) {
      setState(() {
        game.totalPlayedSecondsToday += playedResult;
        _totalPlayedSecondsToday += playedResult;
        if (_totalPlayedSecondsToday >= _dailyLimitMinutes * 60) {
          for (final g in _games) g.isLocked = true;
        }
      });
      await StorageService.saveTotalPlayed(_totalPlayedSecondsToday);
      await StorageService.saveGamePlayed(
          game.name, game.totalPlayedSecondsToday);

      if (_remainingSeconds == 0 && mounted) {
        _navigateToLockedScreen();
      }
    }
  }

  Future<void> _navigateToLockedScreen() async {
    final extraMinutes = await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (_) => const LockedScreen()),
    );
    if (extraMinutes != null && extraMinutes > 0 && mounted) {
      await _loadTimeAndUser();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

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
    final isLow = _remainingSeconds < 600;

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
              Row(
                children: [
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
            ],
          ),
          const SizedBox(height: 28),
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
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.orangeAccent, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Sisa waktu kurang dari 10 menit!',
                    style: TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
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
        // Header row with sync badge
        Row(
          children: [
            const Text(
              'Game Tersedia',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3142),
              ),
            ),
            const Spacer(),
            // Small live-sync badge so child can see list is real-time
            if (!_isLoading)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Live',
                      style: TextStyle(
                        color: Colors.green.withValues(alpha: 0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),

        // UX-K-05: skeleton while loading
        if (_isLoading)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
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
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          )
        else
          GridView.builder(
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
