import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:gamesbox_common/gamesbox_common.dart';

/// UX-K-01: Full-screen locked state — cannot be dismissed.
/// Shows countdown to midnight and a button to scan parent's unlock QR.
class LockedScreen extends StatefulWidget {
  const LockedScreen({super.key});

  @override
  State<LockedScreen> createState() => _LockedScreenState();
}

class _LockedScreenState extends State<LockedScreen> {
  Timer? _countdownTimer;
  Duration _timeUntilReset = Duration.zero;
  bool _showScanner = false;
  String? _kidId;
  String? _otpSecret;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    _kidId = await StorageService.getKidId();
    _otpSecret = await StorageService.getOtpSecret();
  }

  void _startCountdown() {
    _updateCountdown();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateCountdown();
    });
  }

  void _updateCountdown() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1, 0, 0, 0);
    final diff = midnight.difference(now);
    if (mounted) setState(() => _timeUntilReset = diff);
  }

  String get _countdownText {
    final h = _timeUntilReset.inHours.toString().padLeft(2, '0');
    final m = (_timeUntilReset.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_timeUntilReset.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Future<void> _handleQrScan(String? rawValue) async {
    if (rawValue == null) return;
    if (_kidId == null || _otpSecret == null) {
      _showError(
        'Perangkat belum terkonfigurasi. Hubungkan ulang dengan orang tua.',
      );
      return;
    }

    try {
      final extraMinutes = QrUnlockService.verifyAndExtract(
        qrData: rawValue,
        otpSecret: _otpSecret!,
        expectedKidId: _kidId!,
      );

      // Add extra time to local storage
      final currentLimit = await StorageService.getDailyLimit();
      await StorageService.saveDailyLimit(currentLimit + extraMinutes);

      if (mounted) {
        Navigator.pop(context, extraMinutes); // return extra minutes granted
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _showScanner = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFFF5252),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // UX-K-01: Cannot be dismissed without QR unlock
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0E17),
        body: SafeArea(
          child: _showScanner ? _buildScanner() : _buildLockedContent(),
        ),
      ),
    );
  }

  Widget _buildLockedContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),

          // Animated icon
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.8, end: 1.0),
            duration: const Duration(seconds: 2),
            curve: Curves.easeInOut,
            builder: (_, value, child) =>
                Transform.scale(scale: value, child: child),
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF5252).withValues(alpha: 0.3),
                    blurRadius: 32,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.lock_rounded,
                size: 60,
                color: Color(0xFFFF5252),
              ),
            ),
          ),

          const SizedBox(height: 32),

          const Text(
            'Waktu Main Habis!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          Text(
            'Istirahat dulu ya! Kamu sudah bermain cukup banyak hari ini. 😊',
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.7),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          const Spacer(flex: 1),

          // Countdown to reset
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2E),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text(
                  'Main lagi dalam',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _countdownText,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF6C63FF),
                    letterSpacing: 4,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(flex: 1),

          // Ask parent button
          SizedBox(
            width: double.infinity,
            height: 60,
            child: FilledButton.icon(
              onPressed: () => setState(() => _showScanner = true),
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 24),
              label: const Text(
                'Minta Izin Orang Tua',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'Orang tua bisa memberikan waktu tambahan menggunakan QR code',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),

          const Spacer(flex: 2),
        ],
      ),
    );
  }

  Widget _buildScanner() {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => setState(() => _showScanner = false),
              ),
              const Expanded(
                child: Text(
                  'Scan QR dari Orang Tua',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),

        // Info
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_rounded, color: Colors.blue, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Minta orang tua untuk membuka GamesBox Parent → Beri Waktu Tambahan, lalu arahkan kamera ke QR code.',
                  style: TextStyle(
                    color: Colors.blue.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Scanner
        Expanded(
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: MobileScanner(
              onDetect: (capture) {
                final code = capture.barcodes.firstOrNull?.rawValue;
                if (code != null) _handleQrScan(code);
              },
            ),
          ),
        ),
      ],
    );
  }
}
