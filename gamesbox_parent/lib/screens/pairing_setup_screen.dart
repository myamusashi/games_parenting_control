import 'package:flutter/material.dart';
import '../services/pairing_service.dart';
import '../widgets/otp_display_widget.dart';
import 'package:qr_flutter/qr_flutter.dart';

class PairingSetupScreen extends StatefulWidget {
  const PairingSetupScreen({super.key});

  @override
  State<PairingSetupScreen> createState() => _PairingSetupScreenState();
}

class _PairingSetupScreenState extends State<PairingSetupScreen> {
  final PairingService _ps = PairingService();
  String? _otp;

  Future<void> _generate() async {
    // In real app parentId = auth uid
    final parentId = 'parent-demo-id';
    final otp = await _ps.generateOtp(parentId);
    setState(() => _otp = otp);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pairing Setup')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(onPressed: _generate, child: const Text('Generate Pairing Code')),
            const SizedBox(height: 16),
            if (_otp != null) ...[
              OtpDisplayWidget(otp: _otp!),
              const SizedBox(height: 16),
              QrImage(data: _otp!, size: 200),
              const SizedBox(height: 8),
              const Text('Give this code or QR to the kid to pair the device.'),
            ]
          ],
        ),
      ),
    );
  }
}
