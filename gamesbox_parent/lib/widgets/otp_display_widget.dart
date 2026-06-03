import 'package:flutter/material.dart';

class OtpDisplayWidget extends StatelessWidget {
  final String otp;
  const OtpDisplayWidget({super.key, required this.otp});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.grey[200]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Pairing Code', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(otp, style: const TextStyle(fontSize: 28, letterSpacing: 4)),
        ],
      ),
    );
  }
}
