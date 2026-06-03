import 'package:flutter/material.dart';
import '../services/pairing_service.dart';

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final _otpController = TextEditingController();
  bool _loading = false;
  final PairingServiceKid _ps = PairingServiceKid();

  Future<void> _pair() async {
    setState(() => _loading = true);
    try {
      final kidId = await _ps.pairWithOtp(_otpController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Paired successfully (kidId: $kidId)')));
        Navigator.pushReplacementNamed(context, '/games', arguments: {'kidId': kidId});
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pairing failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pair with Parent')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('Enter pairing code provided by parent'),
            const SizedBox(height: 8),
            TextField(controller: _otpController, decoration: const InputDecoration(labelText: 'Pairing code')),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loading ? null : _pair, child: _loading ? const CircularProgressIndicator() : const Text('Pair')),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            const Text('Or scan QR (not implemented in this starter)')
          ],
        ),
      ),
    );
  }
}
