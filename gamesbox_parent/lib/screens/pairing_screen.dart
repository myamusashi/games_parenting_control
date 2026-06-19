import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:gamesbox_common/gamesbox_common.dart';
import 'parent_dashboard_screen.dart';

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

  int _refreshCountdown = 300; // 5 minutes
  Timer? _refreshTimer;

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
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    super.dispose();
  }

  Future<void> _loadFamilyId() async {
    final familyId = await StorageService.getFamilyId();
    if (!mounted) return;
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
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _refreshCountdown--;
        if (_refreshCountdown <= 0) {
          _regenerateQr();
          _refreshCountdown = 300;
        }
      });
    });
  }

  void _regenerateQr() {
    if (_familyId != null) {
      setState(() => _qrData = QrUnlockService.generatePairingQr(_familyId!));
    }
  }

  String get _refreshText {
    final m = _refreshCountdown ~/ 60;
    final s = _refreshCountdown % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _copyFamilyId() {
    if (_familyId == null) return;
    Clipboard.setData(ClipboardData(text: _familyId!));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Kode pairing disalin'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _boostBrightness() {
    // Signal the OS to use light status bar (subtle brightness cue).
    // For full brightness control, add the `screen_brightness` package.
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          '💡 Naikkan kecerahan layar agar QR mudah dipindai',
        ),
        backgroundColor: Colors.amber[800],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _proceedToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ParentDashboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0E17),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
        ),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Perbarui QR',
            onPressed: () {
              _regenerateQr();
              setState(() => _refreshCountdown = 300);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Info banner
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_rounded, color: Colors.blue, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Bagikan kode atau QR ini ke device anak untuk pairing.',
                    style: TextStyle(
                      color: Colors.blue.withValues(alpha: 0.85),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tab bar
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
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: _proceedToHome,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Lanjut ke Dashboard',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 1: text code ─────────────────────────────────────────────────────

  Widget _buildCodeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Icon(Icons.vpn_key_rounded, size: 56, color: Color(0xFF6C63FF)),
          const SizedBox(height: 16),
          const Text(
            'Kode Pairing',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bagikan kode ini ke device anak untuk pairing manual',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 28),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.35),
                width: 2,
              ),
            ),
            child: SelectableText(
              _familyId ?? '—',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Color(0xFF6C63FF),
                letterSpacing: 1.5,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
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
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          _buildStepsCard(),
        ],
      ),
    );
  }

  // ── Tab 2: QR code ───────────────────────────────────────────────────────

  Widget _buildQrTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          // Refresh countdown
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.refresh_rounded,
                color: Colors.white38,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                'QR diperbarui dalam $_refreshText',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // QR card
          GestureDetector(
            onTap: _boostBrightness,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.35),
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
                          shape: PrettyQrSmoothSymbol(color: Color(0xFF3F4E96)),
                        ),
                      ),
                    )
                  : const SizedBox(
                      width: 220,
                      height: 220,
                      child: Center(
                        child: Text(
                          'Family ID belum tersedia.\nDaftarkan akun terlebih dahulu.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 14),

          // Brightness tip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.wb_sunny_rounded,
                  color: Colors.amber,
                  size: 16,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ketuk QR untuk petunjuk meningkatkan kecerahan layar.',
                    style: TextStyle(
                      color: Colors.amber.withValues(alpha: 0.85),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildStepsCard(),
        ],
      ),
    );
  }

  Widget _buildStepsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: Colors.amber.withValues(alpha: 0.8),
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                'Langkah Setup',
                style: TextStyle(
                  color: Colors.amber.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '1. Buka GamesBox Kids di device anak\n'
            '2. Pilih "Pairing dengan Parent"\n'
            '3. Scan QR atau masukkan kode teks\n'
            '4. Masukkan nama anak\n'
            '5. Pairing selesai!',
            style: TextStyle(
              color: Colors.amber.withValues(alpha: 0.75),
              fontSize: 12,
              height: 1.8,
            ),
          ),
        ],
      ),
    );
  }
}
