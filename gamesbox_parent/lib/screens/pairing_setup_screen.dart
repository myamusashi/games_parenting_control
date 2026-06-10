import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:gamesbox_common/gamesbox_common.dart';
import '../services/pairing_service.dart';
import '../widgets/otp_display_widget.dart';

/// PairingSetupScreen — Phase 2 update.
///
/// Previously used raw OTP as QR data.  Now encodes the proper JSON payload
/// via [QrUnlockService.generatePairingQr] so the kids-app scanner can decode
/// the familyId directly from a structured payload.
class PairingSetupScreen extends StatefulWidget {
  const PairingSetupScreen({super.key});

  @override
  State<PairingSetupScreen> createState() => _PairingSetupScreenState();
}

class _PairingSetupScreenState extends State<PairingSetupScreen> {
  final PairingService _ps = PairingService();

  String? _otp; // raw 8-char alphanumeric code stored in /pairing
  String? _qrData; // JSON payload for the QR (encodes familyId / otp)

  int _refreshCountdown = 300;
  Timer? _refreshTimer;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _generate(); // auto-generate on open
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_isGenerating) return;
    setState(() => _isGenerating = true);

    try {
      // Use the stored familyId as the pairing identifier if available,
      // otherwise fall back to generating a short OTP code.
      String? familyId = await StorageService.getFamilyId();
      String pairingId;

      if (familyId != null && familyId.isNotEmpty) {
        pairingId = familyId;
      } else {
        // Fallback: generate an 8-char pairing code (BUG-06 fix already in PairingService)
        // In real app parentId = auth uid from FirebaseService.getCurrentUser()
        final uid = FirebaseService.getCurrentUser()?.uid ?? 'parent-demo';
        pairingId = await _ps.generateOtp(uid);
      }

      final qrPayload = QrUnlockService.generatePairingQr(pairingId);

      if (!mounted) return;
      setState(() {
        _otp = pairingId;
        _qrData = qrPayload;
        _isGenerating = false;
      });
      _startRefreshTimer();
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal membuat kode: $e')));
      }
    }
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshCountdown = 300;
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _refreshCountdown--;
        if (_refreshCountdown <= 0) {
          _generate();
          _refreshCountdown = 300;
        }
      });
    });
  }

  String get _refreshText {
    final m = _refreshCountdown ~/ 60;
    final s = _refreshCountdown % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _copyCode() {
    if (_otp == null) return;
    Clipboard.setData(ClipboardData(text: _otp!));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Kode pairing disalin'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0E17),
        foregroundColor: Colors.white,
        title: const Text('Pairing Setup'),
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _isGenerating ? null : _generate,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Baru'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF6C63FF),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (_isGenerating)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
                ),
              )
            else ...[
              // Code display
              if (_otp != null) ...[
                OtpDisplayWidget(otp: _otp!),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: _copyCode,
                    icon: const Icon(Icons.content_copy_rounded, size: 16),
                    label: const Text('Salin Kode'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6C63FF),
                      side: const BorderSide(color: Color(0xFF6C63FF)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // QR display
              if (_qrData != null) ...[
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
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // QR card
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: 200,
                      height: 200,
                      child: PrettyQrView.data(
                        data: _qrData!,
                        errorCorrectLevel: QrErrorCorrectLevel.M,
                        decoration: const PrettyQrDecoration(
                          shape: PrettyQrSmoothSymbol(color: Color(0xFF3F4E96)),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'Arahkan kamera device anak ke QR code ini untuk pairing otomatis.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
