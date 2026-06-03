import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/storage_service_updated.dart';
import 'home_screen.dart';

class PairingGuideScreen extends StatefulWidget {
  const PairingGuideScreen({super.key});

  @override
  State<PairingGuideScreen> createState() => _PairingGuideScreenState();
}

class _PairingGuideScreenState extends State<PairingGuideScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _familyId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFamilyId();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFamilyId() async {
    final familyId = await StorageService.getFamilyId();
    setState(() {
      _familyId = familyId;
      _isLoading = false;
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  void _proceedToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
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
      ),
      body: Column(
        children: [
          // Header info
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.info_rounded,
                      color: Colors.blue,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Bagikan kode atau QR code berikut ke device anak untuk pairing.',
                        style: TextStyle(
                          color: Colors.blue.withOpacity(0.8),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
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
                  Tab(text: 'Kode 16 Digit'),
                  Tab(text: 'QR Code'),
                ],
              ),
            ),
          ),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildCodeTab(), _buildQrTab()],
            ),
          ),

          // Button
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

  Widget _buildCodeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          const Icon(Icons.vpn_key_rounded, size: 64, color: Color(0xFF6C63FF)),
          const SizedBox(height: 24),
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
            'Bagikan kode ini ke device anak ataupun teman orang tua lain',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 32),
          // Code display
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF6C63FF).withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Text(
                  _familyId ?? 'Loading...',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF6C63FF),
                    letterSpacing: 2,
                    fontFamily: 'Courier',
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Copy button
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
          const SizedBox(height: 32),
          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: Colors.amber,
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Langkah Setup',
                      style: TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '1. Buka GameBox Kids di device anak\n'
                  '2. Pilih "Pairing dengan Parent"\n'
                  '3. Masukkan kode 16 digit ini\n'
                  '4. Konfirmasi pairing',
                  style: TextStyle(
                    color: Colors.amber.withOpacity(0.7),
                    fontSize: 12,
                    height: 1.8,
                  ),
                ),
              ],
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
          const SizedBox(height: 32),
          const Icon(
            Icons.qr_code_2_rounded,
            size: 64,
            color: Color(0xFF6C63FF),
          ),
          const SizedBox(height: 24),
          const Text(
            'QR Code',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Arahkan kamera device anak ke QR code untuk pairing otomatis',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 32),
          // QR placeholder (in real implementation, use qr_flutter)
          Container(
            width: 260,
            height: 260,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF6C63FF).withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _familyId ?? 'Loading...',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                      fontFamily: 'Courier',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '(QR Code akan ditampilkan di sini)',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Note
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purple.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: Colors.purple,
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Catatan',
                      style: TextStyle(
                        color: Colors.purple,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Implementasi QR Code memerlukan library qr_flutter dan mobile_scanner. Untuk demo, gunakan kode 16 digit di tab sebelumnya.',
                  style: TextStyle(
                    color: Colors.purple.withOpacity(0.7),
                    fontSize: 12,
                    height: 1.8,
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
