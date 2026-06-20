import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:gamesbox_common/gamesbox_common.dart';
import '../services/pairing_service.dart';

/// Phase 2 — Kids Pairing Screen.
///
/// UX-K-03: Two tabs:
///   Tab 1 — Scan QR    : MobileScanner reads parent's PrettyQrView QR.
///   Tab 2 — Manual Code: Text field auto-submits when 8+ chars are typed.
///
/// After successful pairing:
///   UX-K-02: Prompts the child to enter their name, saves it, then navigates
///            to HomeScreen.
class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final MobileScannerController _scannerCtrl = MobileScannerController();
  final TextEditingController _codeCtrl = TextEditingController();

  bool _isProcessing = false; // prevent duplicate scan processing
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      // Pause/resume scanner when switching tabs
      if (_tabController.index == 0) {
        _scannerCtrl.start();
      } else {
        _scannerCtrl.stop();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scannerCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  // ─── Pairing logic ────────────────────────────────────────────────────────

  /// Handles a raw string — either from QR scan or manual text field.
  Future<void> _handleCode(String raw) async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });
    _scannerCtrl.stop();

    try {
      // Try to parse as a pairing QR JSON payload first
      final pairingPayload = QrUnlockService.parsePairingQr(raw);
      final pairingId = pairingPayload != null
          ? pairingPayload.familyId
          : raw.trim();

      if (pairingId.isEmpty) throw Exception('Kode tidak valid');

      // Pair with Firebase
      final service = PairingServiceKid();
      final kidId = await service.pairWithOtp(pairingId);

      if (!mounted) return;

      // UX-K-02: Ask for child's name
      final name = await _askChildName();
      if (name != null && name.isNotEmpty) {
        await StorageService.saveKidName(name);
        await service.updateKidName(kidId, name);
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isProcessing = false;
      });
      // Resume scanner if on QR tab
      if (_tabController.index == 0) _scannerCtrl.start();
    }
  }

  /// Shows a dialog asking the child's display name. Returns the entered name
  /// or null if dismissed (we'll fall back to 'Anak').
  Future<String?> _askChildName() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '👋 Halo! Siapa namamu?',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'Masukkan namamu',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: const Color(0xFF0F0E17),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF6C63FF)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 2),
            ),
            prefixIcon: const Icon(
              Icons.person_rounded,
              color: Color(0xFF6C63FF),
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              final name = ctrl.text.trim();
              Navigator.pop(context, name.isEmpty ? null : name);
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Mulai!'),
          ),
        ],
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF43A047), Color(0xFF66BB6A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF43A047).withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.sports_esports_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Hubungkan ke Orang Tua',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Minta orang tua membuka GamesBox Parent\ndan tampilkan kode atau QR-nya',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Error banner
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.red,
                          size: 16,
                        ),
                        onPressed: () => setState(() => _errorMessage = null),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ),

            if (_errorMessage != null) const SizedBox(height: 8),

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
                    color: const Color(0xFF43A047),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: const [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.qr_code_scanner_rounded, size: 16),
                          SizedBox(width: 6),
                          Text('Scan QR'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.keyboard_rounded, size: 16),
                          SizedBox(width: 6),
                          Text('Kode Manual'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [_buildScanTab(), _buildManualTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab 1: QR Scanner ────────────────────────────────────────────────────

  Widget _buildScanTab() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  MobileScanner(
                    controller: _scannerCtrl,
                    onDetect: (capture) {
                      final code = capture.barcodes.firstOrNull?.rawValue;
                      if (code != null) _handleCode(code);
                    },
                  ),

                  // Scan overlay
                  IgnorePointer(
                    child: Center(
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFF43A047),
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: _isProcessing
                            ? Container(
                                color: Colors.black54,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF43A047),
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),

                  // Corner accents
                  IgnorePointer(
                    child: Center(
                      child: SizedBox(
                        width: 220,
                        height: 220,
                        child: CustomPaint(painter: _CornerPainter()),
                      ),
                    ),
                  ),

                  // Flash toggle
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: IconButton(
                      onPressed: () => _scannerCtrl.toggleTorch(),
                      icon: const Icon(
                        Icons.flashlight_on_rounded,
                        color: Colors.white70,
                        size: 28,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black38,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Arahkan kamera ke QR dari GamesBox Parent',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 2: Manual code ───────────────────────────────────────────────────

  Widget _buildManualTab() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_rounded, color: Colors.blue, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Masukkan kode pairing yang ditampilkan di GamesBox Parent orang tua.',
                    style: TextStyle(
                      color: Colors.blue.withValues(alpha: 0.85),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          Text(
            'Kode Pairing',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),

          TextField(
            controller: _codeCtrl,
            enabled: !_isProcessing,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              letterSpacing: 2,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
            ),
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'Contoh: AB3K9Z2M',
              hintStyle: const TextStyle(
                color: Colors.white24,
                fontSize: 16,
                letterSpacing: 1,
                fontFamily: 'monospace',
              ),
              filled: true,
              fillColor: const Color(0xFF1E1E2E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF2A2A3E)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF2A2A3E)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFF43A047),
                  width: 2,
                ),
              ),
              prefixIcon: const Icon(
                Icons.vpn_key_rounded,
                color: Color(0xFF43A047),
              ),
              suffixIcon: _isProcessing
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF43A047),
                        ),
                      ),
                    )
                  : null,
            ),
            // Auto-submit when the code looks long enough (familyId is a Firebase push key, ~20 chars;
            // fallback OTP is 8 chars).  We submit after 8+ chars on Enter key as well.
            onSubmitted: (v) {
              if (v.trim().length >= 6) _handleCode(v.trim());
            },
            onChanged: (v) {
              // Auto-submit for 8-char alphanumeric pairing codes (BUG-06 format)
              if (v.trim().length == 8) _handleCode(v.trim());
            },
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _isProcessing
                  ? null
                  : () {
                      final code = _codeCtrl.text.trim();
                      if (code.length >= 6) {
                        _handleCode(code);
                      } else {
                        setState(
                          () => _errorMessage =
                              'Kode terlalu pendek. Periksa kembali kode dari orang tua.',
                        );
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF43A047),
                disabledBackgroundColor: Colors.grey[700],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Text(
                      'Hubungkan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Corner accent painter for the scan overlay ────────────────────────────

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const len = 24.0;
    const radius = 8.0;
    final paint = Paint()
      ..color = const Color(0xFF43A047)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Top-left
    canvas.drawLine(const Offset(radius, 0), const Offset(len, 0), paint);
    canvas.drawLine(const Offset(0, radius), const Offset(0, len), paint);
    // Top-right
    canvas.drawLine(
      Offset(size.width - len, 0),
      Offset(size.width - radius, 0),
      paint,
    );
    canvas.drawLine(Offset(size.width, radius), Offset(size.width, len), paint);
    // Bottom-left
    canvas.drawLine(
      Offset(0, size.height - len),
      Offset(0, size.height - radius),
      paint,
    );
    canvas.drawLine(
      Offset(radius, size.height),
      Offset(len, size.height),
      paint,
    );
    // Bottom-right
    canvas.drawLine(
      Offset(size.width - len, size.height),
      Offset(size.width - radius, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, size.height - len),
      Offset(size.width, size.height - radius),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
