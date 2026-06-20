import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:gamesbox_common/gamesbox_common.dart';
import 'add_allowed_game_screen.dart';
import '../services/time_limit_service.dart';

/// Phase 3 — UX-P-02: Per-child detail screen.
///
/// Sections:
///   • Header — avatar, name, online badge
///   • Today's Summary — progress bar + played/limit text
///   • Quick Limit Controls — preset buttons (30m / 1h / 2h / ∞)
///   • Give Extra Time — opens bottom sheet that renders unlock QR
///   • Weekly History — 7-day mini bar chart (from Firebase playedTodaySeconds)
///   • Danger Zone — delete child
class ChildDetailScreen extends StatefulWidget {
  final ChildModel child;

  const ChildDetailScreen({super.key, required this.child});

  @override
  State<ChildDetailScreen> createState() => _ChildDetailScreenState();
}

class _ChildDetailScreenState extends State<ChildDetailScreen> {
  // ── Quick-limit presets ────────────────────────────────────────────────
  static const _presets = [
    _LimitPreset('30m', 30),
    _LimitPreset('1 jam', 60),
    _LimitPreset('2 jam', 120),
    _LimitPreset('Tanpa batas', 0),
  ];

  // ── State ─────────────────────────────────────────────────────────────
  TimeLimitModel? _currentLimit;
  int _playedTodaySeconds = 0;
  bool _isSavingLimit = false;

  // Weekly history: index 0 = 6 days ago, index 6 = today
  // Stored as seconds played. We keep it simple — fetched once on load.
  final List<int> _weekHistory = List.filled(7, 0);
  bool _weekLoaded = false;

  StreamSubscription? _limitSub;
  StreamSubscription? _playedSub;

  @override
  void initState() {
    super.initState();
    _subscribe();
    _loadWeekHistory();
  }

  @override
  void dispose() {
    _limitSub?.cancel();
    _playedSub?.cancel();
    super.dispose();
  }

  // ── Firebase subscriptions ────────────────────────────────────────────

  void _subscribe() {
    _limitSub = TimeLimitService.streamLimit(widget.child.id).listen((tl) {
      if (mounted) setState(() => _currentLimit = tl);
    });
    _playedSub =
        TimeLimitService.streamTodayPlayed(widget.child.id).listen((secs) {
      if (mounted) setState(() => _playedTodaySeconds = secs);
    });
  }

  Future<void> _loadWeekHistory() async {
    // Kids app writes playedTodaySeconds for today; we store daily snapshots
    // under kids/<id>/history/<YYYY-MM-DD> when available.
    // For now we show today's value for today and zeros for past days (until
    // history writing is implemented in Phase 4).
    try {
      final snap = await FirebaseDatabase.instance
          .ref('kids/${widget.child.id}/history')
          .get();
      if (snap.exists && snap.value != null) {
        final raw = snap.value as Map<dynamic, dynamic>;
        final today = DateTime.now();
        for (int i = 0; i < 7; i++) {
          final day = today.subtract(Duration(days: 6 - i));
          final key =
              '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
          _weekHistory[i] = (raw[key] as int?) ?? 0;
        }
      }
      // Always use live value for today (index 6)
      _weekHistory[6] = _playedTodaySeconds;
    } catch (_) {
      // history node may not exist yet — that's fine
    }
    if (mounted) setState(() => _weekLoaded = true);
  }

  // ── Limit helpers ─────────────────────────────────────────────────────

  int get _limitSeconds => (_currentLimit?.isUnlimited ?? true)
      ? 0
      : (_currentLimit?.dailySeconds ?? 3600);

  bool get _isUnlimited => _currentLimit?.isUnlimited ?? true;

  double get _progress => (_isUnlimited || _limitSeconds == 0)
      ? 0.0
      : (_playedTodaySeconds / _limitSeconds).clamp(0.0, 1.0);

  bool get _isOverLimit =>
      !_isUnlimited && _playedTodaySeconds >= _limitSeconds;

