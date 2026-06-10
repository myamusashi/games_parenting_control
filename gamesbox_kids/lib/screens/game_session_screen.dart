import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:gamesbox_common/gamesbox_common.dart';
import '../services/kid_sync_service.dart';

class GameSessionScreen extends StatefulWidget {
  final GameEntry game;
  final int remainingSeconds;

  const GameSessionScreen({
    super.key,
    required this.game,
    required this.remainingSeconds,
  });

  @override
  State<GameSessionScreen> createState() => _GameSessionScreenState();
}

class _GameSessionScreenState extends State<GameSessionScreen> {
  int _elapsed = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _launchActualApp();
    // BUG-04: Start sync (may already be running, safe to call again)
    _startSync();
  }

  Future<void> _startSync() async {
    final kidId = await StorageService.getKidId();
    if (kidId != null) KidSyncService.startPeriodicSync(kidId);
  }

  void _launchActualApp() {
    InstalledApps.startApp(widget.game.packageName);
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _elapsed++);

      if (widget.remainingSeconds - _elapsed == 300) {
        _showWarning();
      }

      if (_elapsed >= widget.remainingSeconds) {
        timer.cancel();
        _showTimeUpDialog();
      }
    });
  }

  void _showWarning() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.timer_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text('⚠️ Sisa waktu 5 menit!'),
          ],
        ),
        backgroundColor: const Color(0xFFFF9800),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showTimeUpDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          '⏰ Waktu Habis!',
          style: TextStyle(color: Color(0xFF2D3142)),
        ),
        content: Text(
          'Kamu sudah bermain ${widget.remainingSeconds ~/ 60} menit. Istirahat dulu ya!',
          style: const TextStyle(color: Color(0xFF9191A4)),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _exitSession();
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF5252),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Keluar Game'),
          ),
        ],
      ),
    );
  }

  Future<void> _exitSession() async {
    _timer?.cancel();
    // BUG-04: Force sync before navigating away
    await KidSyncService.syncNow();
    if (mounted) Navigator.pop(context, _elapsed);
  }

  String get _formattedElapsed {
    final m = _elapsed ~/ 60;
    final s = _elapsed % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remainSec = (widget.remainingSeconds - _elapsed).clamp(
      0,
      widget.remainingSeconds,
    );
    final remainM = remainSec ~/ 60;
    final remainS = remainSec % 60;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final confirm = await _showConfirmExit();
        if (confirm == true && mounted) await _exitSession();
      },
      child: Scaffold(
        body: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF3F4E96), Color(0xFF5E6BC4)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                children: [
                  const Spacer(flex: 1),
                  Container(
                    width: 120,
                    height: 120,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: widget.game.iconBytes != null
                        ? Image.memory(widget.game.iconBytes!)
                        : const Icon(
                            Icons.gamepad_rounded,
                            size: 60,
                            color: Colors.white,
                          ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    widget.game.name,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Sedang dimainkan...',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Spacer(flex: 1),
                  // Timer display
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 32,
                      horizontal: 20,
                    ),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          'WAKTU BERMAIN',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formattedElapsed,
                          style: const TextStyle(
                            fontSize: 64,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF3F4E96),
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: remainM < 5
                                ? const Color(0xFFFFEBEE)
                                : const Color(0xFFF1F4FF),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                size: 20,
                                color: remainM < 5
                                    ? const Color(0xFFE53935)
                                    : const Color(0xFF3F4E96),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Sisa: ${remainM.toString().padLeft(2, '0')}:${remainS.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  color: remainM < 5
                                      ? const Color(0xFFE53935)
                                      : const Color(0xFF3F4E96),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(flex: 2),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final confirm = await _showConfirmExit();
                        if (confirm == true && mounted) await _exitSession();
                      },
                      icon: const Icon(Icons.stop_rounded, size: 28),
                      label: const Text(
                        'Selesai Main',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5252),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _showConfirmExit() {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Keluar Game?',
          style: TextStyle(color: Color(0xFF2D3142)),
        ),
        content: const Text(
          'Waktu bermain akan dicatat secara otomatis.',
          style: TextStyle(color: Color(0xFF9191A4)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Lanjut Main'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF5252),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }
}
