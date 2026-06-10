import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'dart:async';
import 'package:gamesbox_common/gamesbox_common.dart';
import 'home_screen.dart';

/// UX-P-01: Fully implemented QR display with PrettyQrView,
/// brightness boost, and auto-refresh every 5 minutes.
class PairingGuideScreen extends StatefulWidget {
  const PairingGuideScreen({super.key});

  @override
  State<PairingGuideScreen> createState() => _PairingGuideScreenState();
}

class _PairingGuideScreenState extends State<PairingGuideScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _familyId;
  String? _qrData;
  bool _isLoading = true;
  Timer? _refreshTimer;
  int _refreshCountdown = 300; // 5 minutes

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFamilyId();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshTimer?.cancel();
    // Restore normal brightness
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    super.dispose();
  }

  Future<void> _loadFamilyId() async {
    final familyId = await StorageService.getFamilyId();
    setState(() {
      _familyId = familyId;
      _qrData = familyId != null
          ? QrUnlockService.generatePairingQr(familyId)
          : null;
      _isLoading = false;
    });
    _startRefreshTimer();
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshCountdown = 300;
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _refreshCountdown--;
        if (_refreshCountdown <= 0) {
          // Regenerate QR with fresh timestamp
          if (_familyId != null) {
            _qrData = QrUnlockService.generatePairingQr(_familyId!);
          }
          _refreshCountdown = 300;
        }
      });
    });
  }

  void _copyFamilyId() {
    if (_familyId != null) {
      Clipboard.setData(ClipboardData(text: _familyId!));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Kode pairing disalin'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  /// UX-P-01: Boost screen brightness for easy QR scanning
  void _boostBrightness() {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarBrightness: Brightness.light,
      statusBarIconBrightness: Brightness.dark,
    ));
  }

  void _proceedToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  String get _refreshText {
    final m = _refreshCountdown ~/ 60;
    final s = _refreshCountdown % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0E17),
        body: Center(
            child: CircularProgressIndicator(color: Color(0xFF6C63FF))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0E17),
        foregroundColor: Colors.white,
        title: const Text('Setup Device Anak'),
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_rounded, color: Colors.blue, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Bagikan kode atau QR code berikut ke device anak untuk pairing.',
                    style: TextStyle(
                        color: Colors.blue.withValues(alpha: 0.8),
                        fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: const Color(0xFF6C63FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: const [
                  Tab(text: 'Kode Teks'),
                  Tab(text: 'QR Code'),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildCodeTab(), _buildQrTab()],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: _proceedToHome,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Lanjut ke Dashboard',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          const Icon(Icons.vpn_key_rounded,
              size: 56, color: Color(0xFF6C63FF)),
          const SizedBox(height: 16),
          const Text('Kode Pairing',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                  width: 2),
            ),
            child: SelectableText(
              _familyId ?? 'Loading...',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF6C63FF),
                  letterSpacing: 2,
                  fontFamily: 'monospace'),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _copyFamilyId,
              icon: const Icon(Icons.content_copy_rounded),
              label: const Text('Salin Kode'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6C63FF),
                side: const BorderSide(color: Color(0xFF6C63FF)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Refresh countdown
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.refresh_rounded,
                  color: Colors.white54, size: 16),
              const SizedBox(width: 6),
              Text(
                'QR diperbarui dalam $_refreshText',
                style:
                    const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // UX-P-01: Real QR using PrettyQrView
          if (_qrData != null)
            GestureDetector(
              onTap: _boostBrightness,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: SizedBox(
                  width: 240,
                  height: 240,
                  child: PrettyQrView.data(
                    data: _qrData!,
                    decoration: const PrettyQrDecoration(
                      shape: PrettyQrSmoothSymbol(
                        color: Color(0xFF3F4E96),
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            const Text('Family ID belum tersedia',
                style: TextStyle(color: Colors.white54)),

          const SizedBox(height: 16),

          // Brightness tip
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.wb_sunny_rounded,
                    color: Colors.amber, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ketuk QR untuk meningkatkan kecerahan layar agar mudah dipindai.',
                    style: TextStyle(
                        color: Colors.amber.withValues(alpha: 0.8),
                        fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