  Future<void> _applyPreset(int minutes) async {
    setState(() => _isSavingLimit = true);
    await TimeLimitService.setLimitMinutes(widget.child.id, minutes);
    if (mounted) setState(() => _isSavingLimit = false);
  }

  // ── Delete child ──────────────────────────────────────────────────────

  Future<void> _handleDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Anak?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Data ${widget.child.name} akan dihapus permanen.',
          style: const TextStyle(color: Color(0xFFAAAAAA)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style:
                FilledButton.styleFrom(backgroundColor: const Color(0xFFFF5252)),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await FirebaseDatabase.instance
          .ref('kids/${widget.child.id}')
          .remove();
      if (mounted) Navigator.pop(context);
    }
  }

  // ── Extra-time bottom sheet ───────────────────────────────────────────

  void _showExtraTimeSheet() async {
    final secret = await StorageService.getOtpSecret();
    if (!mounted) return;
    if (secret == null || secret.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OTP secret belum tersedia. Daftar ulang akun.'),
          backgroundColor: Color(0xFFFF5252),
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExtraTimeSheet(
        child: widget.child,
        otpSecret: secret,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 24),
                _buildTodaySummaryCard(),
                const SizedBox(height: 20),
                _buildQuickLimitCard(),
                const SizedBox(height: 20),
                _buildExtraTimeButton(),
                const SizedBox(height: 20),
                _buildAllowedGamesCard(),
                const SizedBox(height: 20),
                _buildWeeklyHistoryCard(),
                const SizedBox(height: 20),
                _buildDangerZone(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllowedGamesCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sports_esports_rounded,
                  color: Color(0xFF6C63FF), size: 18),
              const SizedBox(width: 8),
              const Text(
                'Game Diizinkan',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddAllowedGameScreen(child: widget.child),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Tambah'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<AllowedGame>>(
            stream: AllowedGamesService.streamGames(widget.child.id),
            builder: (context, snapshot) {
              final games = snapshot.data ?? [];
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: LinearProgressIndicator(color: Color(0xFF6C63FF)),
                );
              }
              if (games.isEmpty) {
                return const Text(
                  'Belum ada game. Tambahkan package game agar muncul di perangkat anak.',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                );
              }
              return Column(
                children: games.map((game) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.android_rounded,
                        color: Color(0xFF6C63FF)),
                    title: Text(
                      game.name,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      game.packageName,
                      style: const TextStyle(color: Colors.white54),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: Color(0xFFFF5252)),
                      onPressed: () => AllowedGamesService.removeGame(
                        widget.child.id,
                        game.packageName,
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── AppBar with avatar header ─────────────────────────────────────────

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: const Color(0xFF0F0E17),
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF3F4E96), Color(0xFF6C63FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                // Avatar
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _avatarColors(widget.child.id),
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      widget.child.initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.child.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: widget.child.isOnline
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFF666666),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.child.isOnline ? 'Online sekarang' : 'Offline',
                      style: TextStyle(
                        color: widget.child.isOnline
                            ? const Color(0xFF81C784)
                            : Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Today's summary ───────────────────────────────────────────────────

  Widget _buildTodaySummaryCard() {
    final playedMinutes = _playedTodaySeconds ~/ 60;
    final limitMinutes = _isUnlimited ? null : _limitSeconds ~/ 60;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.today_rounded,
                  color: Color(0xFF6C63FF), size: 18),
              const SizedBox(width: 8),
              const Text(
                'Ringkasan Hari Ini',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              if (_isOverLimit)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5252).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Batas tercapai',
                    style: TextStyle(
                      color: Color(0xFFFF5252),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          // Big numbers
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatMinutes(playedMinutes),
                style: TextStyle(
                  color:
                      _isOverLimit ? const Color(0xFFFF5252) : Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              if (limitMinutes != null) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 6, left: 4),
                  child: Text(
                    ' / ${_formatMinutes(limitMinutes)}',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 6, left: 4),
                  child: Text(
                    ' dimainkan',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _isUnlimited ? 0.0 : _progress,
              minHeight: 10,
              backgroundColor: const Color(0xFF2A2A3E),
              valueColor: AlwaysStoppedAnimation<Color>(
                _isOverLimit
                    ? const Color(0xFFFF5252)
                    : Color.lerp(
                        const Color(0xFF43A047),
                        const Color(0xFFFF9800),
                        _progress,
                      )!,
              ),
            ),
          ),
          if (_isUnlimited) ...[
            const SizedBox(height: 10),
            Text(
              'Tanpa batas waktu hari ini',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Quick limit controls ──────────────────────────────────────────────

  Widget _buildQuickLimitCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timer_rounded,
                  color: Color(0xFF6C63FF), size: 18),
              const SizedBox(width: 8),
              const Text(
                'Batas Waktu Harian',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              if (_isSavingLimit)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF6C63FF)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: _presets.map((p) {
              final isActive = p.minutes == 0
                  ? _isUnlimited
                  : (!_isUnlimited &&
                      (_currentLimit?.dailyMinutes ?? -1) == p.minutes);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: _isSavingLimit ? null : () => _applyPreset(p.minutes),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFF6C63FF)
                            : const Color(0xFF2A2A3E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isActive
                              ? const Color(0xFF6C63FF)
                              : const Color(0xFF3A3A4E),
                        ),
                      ),
                      child: Text(
                        p.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isActive ? Colors.white : Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Give extra time button ────────────────────────────────────────────

  Widget _buildExtraTimeButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: FilledButton.icon(
        onPressed: _showExtraTimeSheet,
        icon: const Icon(Icons.qr_code_rounded, size: 24),
        label: const Text(
          'Beri Waktu Tambahan',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF43A047),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  // ── Weekly history mini bar chart ─────────────────────────────────────

  Widget _buildWeeklyHistoryCard() {
    final maxVal =
        _weekHistory.reduce((a, b) => a > b ? a : b).clamp(1, 999999);
    final dayLabels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    final today = DateTime.now();
    // Map index to actual weekday label
    final labels = List.generate(7, (i) {
      final d = today.subtract(Duration(days: 6 - i));
      return dayLabels[d.weekday - 1];
    });

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded,
                  color: Color(0xFF6C63FF), size: 18),
              const SizedBox(width: 8),
              const Text(
                'Riwayat 7 Hari',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final val = _weekLoaded ? _weekHistory[i] : 0;
                final ratio = val / maxVal;
                final isToday = i == 6;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Minute label above bar
                        if (val > 0)
                          Text(
                            '${val ~/ 60}m',
                            style: TextStyle(
                              color: isToday
                                  ? const Color(0xFF6C63FF)
                                  : Colors.white38,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        const SizedBox(height: 4),
                        // Bar
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOut,
                          height: (ratio * 64).clamp(4.0, 64.0),
                          decoration: BoxDecoration(
                            color: isToday
                                ? const Color(0xFF6C63FF)
                                : const Color(0xFF2A2A3E),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Day label
                        Text(
                          labels[i],
                          style: TextStyle(
                            color: isToday
                                ? const Color(0xFF6C63FF)
                                : Colors.white38,
                            fontSize: 10,
                            fontWeight: isToday
                                ? FontWeight.w700
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ── Danger zone ───────────────────────────────────────────────────────

  Widget _buildDangerZone() {
    return _Card(
      borderColor: const Color(0xFFFF5252).withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_rounded,
                  color: Color(0xFFFF5252), size: 18),
              const SizedBox(width: 8),
              const Text(
                'Danger Zone',
                style: TextStyle(
                  color: Color(0xFFFF5252),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _handleDelete,
              icon: const Icon(Icons.person_remove_rounded, size: 18),
              label: Text('Hapus ${widget.child.name}'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFF5252),
                side:
                    const BorderSide(color: Color(0xFFFF5252), width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  String _formatMinutes(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}j' : '${h}j ${m}m';
  }

  List<Color> _avatarColors(String id) {
    final colors = [
      [const Color(0xFF6C63FF), const Color(0xFF9C89FF)],
      [const Color(0xFFFF6584), const Color(0xFFFF8FA0)],
      [const Color(0xFF43A047), const Color(0xFF66BB6A)],
      [const Color(0xFFFF9800), const Color(0xFFFFB74D)],
      [const Color(0xFF00BCD4), const Color(0xFF4DD0E1)],
    ];
    return colors[id.hashCode.abs() % colors.length];
  }
}

// ── Extra-time bottom sheet ──────────────────────────────────────────────────

class _ExtraTimeSheet extends StatefulWidget {
  final ChildModel child;
  final String otpSecret;

  const _ExtraTimeSheet({required this.child, required this.otpSecret});

  @override
  State<_ExtraTimeSheet> createState() => _ExtraTimeSheetState();
}

class _ExtraTimeSheetState extends State<_ExtraTimeSheet> {
  static const _options = [15, 30, 60];
  int _selectedMinutes = 30;
  String? _qrData;
  int _refreshCountdown = 300; // 5 minutes
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _generateQr();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _generateQr() {
    _timer?.cancel();
    setState(() {
      _qrData = QrUnlockService.generateUnlockQr(
        kidId: widget.child.id,
        extraMinutes: _selectedMinutes,
        otpSecret: widget.otpSecret,
      );
      _refreshCountdown = 300;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _refreshCountdown--;
        if (_refreshCountdown <= 0) _generateQr();
      });
    });
  }

  String get _refreshText {
    final m = _refreshCountdown ~/ 60;
    final s = _refreshCountdown % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF43A047).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add_alarm_rounded,
                      color: Color(0xFF43A047), size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Beri Waktu Tambahan',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      widget.child.name,
                      style: const TextStyle(
                        color: Color(0xFF6C63FF),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Duration selector
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Durasi tambahan',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: _options.map((min) {
                final isSelected = _selectedMinutes == min;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedMinutes = min);
                        _generateQr();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF43A047)
                              : const Color(0xFF2A2A3E),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF43A047)
                                : const Color(0xFF3A3A4E),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              min < 60 ? '${min}m' : '${min ~/ 60}j',
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white54,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              '$min menit',
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white70
                                    : Colors.white38,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // QR expiry countdown
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.refresh_rounded,
                    color: Colors.white38, size: 14),
                const SizedBox(width: 6),
                Text(
                  'QR kadaluarsa dalam $_refreshText',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // QR code
            GestureDetector(
              onTap: () {
                // Boost brightness hint
                SystemChrome.setSystemUIOverlayStyle(
                  const SystemUiOverlayStyle(
                      statusBarBrightness: Brightness.light),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('💡 Naikkan kecerahan agar mudah dipindai'),
                    backgroundColor: Colors.amber[800],
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF43A047).withValues(alpha: 0.35),
                      blurRadius: 28,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: _qrData != null
                    ? SizedBox(
                        width: 220,
                        height: 220,
                        child: PrettyQrView.data(
                          data: _qrData!,
                          errorCorrectLevel: QrErrorCorrectLevel.M,
                          decoration: const PrettyQrDecoration(
                            shape: PrettyQrSmoothSymbol(
                                color: Color(0xFF2E7D32)),
                          ),
                        ),
                      )
                    : const SizedBox(
                        width: 220,
                        height: 220,
                        child: Center(child: CircularProgressIndicator()),
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // Instructions
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: Colors.blue.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_rounded,
                      color: Colors.blue, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Minta ${widget.child.name} membuka GamesBox Kids → '
                      '"Minta Izin Orang Tua", lalu arahkan kamera ke QR ini.',
                      style: TextStyle(
                        color: Colors.blue.withValues(alpha: 0.8),
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared card widget ───────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  final Color? borderColor;

  const _Card({required this.child, this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor ?? const Color(0xFF2A2A3E),
        ),
      ),
      child: child,
    );
  }
}

// ── Limit preset data class ──────────────────────────────────────────────────

class _LimitPreset {
  final String label;
  final int minutes;
  const _LimitPreset(this.label, this.minutes);
}
